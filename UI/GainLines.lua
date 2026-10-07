local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")
local Format = ns.Format or require("LevelUpInfo.Core.Format")
local Layout = ns.Layout or require("LevelUpInfo.UI.Layout")

local format = string.format
local ipairs = ipairs
local tostring = tostring

local Text = Localization.Text

local LINE_HEIGHT = 16
local HEADING_HEIGHT = 24 -- same heading line as the skill groups
local TEXT_LEFT = 4
local OLD_VALUE_COLOR = "|cff808080" -- the gray of GameFontDisable

-- Gains in display order; each name is a Blizzard global with an English fallback,
-- shown in its own stat color (6-digit hex).
local GAINS = {
  { key = "health", global = "HEALTH", fallback = "Health", color = "49d36b" },
  { key = "power", global = "MANA", fallback = "Mana", color = "4d8dff" },
  { key = "talents", global = "TALENT_POINTS", fallback = "Talent points", color = "c084fc" },
  { key = "strength", global = "SPELL_STAT1_NAME", fallback = "Strength", color = "ff5c5c" },
  { key = "agility", global = "SPELL_STAT2_NAME", fallback = "Agility", color = "ffa340" },
  { key = "stamina", global = "SPELL_STAT3_NAME", fallback = "Stamina", color = "d9b38c" },
  { key = "intellect", global = "SPELL_STAT4_NAME", fallback = "Intellect", color = "4fd1e8" },
  { key = "spirit", global = "SPELL_STAT5_NAME", fallback = "Spirit", color = "f5a3d0" },
}

-- The window's stat gain lines under a `Stats` heading: pooled font strings
-- on the content frame.
local GainLines = {}

local heading
local lines = {}
local green -- "|cffRRGGBB" from GREEN_FONT_COLOR, set on first fill

-- Text for one non-zero gain: `Name old ARROW new (+N)` with old gray, or
-- `Name (+N)` for talents and a missing before.
local function gainText(record, gain, amount)
  local coloredName = "|cff" .. gain.color .. (_G[gain.global] or Text(gain.fallback)) .. "|r"
  local plus = green .. format(Text("(+%d)"), amount) .. "|r"
  local before = record.before and record.before[gain.key]
  if gain.key == "talents" or not before then
    return format(Text("%s %s"), coloredName, plus)
  end
  local old = OLD_VALUE_COLOR .. tostring(before) .. "|r"
  return format(Text("%s %s %s %s %s"), coloredName, old, Format.ARROW, tostring(before + amount), plus)
end

-- Makes the heading; called once when the window is built.
function GainLines.Build(content)
  heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  heading:SetText(Text("Stats"))
end

-- Sets and lays out the heading and one line per non-zero gain; returns how
-- many lines were used.
function GainLines.Fill(content, record)
  if not green then
    green = Format.ColorCode(_G.GREEN_FONT_COLOR)
  end
  local used = 0
  for _, gain in ipairs(GAINS) do
    local amount = record.gains[gain.key]
    if amount and amount ~= 0 then
      if used == 0 then
        Layout.Add(heading, content, TEXT_LEFT, HEADING_HEIGHT)
      end
      used = used + 1
      lines[used] = lines[used] or content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      lines[used]:SetText(gainText(record, gain, amount))
      Layout.Add(lines[used], content, TEXT_LEFT, LINE_HEIGHT)
    end
  end
  for index = used + 1, #lines do
    lines[index]:Hide()
  end
  if used == 0 then
    heading:Hide()
  end
  return used
end

function GainLines.HideAll()
  heading:Hide()
  for _, line in ipairs(lines) do
    line:Hide()
  end
end

ns.GainLines = GainLines
return GainLines
