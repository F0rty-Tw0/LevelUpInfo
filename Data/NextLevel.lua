local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BuiltinSpells = ns.BuiltinSpells or require("LevelUpInfo.Data.BuiltinSpells")
local SkillList = ns.SkillList or require("LevelUpInfo.Data.SkillList")

local pairs = pairs
local ipairs = ipairs
local max = math.max

local NextLevel = {}

local NO_LEVEL = 0
local EMPTY = {}

local function highestLevel(levels)
  local highest = NO_LEVEL
  for level in pairs(levels) do
    if level > highest then
      highest = level
    end
  end
  return highest
end

-- Trainer-cache entries first listed at `level`: quest and weapon rows carry a source.
local function ownEntriesAt(entries, level)
  local found = {}
  for _, entry in ipairs(entries) do
    if entry.level == level and entry.source == nil then
      found[#found + 1] = entry
    end
  end
  return found
end

-- The lowest level above toLevel, in the trainer cache or the built-in table,
-- with a skill the trainer would sell you there, and those skills in the
-- skill list's order; nil when none.
function NextLevel.Find(trainers, class, race, faction, toLevel)
  local live = trainers[class]
  local liveLevels = live and live.levels or EMPTY
  local builtinLevels = BuiltinSpells[class] or EMPTY
  for level = toLevel + 1, max(highestLevel(liveLevels), BuiltinSpells.MaxLevel(class)) do
    if liveLevels[level] ~= nil or builtinLevels[level] ~= nil then
      local found = ownEntriesAt(SkillList.Build(trainers, class, race, faction, level - 1, level), level)
      if #found > 0 then
        return level, found
      end
    end
  end
  return nil
end

ns.NextLevel = NextLevel
return NextLevel
