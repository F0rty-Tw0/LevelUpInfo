local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")
local Layout = ns.Layout or require("LevelUpInfo.UI.Layout")

local floor = math.floor
local format = string.format
local ipairs = ipairs
local tostring = tostring

local Text = Localization.Text

local LINE_HEIGHT = 16
local TEXT_LEFT = 4
local COLOR_SCALE = 255
local ARROW_FORMAT = "|TInterface\\Buttons\\Arrow-Up-Up:14:14:0:0:32:32:0:32:0:32:%d:%d:%d|t"

-- Gains in SPEC order; each name is a Blizzard global with an English fallback,
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

-- The window's stat gain lines: pooled font strings on the content frame.
local GainLines = {}

local lines = {}
local arrow

local function to255(c)
  return floor(c * COLOR_SCALE + 0.5)
end

local function gainText(record, gain)
  local amount = record.gains[gain.key]
  if not amount or amount == 0 then
    return nil
  end
  local coloredName = "|cff" .. gain.color .. (_G[gain.global] or Text(gain.fallback)) .. "|r"
  local before = record.before and record.before[gain.key]
  if gain.key == "talents" or not before then
    return format(Text("%s %s %s"), arrow, format(Text("+%d"), amount), coloredName)
  end
  return format(Text("%s %s %s %s"), coloredName, tostring(before), arrow, tostring(before + amount))
end

-- Sets and lays out one line per non-zero gain; returns how many were used.
function GainLines.Fill(content, record)
  if not arrow then
    local r, g, b = _G.GREEN_FONT_COLOR:GetRGB()
    arrow = format(ARROW_FORMAT, to255(r), to255(g), to255(b))
  end
  local used = 0
  for _, gain in ipairs(GAINS) do
    local text = gainText(record, gain)
    if text then
      used = used + 1
      lines[used] = lines[used] or content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      lines[used]:SetText(text)
      Layout.Add(lines[used], content, TEXT_LEFT, LINE_HEIGHT)
    end
  end
  for index = used + 1, #lines do
    lines[index]:Hide()
  end
  return used
end

function GainLines.HideAll()
  for _, line in ipairs(lines) do
    line:Hide()
  end
end

ns.GainLines = GainLines
return GainLines
