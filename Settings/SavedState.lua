local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Defaults = ns.SettingsDefaults or require("LevelUpInfo.Settings.Defaults")

local floor, min, max = math.floor, math.min, math.max
local next, pairs, ipairs, type = next, pairs, ipairs, type

-- Steps like 0.05 leave float noise; round to 2 decimals so 1.05 == 1.05.
local DECIMAL_SCALE = 100

local ANCHOR_POINTS = {
  TOPLEFT = true,
  TOP = true,
  TOPRIGHT = true,
  LEFT = true,
  CENTER = true,
  RIGHT = true,
  BOTTOMLEFT = true,
  BOTTOM = true,
  BOTTOMRIGHT = true,
}

local SavedState = {}

local function isNumber(value)
  return type(value) == "number" and value == value
end

local function isPositiveInteger(value)
  return isNumber(value) and value > 0 and value % 1 == 0
end

local function round(value)
  return floor(value + 0.5)
end

local function normalizeNumber(value, setting)
  if not isNumber(value) then
    return setting.default
  end
  local stepped = setting.min + round((value - setting.min) / setting.step) * setting.step
  stepped = round(stepped * DECIMAL_SCALE) / DECIMAL_SCALE
  return min(setting.max, max(setting.min, stepped))
end

local function normalizeSetting(value, setting)
  if setting.kind == "slider" then
    return normalizeNumber(value, setting)
  end
  if type(value) == "boolean" then
    return value
  end
  return setting.default
end

-- Same rule the saved value gets on load; the options panel reuses it for slider values.
SavedState.NormalizeSetting = normalizeSetting

local function normalizePosition(position)
  if type(position) ~= "table" or not ANCHOR_POINTS[position.point] then
    return nil
  end
  if not isNumber(position.x) or not isNumber(position.y) then
    return nil
  end
  return { point = position.point, x = position.x, y = position.y }
end

local function cleanRaces(races)
  if type(races) ~= "table" then
    return nil
  end
  local clean = {}
  for race, seen in pairs(races) do
    if type(race) == "string" and seen == true then
      clean[race] = true
    end
  end
  return next(clean) and clean or nil
end

local function cleanEntry(entry)
  if type(entry) ~= "table" or not isNumber(entry.cost) or type(entry.rank) ~= "string" then
    return nil
  end
  local races = cleanRaces(entry.races)
  if not races then
    return nil
  end
  return { cost = entry.cost, rank = entry.rank, races = races }
end

local function cleanLevel(entries)
  if type(entries) ~= "table" then
    return nil
  end
  local clean = {}
  for spellID, entry in pairs(entries) do
    if isPositiveInteger(spellID) then
      clean[spellID] = cleanEntry(entry)
    end
  end
  return next(clean) and clean or nil
end

local function cleanLevels(levels)
  local clean = {}
  if type(levels) ~= "table" then
    return clean
  end
  for level, entries in pairs(levels) do
    if isPositiveInteger(level) then
      clean[level] = cleanLevel(entries)
    end
  end
  return clean
end

local function cleanCovered(covered)
  local clean = {}
  if type(covered) ~= "table" then
    return clean
  end
  for race, level in pairs(covered) do
    if type(race) == "string" and isPositiveInteger(level) then
      clean[race] = level
    end
  end
  return clean
end

local function cleanTrainers(trainers)
  local clean = {}
  if type(trainers) ~= "table" then
    return clean
  end
  for class, data in pairs(trainers) do
    if type(class) == "string" and type(data) == "table" then
      clean[class] = { covered = cleanCovered(data.covered), levels = cleanLevels(data.levels) }
    end
  end
  return clean
end

function SavedState.Initialize(saved)
  saved = type(saved) == "table" and saved or {}
  local db = {
    position = normalizePosition(saved.position),
    trainers = cleanTrainers(saved.trainers),
  }
  for _, setting in ipairs(Defaults.list) do
    db[setting.key] = normalizeSetting(saved[setting.key], setting)
  end
  return db
end

ns.SavedState = SavedState
return SavedState
