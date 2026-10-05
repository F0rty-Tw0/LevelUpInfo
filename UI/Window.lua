local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")
local SkillList = ns.SkillList or require("LevelUpInfo.Data.SkillList")
local AutoHide = ns.AutoHide or require("LevelUpInfo.UI.AutoHide")
local SkillRow = ns.SkillRow or require("LevelUpInfo.UI.SkillRow")

local format = string.format
local ipairs = ipairs
local select = select

local Text = Localization.Text

local FRAME_WIDTH = 338
local CONTENT_WIDTH = 298
local CONTENT_LEFT = 19
local HEADER_HEIGHT = 68
local FOOTER_HEIGHT = 12
local LINE_HEIGHT = 16
local HEADING_HEIGHT = 20
local SECTION_GAP = 6
local ROW_HEIGHT = 47
local TEXT_LEFT = 4
local GROUP_CAP = 5

-- Skill groups in display order; a capped group shows its first `cap` rows,
-- then a `+N more` line for the rest.
local GROUPS = {
  { group = "skill", title = "New skills" },
  { group = "rank", title = "New ranks" },
  { group = "missed", title = "Not yet learned", cap = GROUP_CAP, more = "+%d more not yet learned" },
  { group = "weapon", title = "Weapon skills", cap = GROUP_CAP, more = "+%d more weapon skills" },
}

-- Gains in SPEC order; each name is a Blizzard global with an English fallback.
local GAINS = {
  { key = "health", global = "HEALTH", fallback = "Health" },
  { key = "power", global = "MANA", fallback = "Mana" },
  { key = "talents", global = "TALENT_POINTS", fallback = "Talent points" },
  { key = "strength", global = "SPELL_STAT1_NAME", fallback = "Strength" },
  { key = "agility", global = "SPELL_STAT2_NAME", fallback = "Agility" },
  { key = "stamina", global = "SPELL_STAT3_NAME", fallback = "Stamina" },
  { key = "intellect", global = "SPELL_STAT4_NAME", fallback = "Intellect" },
  { key = "spirit", global = "SPELL_STAT5_NAME", fallback = "Spirit" },
}

local Window = {}

local db
local frame
local content
local current
local gainLines = {}
local rows = {}
local headings = {}
local moreLines = {}
local rowsUsed

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
  end)
  AutoHide.Attach(frame, db)
  frame.CloseButton:SetScript("OnClick", AutoHide.Close)
  content = _G.CreateFrame("Frame", nil, frame)
  content:SetSize(CONTENT_WIDTH, 1)
  content:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, -HEADER_HEIGHT)
  for _, spec in ipairs(GROUPS) do
    headings[spec.group] = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    if spec.cap then
      moreLines[spec.group] = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    end
  end
end

-- Puts a region at the cursor and returns the cursor below it.
local function place(region, x, y, height)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
  region:Show()
  return y + height
end

local function gainText(record, gain)
  local amount = record.gains[gain.key]
  if not amount or amount == 0 then
    return nil
  end
  local name = _G[gain.global] or Text(gain.fallback)
  local before = record.before and record.before[gain.key]
  if gain.key == "talents" or not before then
    return format(Text("+%d %s"), amount, name)
  end
  return format(Text("%s %d → %d"), name, before, before + amount)
end

local function fillGains(record, y)
  local used = 0
  for _, gain in ipairs(GAINS) do
    local text = gainText(record, gain)
    if text then
      used = used + 1
      gainLines[used] = gainLines[used] or content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      gainLines[used]:SetText(text)
      y = place(gainLines[used], TEXT_LEFT, y, LINE_HEIGHT)
    end
  end
  for index = used + 1, #gainLines do
    gainLines[index]:Hide()
  end
  return y
end

local function nextRow()
  rowsUsed = rowsUsed + 1
  rows[rowsUsed] = rows[rowsUsed] or SkillRow.Create(content, AutoHide.Pause, AutoHide.Resume)
  return rows[rowsUsed]
end

-- The `+N more` line of a capped group, shown only when rows were left out.
local function fillMore(spec, count, y)
  local line = moreLines[spec.group]
  if not line then
    return y
  end
  local hidden = count - spec.cap
  if hidden <= 0 then
    line:Hide()
    return y
  end
  line:SetText(format(Text(spec.more), hidden))
  return place(line, TEXT_LEFT, y, LINE_HEIGHT)
end

local function fillGroup(spec, entries, money, y)
  local heading = headings[spec.group]
  local count = 0
  for _, entry in ipairs(entries) do
    if entry.group == spec.group then
      count = count + 1
      if count == 1 then
        heading:SetText(Text(spec.title))
        y = place(heading, TEXT_LEFT, y, HEADING_HEIGHT)
      end
      if not spec.cap or count <= spec.cap then
        local row = nextRow()
        SkillRow.SetSkill(row, entry, money)
        y = place(row, 0, y, ROW_HEIGHT)
      end
    end
  end
  if count == 0 then
    heading:Hide()
  end
  return fillMore(spec, count, y)
end

local function fillSkills(record, y)
  local class = select(2, _G.UnitClass("player"))
  local race = select(2, _G.UnitRace("player"))
  local faction = _G.UnitFactionGroup("player")
  local entries, showHint = SkillList.Build(db.trainers, class, race, faction, record.fromLevel, record.toLevel)
  local money = _G.GetMoney()
  rowsUsed = 0
  if y > 0 and (#entries > 0 or showHint) then
    y = y + SECTION_GAP
  end
  for _, spec in ipairs(GROUPS) do
    y = fillGroup(spec, entries, money, y)
  end
  if showHint then
    local row = nextRow()
    SkillRow.SetHint(row)
    y = place(row, 0, y, ROW_HEIGHT)
  end
  for index = rowsUsed + 1, #rows do
    rows[index]:Hide()
  end
  return y
end

local function fill(record)
  frame:SetTitle(format(Text("Level %d"), record.toLevel))
  local height = fillSkills(record, fillGains(record, 0))
  content:SetHeight(height)
  frame:SetSize(FRAME_WIDTH, HEADER_HEIGHT + height + FOOTER_HEIGHT)
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
  fill(record)
  Window.ApplyScale()
  applyAnchor()
  frame:Show()
  AutoHide.Resume()
end

ns.Window = Window
return Window
