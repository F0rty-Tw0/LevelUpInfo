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
-- A faint 1 px line centered in the 14 px block gap under the talent line.
local DIVIDER_WIDTH = 290
local DIVIDER_HEIGHT = 1
local DIVIDER_GAP_ABOVE = 7
local DIVIDER_GAP_BELOW = 6
local DIVIDER_ALPHA = 0.15

-- Gains in display order; each name is a Blizzard global with an English fallback,
-- shown in its own stat color (6-digit hex). Talent points come first, above the
-- `Stats` heading.
local GAINS = {
  { key = "talents", global = "TALENT_POINTS", fallback = "Talent points", color = "c084fc" },
  { key = "health", global = "HEALTH", fallback = "Health", color = "49d36b" },
  { key = "power", global = "MANA", fallback = "Mana", color = "4d8dff" },
  { key = "strength", global = "SPELL_STAT1_NAME", fallback = "Strength", color = "ff5c5c" },
  { key = "agility", global = "SPELL_STAT2_NAME", fallback = "Agility", color = "ffa340" },
  { key = "stamina", global = "SPELL_STAT3_NAME", fallback = "Stamina", color = "d9b38c" },
  { key = "intellect", global = "SPELL_STAT4_NAME", fallback = "Intellect", color = "4fd1e8" },
  { key = "spirit", global = "SPELL_STAT5_NAME", fallback = "Spirit", color = "f5a3d0" },
}

-- The window's gain lines: the talent line, then a divider and the stat
-- lines under a `Stats` heading. Pooled font strings on the content frame.
local GainLines = {}

local heading
local divider
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

-- Makes the heading and divider; called once when the window is built.
function GainLines.Build(content)
  heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  heading:SetText(Text("Stats"))
  divider = content:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(1, 1, 1, DIVIDER_ALPHA)
  divider:SetSize(DIVIDER_WIDTH, DIVIDER_HEIGHT)
end

-- Before the first stat line: the divider when the talent line is above it,
-- then the heading.
local function addStatsTop(content, talentShown)
  if talentShown then
    Layout.AddGap(content, DIVIDER_GAP_ABOVE)
    Layout.Add(divider, content, TEXT_LEFT, DIVIDER_HEIGHT)
    Layout.AddGap(content, DIVIDER_GAP_BELOW)
  end
  Layout.Add(heading, content, TEXT_LEFT, HEADING_HEIGHT)
end

-- Sets and lays out one line per non-zero gain, with the heading and divider
-- around the stat lines; returns how many lines were used.
function GainLines.Fill(content, record)
  if not green then
    green = Format.ColorCode(_G.GREEN_FONT_COLOR)
  end
  local used = 0
  local stats = 0
  for _, gain in ipairs(GAINS) do
    local amount = record.gains[gain.key]
    if amount and amount ~= 0 then
      if gain.key ~= "talents" then
        if stats == 0 then
          addStatsTop(content, used > 0)
        end
        stats = stats + 1
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
  if stats == 0 then
    heading:Hide()
  end
  if stats == 0 or stats == used then
    divider:Hide()
  end
  return used
end

function GainLines.HideAll()
  heading:Hide()
  divider:Hide()
  for _, line in ipairs(lines) do
    line:Hide()
  end
end

ns.GainLines = GainLines
return GainLines
