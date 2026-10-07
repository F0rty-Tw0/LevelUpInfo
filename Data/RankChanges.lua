local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")
local Format = ns.Format or require("LevelUpInfo.Core.Format")
local RankDiff = ns.RankDiff or require("LevelUpInfo.Data.RankDiff")

local Text = Localization.Text
local concat = table.concat
local find = string.find
local format = string.format
local gmatch = string.gmatch
local gsub = string.gsub
local ipairs = ipairs
local lower = string.lower
local match = string.match
local sub = string.sub
local tostring = tostring

local RankChanges = {}

local MAX_LINES = 4
local MS_PER_SECOND = 1000
local MS_PER_MINUTE = 60000
local NEW_VALUE_COLOR = "|cffffffff"
local COLOR_END = "|r"

-- Label groups in priority order; a value's sentence matches a group when
-- any of its words equals one of the group's words.
local KEYWORD_GROUPS = {
  { label = "Absorb", words = { "absorb", "absorbs", "absorbing" } },
  { label = "Healing", words = { "heal", "heals", "healing" } },
  { label = "Damage", words = { "damage" } },
  { label = "Armor", words = { "armor" } },
  { label = "Mana", words = { "mana" } },
}

-- A number at `pos`: digits, then each `,` + exactly three digits (thousands
-- separator), plus `.` and digits when a digit follows the dot.
local function readNumber(text, pos)
  local _, stop = find(text, "^%d+", pos)
  if not stop then
    return nil
  end
  while true do
    local _, groupStop = find(text, "^,%d%d%d", stop + 1)
    if not groupStop or find(text, "^%d", groupStop + 1) then
      break
    end
    stop = groupStop
  end
  local _, fractionStop = find(text, "^%.%d+", stop + 1)
  stop = fractionStop or stop
  return sub(text, pos, stop), stop
end

-- A value at `pos`: a number or a range (number, " to ", number) shown as
-- a-b; a `%` right after it joins the display but stays in the template.
local function readValue(text, pos)
  local display, stop = readNumber(text, pos)
  local to = Text(" to ")
  if sub(text, stop + 1, stop + #to) == to then
    local second, secondStop = readNumber(text, stop + #to + 1)
    if second then
      display, stop = display .. "-" .. second, secondStop
    end
  end
  local unit = match(text, "^%s*(%a+)", stop + 1)
  if sub(text, stop + 1, stop + 1) == "%" then
    display = display .. "%"
  end
  return { display = display, unit = unit }, stop
end

local function wordsOf(sentence)
  local words = {}
  for word in gmatch(lower(sentence), "%a+") do
    words[word] = true
  end
  return words
end

-- Adds the sentence's values to `values` and its template pieces to `parts`.
local function parseSentence(sentence, values, parts)
  local words = wordsOf(sentence)
  local pos = 1
  while true do
    local start = find(sentence, "%d", pos)
    if not start then
      break
    end
    local value, stop = readValue(sentence, start)
    value.words = words
    values[#values + 1] = value
    parts[#parts + 1] = sub(sentence, pos, start - 1) .. "#"
    pos = stop + 1
  end
  parts[#parts + 1] = sub(sentence, pos)
end

-- Values in text order and the template (every value replaced by `#`).
-- Sentences end at a `.` followed by whitespace or the end of the text.
local function parse(description)
  local values, parts = {}, {}
  local pos = 1
  for dot in gmatch(description, "()%.%s") do
    parseSentence(sub(description, pos, dot), values, parts)
    pos = dot + 1
  end
  parseSentence(sub(description, pos), values, parts)
  return values, concat(parts)
end

local function keywordLabel(words)
  for _, group in ipairs(KEYWORD_GROUPS) do
    for _, word in ipairs(group.words) do
      if words[Text(word)] then
        return Text(group.label)
      end
    end
  end
  return Text("Effect")
end

-- Callers check this before computing a diff, so dropped lines cost nothing.
local function full(lines)
  return #lines >= MAX_LINES
end

-- `diff` is the colored difference text, or nil for none.
local function addLine(lines, label, old, new, diff)
  local newText = NEW_VALUE_COLOR .. new .. COLOR_END
  if diff then
    lines[#lines + 1] = format(Text("%s: %s %s %s %s"), label, old, Format.ARROW, newText, diff)
  else
    lines[#lines + 1] = format(Text("%s: %s %s %s"), label, old, Format.ARROW, newText)
  end
end

local function addValueLine(lines, old, new)
  if full(lines) then
    return
  end
  local diff = RankDiff.Values(old.display, new.display, false)
  if new.unit == Text("sec") then
    addLine(lines, Text("Duration"), format(Text("%s sec"), old.display), format(Text("%s sec"), new.display), diff)
  elseif new.unit == Text("min") then
    addLine(lines, Text("Duration"), format(Text("%s min"), old.display), format(Text("%s min"), new.display), diff)
  else
    addLine(lines, keywordLabel(new.words), old.display, new.display, diff)
  end
end

local function addDescriptionLines(lines, oldText, newText)
  local oldValues, oldTemplate = parse(oldText or "")
  local newValues, newTemplate = parse(newText or "")
  if oldTemplate ~= newTemplate then
    return
  end
  for i, new in ipairs(newValues) do
    if oldValues[i].display ~= new.display then
      addValueLine(lines, oldValues[i], new)
    end
  end
end

local function seconds(ms)
  local text = gsub(format("%.1f", ms / MS_PER_SECOND), "%.0$", "")
  return format(Text("%s sec"), text)
end

local function castTimeText(ms)
  if ms == 0 then
    return Text("Instant")
  end
  return seconds(ms)
end

-- Cooldowns show in minutes when whole minutes, else in seconds.
local function cooldownUnit(ms)
  if ms >= MS_PER_MINUTE and ms % MS_PER_MINUTE == 0 then
    return MS_PER_MINUTE
  end
  return MS_PER_SECOND
end

local function cooldownText(ms)
  if ms == 0 then
    return Text("None")
  end
  if cooldownUnit(ms) == MS_PER_MINUTE then
    return format(Text("%s min"), format("%d", ms / MS_PER_MINUTE))
  end
  return seconds(ms)
end

local function costLabel(powerToken)
  local powerName = powerToken and _G[powerToken]
  if type(powerName) == "string" then
    return format(Text("%s cost"), powerName)
  end
  return Text("Cost")
end

local function changed(old, new)
  return old ~= nil and new ~= nil and old ~= new
end

-- Cost, cast time and cooldown: lower is better. A cooldown diff is in the
-- new value's unit, or the old value's when the new one is None.
local function addStatLines(lines, old, new)
  if not full(lines) and changed(old.cost, new.cost) then
    local oldCost, newCost = tostring(old.cost), tostring(new.cost)
    addLine(lines, costLabel(new.powerToken), oldCost, newCost, RankDiff.Values(oldCost, newCost, true))
  end
  if not full(lines) and changed(old.castTime, new.castTime) then
    local diff = RankDiff.Times(old.castTime, new.castTime, MS_PER_SECOND)
    addLine(lines, Text("Cast time"), castTimeText(old.castTime), castTimeText(new.castTime), diff)
  end
  if not full(lines) and changed(old.cooldown, new.cooldown) then
    local unit = cooldownUnit(new.cooldown ~= 0 and new.cooldown or old.cooldown)
    local diff = RankDiff.Times(old.cooldown, new.cooldown, unit)
    addLine(lines, Text("Cooldown"), cooldownText(old.cooldown), cooldownText(new.cooldown), diff)
  end
end

-- Up to MAX_LINES "Label: old ARROW new (diff)" lines, description values
-- first, then cost, cast time and cooldown; only values that differ.
function RankChanges.Lines(old, new)
  local lines = {}
  addDescriptionLines(lines, old.description, new.description)
  addStatLines(lines, old, new)
  return lines
end

ns.RankChanges = RankChanges
return RankChanges
