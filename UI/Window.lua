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
local min = math.min
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
-- Spacing hierarchy: rows of a group sit closest, a heading sits right on its
-- rows, blocks (stats, each skill group, the hint) are pushed further apart.
local GROUP_GAP = 14
local ROW_HEIGHT = 47
local ROW_GAP = 4
local TEXT_LEFT = 4
local GROUP_CAP = 5
-- Congratulation line in the header strip right of the portrait.
local HEADER_LEFT = 62
local HEADER_TOP = -35
local HEADER_WIDTH = 262
local NO_LINES = {}

-- Skill groups in display order; a capped group shows its first `cap` rows
-- and a `+N more` toggle, or, expanded, all rows in a scroll box.
local GROUPS = {
  { group = "skill", title = "New skills", cap = GROUP_CAP, more = "+%d more new skills" },
  { group = "rank", title = "New ranks", cap = GROUP_CAP, more = "+%d more new ranks" },
  { group = "missed", title = "Not yet learned", cap = GROUP_CAP, more = "+%d more not yet learned" },
  { group = "weapon", title = "Weapon skills", cap = GROUP_CAP, more = "+%d more weapon skills" },
}

local Window = {}

local db
local frame
local content
local reachedLine
local current
local rows = {}
local headings = {}
local POOLS = { rows, headings } -- all hidden when a fill fails
local rowsUsed
local rowEntries = {} -- entry shown in rows[i], read only when rowLines[i]
local rowLines = {} -- whether rows[i] shows change lines
local boxFirstRow = {} -- group → index in `rows` of its expanded box's first row
local skillEntries, skillHint -- skill list of `current`: built on Show, reused by Refresh
-- Set while a fill runs, so a load result fired inside it starts no second fill.
local filling = false
-- Set by a failed fill or refresh: its layout list must not be replayed, so
-- the next refresh is a full fill.
local stale = false
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

local function buildHeader()
  frame:SetTitle(Text("Level Up!"))
  reachedLine = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  reachedLine:SetWidth(HEADER_WIDTH)
  reachedLine:SetJustifyH("LEFT")
  reachedLine:SetWordWrap(false)
  reachedLine:SetPoint("TOPLEFT", frame, "TOPLEFT", HEADER_LEFT, HEADER_TOP)
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
  buildHeader()
  content = _G.CreateFrame("Frame", nil, frame)
  content:SetSize(CONTENT_WIDTH, 1)
  content:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, -HEADER_HEIGHT)
  GainLines.Build(content)
  for _, spec in ipairs(GROUPS) do
    headings[spec.group] = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
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
  local lines = entry.previousSpellID ~= nil
  rowLines[rowsUsed] = lines
  if lines then
    rowEntries[rowsUsed] = entry
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

-- `gap` goes above the heading when the group has rows; returns the row count.
local function fillGroup(spec, entries, money, gap)
  local heading = headings[spec.group]
  local expanded = SkillGroup.IsExpanded(spec.group)
  local parent = content
  local count = 0
  for _, entry in ipairs(entries) do
    if entry.group == spec.group then
      count = count + 1
      if count == 1 then
        heading:SetText(Text(spec.title))
        Layout.AddGap(content, gap)
        Layout.Add(heading, content, TEXT_LEFT, HEADING_HEIGHT)
        if expanded then
          local box
          box, parent = SkillGroup.Box(spec.group)
          boxFirstRow[spec.group] = rowsUsed + 1
          Layout.Add(box, content, 0, nil)
        end
      end
      if expanded or not spec.cap or count <= spec.cap then
        if count > 1 then
          Layout.AddGap(parent, ROW_GAP)
        end
        addRow(entry, money, parent)
      end
    end
  end
  if count == 0 then
    heading:Hide()
  end
  if spec.cap then
    fillToggle(spec, count)
  end
  return count
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
  _G.wipe(boxFirstRow)
  local gap = gainCount > 0 and GROUP_GAP or 0
  for _, spec in ipairs(GROUPS) do
    if fillGroup(spec, skillEntries, money, gap) > 0 then
      gap = GROUP_GAP
    end
  end
  if skillHint then
    Layout.AddGap(content, gap)
    local row = nextRow(content)
    SkillRow.SetHint(row)
    rowLines[rowsUsed] = false
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

-- An expanded box is as tall as its group's first `cap` rows and the gaps
-- between them, so expanding keeps the group's size and only adds the
-- scrollbar. Runs before placing: the layout reads the box's height.
local function fitBoxes()
  for _, spec in ipairs(GROUPS) do
    local first = boxFirstRow[spec.group]
    if spec.cap and first and SkillGroup.IsExpanded(spec.group) then
      local last = min(first + spec.cap - 1, rowsUsed)
      local height = (last - first) * ROW_GAP
      for index = first, last do
        height = height + rows[index]:GetHeight()
      end
      SkillGroup.SetBoxHeight(spec.group, height)
    end
  end
end

local function applyLayout()
  fitBoxes()
  local height, cursors = Layout.Run(content)
  sizeBoxes(cursors)
  content:SetHeight(height)
  frame:SetSize(FRAME_WIDTH, HEADER_HEIGHT + height + FOOTER_HEIGHT)
end

-- Runs `work` under the `filling` guard; an error hides everything, marks
-- the window stale and reports it.
local function guarded(work)
  filling = true
  local ok, err = xpcall(work, errorHandler)
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
    stale = true
    _G.geterrorhandler()(err)
  end
end

function fill(record)
  guarded(function()
    reachedLine:SetText(format(Text("Congratulations! You reached level %d."), record.toLevel))
    Layout.Reset()
    fillSkills(record, GainLines.Fill(content, record))
    applyLayout()
    stale = false
  end)
end

-- Recomputes the change lines of shown rows that use `spellID`; places the
-- window again only when one matched.
local function refreshRows(spellID)
  local changed = false
  for index = 1, rowsUsed do
    local entry = rowEntries[index]
    if rowLines[index] and (entry.spellID == spellID or entry.previousSpellID == spellID) then
      SkillRow.SetChanges(rows[index], SpellFacts.Changes(entry.previousSpellID, entry.spellID) or NO_LINES)
      changed = true
    end
  end
  if changed then
    applyLayout()
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

-- Spell text for `spellID` arrived: updates only the rows using it (nil or
-- stale: a full refill). Keeps countdown, anchor, scale, expanded state and
-- scroll position.
function Window.Refresh(spellID)
  if filling or not current or not frame or not frame:IsShown() then
    return
  end
  if spellID == nil or stale then
    fill(current)
  else
    guarded(function()
      refreshRows(spellID)
    end)
  end
end

ns.Window = Window
return Window
