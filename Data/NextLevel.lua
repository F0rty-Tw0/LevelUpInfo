local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SkillList = ns.SkillList or require("LevelUpInfo.Data.SkillList")

local pairs = pairs
local ipairs = ipairs

local NextLevel = {}

local NO_LEVEL = 0

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

-- The lowest cached level above toLevel with a skill the trainer would sell
-- you there, and those skills in the skill list's order; nil when none.
function NextLevel.Find(trainers, class, race, faction, toLevel)
  local data = trainers[class]
  if not data then
    return nil
  end
  for level = toLevel + 1, highestLevel(data.levels) do
    if data.levels[level] then
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
