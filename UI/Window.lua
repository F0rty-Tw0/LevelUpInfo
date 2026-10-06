local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")
local SkillList = ns.SkillList or require("LevelUpInfo.Data.SkillList")
local AutoHide = ns.AutoHide or require("LevelUpInfo.UI.AutoHide")
local SkillRow = ns.SkillRow or require("LevelUpInfo.UI.SkillRow")
local SkillGroup = ns.SkillGroup or require("LevelUpInfo.UI.SkillGroup")
local SpellFacts = ns.SpellFacts or require("LevelUpInfo.Data.SpellFacts")
local Layout = ns.Layout or require("LevelUpInfo.UI.Layout")
local GainLines = ns.GainLines or require("LevelUpInfo.UI.GainLines")

local format = string.format
local ipairs = ipairs
local pairs = pairs
local select = select
local tostring = tostring
local xpcall = xpcall

local Text = Localization.Text

local FRAME_WIDTH = 338
local CONTENT_WIDTH = 298
local CONTENT_LEFT = 19
local HEADER_HEIGHT = 68
local FOOTER_HEIGHT = 12
local LINE_HEIGHT = 16
local HEADING_HEIGHT = 24
local SECTION_GAP = 6
local ROW_HEIGHT = 47
local TEXT_LEFT = 4
local GROUP_CAP = 5
local DIVIDER_ALPHA = 0.25
local DIVIDER_GAP = 2
local NO_LINES = {}

-- Skill groups in display order; a capped group shows its first `cap` rows
-- and a `+N more` toggle, or, expanded, all rows in a scroll box.
local GROUPS = {
  { group = "skill", title = "New skills" },
  { group = "rank", title = "New ranks" },
  { group = "missed", title = "Not yet learned", cap = GROUP_CAP, more = "+%d more not yet learned" },
  { group = "weapon", title = "Weapon skills", cap = GROUP_CAP, more = "+%d more weapon skills" },
}

local Window = {}

local db
local frame
local content
local current
local rows = {}
local headings = {}
local dividers = {}
local POOLS = { rows, headings, dividers } -- all hidden when a fill fails
local rowsUsed
local skillEntries, skillHint -- skill list of `current`: built on Show, reused by Refresh
-- Set while a fill runs, so a load result fired inside it starts no second fill.
local filling = false
local fill

-- A toggle click refills the shown record with the group's new state.
local function onToggle()
  if current and not filling then
    fill(current)
  end
end

local function applyAnchor()
  frame:ClearAllPoints()
  local position = db.position
  if position then
    frame:SetPoint(position.point, _G.UIParent, position.point, position.x, position.y)
  else
    frame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 120)
  end
end

local function savePosition()
  frame:StopMovingOrSizing()
  local point, _, _, x, y = frame:GetPoint()
  db.position = { point = point, x = x, y = y }
end

local function errorHandler(err)
  return tostring(err) .. "\n" .. _G.debugstack()
end

local function build()
  frame = _G.CreateFrame("Frame", "LevelUpInfoFrame", _G.UIParent, "ButtonFrameTemplate")
  frame:Hide()
  _G.ButtonFrameTemplate_HideButtonBar(frame)
  frame:SetPortraitToUnit("player")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", savePosition)
  frame:HookScript("OnHide", function()
    current = nil
    SpellFacts.Stop()
  end)
  AutoHide.Attach(frame, db)
  frame.CloseButton:SetScript("OnClick", AutoHide.Close)
  content = _G.CreateFrame("Frame", nil, frame)
  content:SetSize(CONTENT_WIDTH, 1)
  content:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, -HEADER_HEIGHT)
  local r, g, b = _G.NORMAL_FONT_COLOR:GetRGB()
  for _, spec in ipairs(GROUPS) do
    local heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    headings[spec.group] = heading
    local divider = content:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(r, g, b, DIVIDER_ALPHA)
    divider:SetSize(CONTENT_WIDTH, 1)
    divider:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", -TEXT_LEFT, -DIVIDER_GAP)
    dividers[spec.group] = divider
  end
  SkillGroup.Build(content, GROUPS, onToggle)
end

-- A reused row that sat in another container (content or a box) moves over.
local function nextRow(parent)
  rowsUsed = rowsUsed + 1
  local row = rows[rowsUsed]
  if not row then
    row = SkillRow.Create(parent, AutoHide.Pause, AutoHide.Resume)
    rows[rowsUsed] = row
  elseif row:GetParent() ~= parent then
    row:SetParent(parent)
  end
  return row
end

local function addRow(entry, money, parent)
  local row = nextRow(parent)
  SkillRow.SetSkill(row, entry, money)
  if entry.previousSpellID then
    SkillRow.SetChanges(row, SpellFacts.Changes(entry.previousSpellID, entry.spellID) or NO_LINES)
  end
  Layout.Add(row, parent, 0, nil)
end

-- A capped group's toggle: `Show less` under its box, `+N more` when
-- collapsed rows were left out, else hidden.
local function fillToggle(spec, count)
  local group = spec.group
  local text
  if SkillGroup.IsExpanded(group) and count > 0 then
    text = Text("Show less")
  else
    SkillGroup.HideBox(group)
    if count > spec.cap then
      text = format(Text(spec.more), count - spec.cap)
    end
  end
  if text then
    Layout.Add(SkillGroup.Toggle(group, text), content, 0, LINE_HEIGHT)
  else
    SkillGroup.HideToggle(group)
  end
end

local function fillGroup(spec, entries, money)
  local heading = headings[spec.group]
  local expanded = SkillGroup.IsExpanded(spec.group)
  local parent = content
  local count = 0
  for _, entry in ipairs(entries) do
    if entry.group == spec.group then
      count = count + 1
      if count == 1 then
        heading:SetText(Text(spec.title))
        Layout.Add(heading, content, TEXT_LEFT, HEADING_HEIGHT)
        dividers[spec.group]:Show()
        if expanded then
          local box
          box, parent = SkillGroup.Box(spec.group)
          Layout.Add(box, content, 0, nil)
        end
      end
      if expanded or not spec.cap or count <= spec.cap then
        addRow(entry, money, parent)
      end
    end
  end
  if count == 0 then
    heading:Hide()
    dividers[spec.group]:Hide()
  end
  if spec.cap then
    fillToggle(spec, count)
  end
end

local function fillSkills(record, gainCount)
  if not skillEntries then
    local class = select(2, _G.UnitClass("player"))
    local race = select(2, _G.UnitRace("player"))
    local faction = _G.UnitFactionGroup("player")
    skillEntries, skillHint = SkillList.Build(db.trainers, class, race, faction, record.fromLevel, record.toLevel)
  end
  local money = _G.GetMoney()
  rowsUsed = 0
  if gainCount > 0 and (#skillEntries > 0 or skillHint) then
    Layout.AddGap(content, SECTION_GAP)
  end
  for _, spec in ipairs(GROUPS) do
    fillGroup(spec, skillEntries, money)
  end
  if skillHint then
    local row = nextRow(content)
    SkillRow.SetHint(row)
    Layout.Add(row, content, 0, ROW_HEIGHT)
  end
  for index = rowsUsed + 1, #rows do
    rows[index]:Hide()
  end
end

-- Each expanded group's scroll child is as tall as the rows placed in it.
local function sizeBoxes(cursors)
  for _, spec in ipairs(GROUPS) do
    if spec.cap and SkillGroup.IsExpanded(spec.group) then
      local _, child = SkillGroup.Box(spec.group)
      SkillGroup.SetContentHeight(spec.group, cursors[child] or 0)
    end
  end
end

function fill(record)
  filling = true
  local ok, err = xpcall(function()
    frame:SetTitle(format(Text("Level %d"), record.toLevel))
    Layout.Reset()
    fillSkills(record, GainLines.Fill(content, record))
    local height, cursors = Layout.Run(content)
    sizeBoxes(cursors)
    content:SetHeight(height)
    frame:SetSize(FRAME_WIDTH, HEADER_HEIGHT + height + FOOTER_HEIGHT)
  end, errorHandler)
  filling = false
  if not ok then
    Layout.Reset()
    GainLines.HideAll()
    SkillGroup.HideAll()
    for _, pool in ipairs(POOLS) do
      for _, region in pairs(pool) do
        region:Hide()
      end
    end
    _G.geterrorhandler()(err)
  end
end

function Window.Install(savedDB)
  db = savedDB
end

function Window.Current()
  return current
end

function Window.Frame()
  return frame
end

function Window.ApplyScale()
  if frame then
    frame:SetScale(db.scale)
  end
end

function Window.ResetPosition()
  db.position = nil
  if frame then
    applyAnchor()
  end
end

-- The one show and re-show path: stop the countdown, refill, restart it
-- (Resume does nothing while the mouse is over the window).
function Window.Show(record)
  if not frame then
    build()
  end
  AutoHide.Pause()
  current = record
  skillEntries = nil
  SkillGroup.Collapse()
  fill(record)
  Window.ApplyScale()
  applyAnchor()
  frame:Show()
  AutoHide.Resume()
end

-- Refills the shown record when spell text arrives; keeps countdown, anchor,
-- scale and each group's expanded state and scroll position.
function Window.Refresh()
  if filling or not current or not frame or not frame:IsShown() then
    return
  end
  fill(current)
end

ns.Window = Window
return Window
