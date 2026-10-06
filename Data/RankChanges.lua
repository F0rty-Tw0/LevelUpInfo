local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")

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

-- A number at `pos`: digits, plus `.` and digits when a digit follows the dot.
local function readNumber(text, pos)
  local _, stop = find(text, "^%d+", pos)
  if not stop then
    return nil
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

local function addLine(lines, label, old, new)
  if #lines < MAX_LINES then
    lines[#lines + 1] = format(Text("%s: %s → %s"), label, old, NEW_VALUE_COLOR .. new .. COLOR_END)
  end
end

local function addValueLine(lines, old, new)
  if new.unit == Text("sec") then
    addLine(lines, Text("Duration"), format(Text("%s sec"), old.display), format(Text("%s sec"), new.display))
  elseif new.unit == Text("min") then
    addLine(lines, Text("Duration"), format(Text("%s min"), old.display), format(Text("%s min"), new.display))
  else
    addLine(lines, keywordLabel(new.words), old.display, new.display)
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

local function cooldownText(ms)
  if ms == 0 then
    return Text("None")
  end
  if ms >= MS_PER_MINUTE and ms % MS_PER_MINUTE == 0 then
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

local function addStatLines(lines, old, new)
  if changed(old.cost, new.cost) then
    addLine(lines, costLabel(new.powerToken), old.cost, new.cost)
  end
  if changed(old.castTime, new.castTime) then
    addLine(lines, Text("Cast time"), castTimeText(old.castTime), castTimeText(new.castTime))
  end
  if changed(old.cooldown, new.cooldown) then
    addLine(lines, Text("Cooldown"), cooldownText(old.cooldown), cooldownText(new.cooldown))
  end
end

-- Up to MAX_LINES "Label: old → new" lines, description values first, then
-- cost, cast time and cooldown; only values that differ.
function RankChanges.Lines(old, new)
  local lines = {}
  addDescriptionLines(lines, old.description, new.description)
  addStatLines(lines, old, new)
  return lines
end

ns.RankChanges = RankChanges
return RankChanges
