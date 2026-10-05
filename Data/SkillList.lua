local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TrainerCache = ns.TrainerCache or require("LevelUpInfo.Data.TrainerCache")

local match = string.match
local pairs = pairs
local sort = table.sort
local tonumber = tonumber

local SkillList = {}

-- An entry your race has not seen is another race's racial when any race
-- that covered its level lacks it; your own race counts as one of them.
local function isVisible(covered, race, level, entry)
  if entry.races[race] then
    return true
  end
  for otherRace, otherCovered in pairs(covered) do
    if otherCovered >= level and not entry.races[otherRace] then
      return false
    end
  end
  return true
end

-- A new rank when the first number in the rank text is 2 or more.
local function isNewRank(rank)
  return (tonumber(match(rank, "%d+")) or 0) >= 2
end

local GROUP_ORDER = { skill = 1, rank = 2, missed = 3, weapon = 4 }

local function byGroupThenLevelThenName(a, b)
  if a.group ~= b.group then
    return GROUP_ORDER[a.group] < GROUP_ORDER[b.group]
  end
  if a.level ~= b.level then
    return a.level < b.level
  end
  return a.name < b.name
end

-- Missed: at or below the old level, so it could have been bought already.
local function groupOf(level, fromLevel, newRank)
  if level <= fromLevel then
    return "missed"
  end
  return newRank and "rank" or "skill"
end

local function addLevel(entries, data, race, level, fromLevel)
  for spellID, entry in pairs(data.levels[level] or {}) do
    if isVisible(data.covered, race, level, entry) and not _G.IsPlayerSpell(spellID) then
      local info = _G.C_Spell.GetSpellInfo(spellID)
      if info then
        local newRank = isNewRank(entry.rank)
        entries[#entries + 1] = {
          spellID = spellID,
          level = level,
          name = info.name,
          icon = info.iconID,
          rank = entry.rank,
          cost = entry.cost,
          newRank = newRank,
          group = groupOf(level, fromLevel, newRank),
        }
      end
    end
  end
end

-- Unlearned trainer skills up to toLevel: new skills and new ranks from
-- (fromLevel, toLevel], then the ones skipped at or below fromLevel;
-- plus whether to show the hint row.
function SkillList.Build(trainers, class, race, _faction, fromLevel, toLevel)
  local entries = {}
  local data = trainers[class]
  if data then
    for level = 1, toLevel do
      addLevel(entries, data, race, level, fromLevel)
    end
  end
  sort(entries, byGroupThenLevelThenName)
  return entries, TrainerCache.Covered(trainers, class, race) < toLevel
end

ns.SkillList = SkillList
return SkillList
