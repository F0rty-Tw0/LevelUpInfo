local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TrainerCache = ns.TrainerCache or require("LevelUpInfo.Data.TrainerCache")

local pairs = pairs
local sort = table.sort

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

local function byLevelThenName(a, b)
  if a.level ~= b.level then
    return a.level < b.level
  end
  return a.name < b.name
end

local function addLevel(entries, data, race, level)
  for spellID, entry in pairs(data.levels[level] or {}) do
    if isVisible(data.covered, race, level, entry) and not _G.IsPlayerSpell(spellID) then
      local info = _G.C_Spell.GetSpellInfo(spellID)
      if info then
        entries[#entries + 1] = {
          spellID = spellID,
          level = level,
          name = info.name,
          icon = info.iconID,
          rank = entry.rank,
          cost = entry.cost,
        }
      end
    end
  end
end

-- Skills new in levels (fromLevel, toLevel], and whether to show the hint row.
function SkillList.Build(trainers, class, race, fromLevel, toLevel)
  local entries = {}
  local data = trainers[class]
  if data then
    for level = fromLevel + 1, toLevel do
      addLevel(entries, data, race, level)
    end
  end
  sort(entries, byLevelThenName)
  return entries, TrainerCache.Covered(trainers, class, race) < toLevel
end

ns.SkillList = SkillList
return SkillList
