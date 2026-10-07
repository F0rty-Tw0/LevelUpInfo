local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")
local Format = ns.Format or require("LevelUpInfo.Core.Format")

local Text = Localization.Text
local abs = math.abs
local concat = table.concat
local find = string.find
local floor = math.floor
local format = string.format
local gsub = string.gsub
local ipairs = ipairs
local match = string.match
local max = math.max
local reverse = string.reverse
local tonumber = tonumber

-- The colored `(+N)` / `(-N)` after a rank change line's new value.
local RankDiff = {}

local COLOR_END = "|r"
local DECIMAL_BASE = 10
local TIME_FORMAT = "%.1f"

-- A display value ("12-17", "1,000", "10-20%") as its end strings plus its
-- `%` suffix ("" when none).
local function splitEnds(text)
  local body, percent = match(text, "^(.-)(%%?)$")
  local low, high = match(body, "^([^-]+)%-([^-]+)$")
  if low then
    return { low, high }, percent
  end
  return { body }, percent
end

local function decimalsOf(number)
  local fraction = match(number, "%.(%d+)$")
  return fraction and #fraction or 0
end

local function mostDecimals(oldEnds, newEnds)
  local decimals = 0
  for _, ends in ipairs({ oldEnds, newEnds }) do
    for _, number in ipairs(ends) do
      decimals = max(decimals, decimalsOf(number))
    end
  end
  return decimals
end

local function toNumber(number)
  return tonumber((gsub(number, ",", "")))
end

-- Signed new-minus-old change per end, rounded to `decimals`; nil when the
-- ends don't pair up or one isn't a number.
local function endChanges(oldEnds, newEnds, decimals)
  if #oldEnds ~= #newEnds then
    return nil
  end
  local scale = DECIMAL_BASE ^ decimals
  local changes = {}
  for i, newEnd in ipairs(newEnds) do
    local old, new = toNumber(oldEnds[i]), toNumber(newEnd)
    if not old or not new then
      return nil
    end
    local change = new - old
    local rounded = floor(abs(change) * scale + 0.5) / scale
    changes[i] = change < 0 and -rounded or rounded
  end
  return changes
end

-- 1 when no end fell, -1 when no end rose; nil when ends move opposite ways
-- or none moved.
local function direction(changes)
  local up, down = false, false
  for _, change in ipairs(changes) do
    up = up or change > 0
    down = down or change < 0
  end
  if up == down then
    return nil
  end
  return up and 1 or -1
end

local function groupThousands(text)
  local whole, rest = match(text, "^(%d+)(.*)$")
  local grouped = gsub(reverse(whole), "(%d%d%d)", "%1,")
  grouped = gsub(reverse(grouped), "^,", "")
  return grouped .. rest
end

local function magnitudeText(change, decimals, grouped)
  local text = format("%." .. decimals .. "f", abs(change))
  if decimals > 0 then
    text = gsub(text, "0+$", "")
    text = gsub(text, "%.$", "")
  end
  return grouped and groupThousands(text) or text
end

local function colored(sign, lowerIsBetter, body)
  local better = (sign > 0) ~= lowerIsBetter
  local color = better and _G.GREEN_FONT_COLOR or _G.RED_FONT_COLOR
  local template = sign > 0 and Text("(+%s)") or Text("(-%s)")
  return Format.ColorCode(color) .. format(template, body) .. COLOR_END
end

-- Diff text between two display values, or nil when there is none to show.
function RankDiff.Values(oldText, newText, lowerIsBetter)
  local oldEnds = splitEnds(oldText)
  local newEnds, percent = splitEnds(newText)
  local decimals = mostDecimals(oldEnds, newEnds)
  local changes = endChanges(oldEnds, newEnds, decimals)
  local sign = changes and direction(changes)
  if not sign then
    return nil
  end
  local grouped = find(oldText .. newText, ",", 1, true) ~= nil
  local parts = {}
  for i, change in ipairs(changes) do
    parts[i] = magnitudeText(change, decimals, grouped)
  end
  if parts[2] == parts[1] then
    parts[2] = nil
  end
  return colored(sign, lowerIsBetter, concat(parts, "-") .. percent)
end

local function unitText(ms, unitMs)
  return (gsub(format(TIME_FORMAT, ms / unitMs), "%.0$", ""))
end

-- Diff text between two millisecond amounts in `unitMs` units (lower is
-- better, at most one decimal), or nil when there is none to show.
function RankDiff.Times(oldMs, newMs, unitMs)
  return RankDiff.Values(unitText(oldMs, unitMs), unitText(newMs, unitMs), true)
end

ns.RankDiff = RankDiff
return RankDiff
