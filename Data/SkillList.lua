local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TrainerCache = ns.TrainerCache or require("LevelUpInfo.Data.TrainerCache")
local OtherSources = ns.OtherSources or require("LevelUpInfo.Data.OtherSources")

local ipairs = ipairs
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

-- Weapon skills sort by name only; the other groups by level, then name.
local function byGroupThenLevelThenName(a, b)
  if a.group ~= b.group then
    return GROUP_ORDER[a.group] < GROUP_ORDER[b.group]
  end
  if a.group ~= "weapon" and a.level ~= b.level then
    return a.level < b.level
  end
  if a.name ~= b.name then
    return a.name < b.name
  end
  return a.spellID < b.spellID
end

-- Missed: at or below the old level, so it could have been bought already.
local function groupOf(level, fromLevel, newRank)
  if level <= fromLevel then
    return "missed"
  end
  return newRank and "rank" or "skill"
end

local function addLevel(bySpell, data, race, level, fromLevel)
  for spellID, entry in pairs(data.levels[level] or {}) do
    if isVisible(data.covered, race, level, entry) and not _G.IsPlayerSpell(spellID) then
      local info = _G.C_Spell.GetSpellInfo(spellID)
      if info then
        local newRank = isNewRank(entry.rank)
        bySpell[spellID] = {
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

local function rowApplies(row, race, faction, toLevel)
  return row.level <= toLevel
    and (row.race == nil or row.race == race)
    and (row.faction == nil or row.faction == faction)
    and not _G.IsPlayerSpell(row.spellID)
end

-- A quest row yields to any visible candidate with its spell; a weapon row
-- replaces a trainer entry but yields to an earlier weapon row.
local function isTaken(bySpell, row)
  local taken = bySpell[row.spellID]
  if row.kind == "weapon" then
    return taken ~= nil and taken.group == "weapon"
  end
  return taken ~= nil
end

local function addOtherSource(bySpell, row, fromLevel)
  if isTaken(bySpell, row) then
    return
  end
  local info = _G.C_Spell.GetSpellInfo(row.spellID)
  if info then
    bySpell[row.spellID] = {
      spellID = row.spellID,
      level = row.level,
      name = info.name,
      icon = info.iconID,
      rank = "",
      cost = row.cost,
      newRank = false,
      group = row.kind == "weapon" and "weapon" or groupOf(row.level, fromLevel, false),
      source = row,
    }
  end
end

-- Unlearned trainer, quest and weapon-master skills up to toLevel: new skills
-- and new ranks from (fromLevel, toLevel], then the ones skipped at or below
-- fromLevel, then weapon skills; plus whether to show the hint row.
function SkillList.Build(trainers, class, race, faction, fromLevel, toLevel)
  local bySpell = {}
  local data = trainers[class]
  if data then
    for level = 1, toLevel do
      addLevel(bySpell, data, race, level, fromLevel)
    end
  end
  for _, row in ipairs(OtherSources[class] or {}) do
    if rowApplies(row, race, faction, toLevel) then
      addOtherSource(bySpell, row, fromLevel)
    end
  end
  local entries = {}
  for _, entry in pairs(bySpell) do
    entries[#entries + 1] = entry
  end
  sort(entries, byGroupThenLevelThenName)
  return entries, TrainerCache.Covered(trainers, class, race) < toLevel
end

ns.SkillList = SkillList
return SkillList
