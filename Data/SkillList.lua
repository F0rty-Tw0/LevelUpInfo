local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TrainerCache = ns.TrainerCache or require("LevelUpInfo.Data.TrainerCache")
local OtherSources = ns.OtherSources or require("LevelUpInfo.Data.OtherSources")
local WeaponIcons = ns.WeaponIcons or require("LevelUpInfo.Data.WeaponIcons")

local ipairs = ipairs
local match = string.match
local pairs = pairs
local pcall = pcall
local sort = table.sort
local tonumber = tonumber

local SkillList = {}

-- Classic Era and TBC drop IsPlayerSpell unless a deprecation CVar is on.
local function isKnown(spellID)
  if _G.IsPlayerSpell then
    return _G.IsPlayerSpell(spellID)
  end
  return _G.C_SpellBook.IsSpellKnown(spellID)
end

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

local FIRST_NEW_RANK = 2

-- The first number in the rank text; nil for "" or "Apprentice".
local function rankNumber(rank)
  return tonumber(match(rank, "%d+"))
end

-- The cached rank text, or the spell's own subtext when the trainer gave
-- none (it leaves it empty for spells above your level).
local function rankOf(spellID, entry)
  if entry.rank ~= "" or _G.C_Spell.GetSpellSubtext == nil then
    return entry.rank
  end
  return _G.C_Spell.GetSpellSubtext(spellID) or ""
end

local function isNewRank(rank)
  return (rankNumber(rank) or 0) >= FIRST_NEW_RANK
end

local function rankKey(name, number)
  return name .. ":" .. number
end

-- Class cache over levels 1..toLevel: spell name + rank number to the lowest spellID.
local function rankIndex(data, toLevel)
  local index = {}
  for level = 1, toLevel do
    for spellID, entry in pairs(data.levels[level] or {}) do
      local number = rankNumber(rankOf(spellID, entry))
      local info = number and _G.C_Spell.GetSpellInfo(spellID)
      if info then
        local key = rankKey(info.name, number)
        if index[key] == nil or spellID < index[key] then
          index[key] = spellID
        end
      end
    end
  end
  return index
end

-- Starting spells' Rank 1 is never sold by a trainer: take the known spell
-- of that name when its rank text has the wanted number. The by-name call is
-- guarded: a client that rejects a string argument gives no previous rank.
local function knownPrevious(name, previous)
  if _G.C_Spell.GetSpellSubtext == nil then
    return nil
  end
  local ok, known = pcall(_G.C_Spell.GetSpellInfo, name)
  if ok and known and rankNumber(_G.C_Spell.GetSpellSubtext(known.spellID) or "") == previous then
    return known.spellID
  end
  return nil
end

-- The index is built only when a new rank is listed.
local function addPreviousRanks(entries, data, toLevel)
  local index
  for _, entry in ipairs(entries) do
    if entry.newRank then
      index = index or rankIndex(data, toLevel)
      local previous = rankNumber(entry.rank) - 1
      entry.previousSpellID = index[rankKey(entry.name, previous)] or knownPrevious(entry.name, previous)
    end
  end
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
    if isVisible(data.covered, race, level, entry) and not isKnown(spellID) then
      local info = _G.C_Spell.GetSpellInfo(spellID)
      if info then
        local rank = rankOf(spellID, entry)
        local newRank = isNewRank(rank)
        bySpell[spellID] = {
          spellID = spellID,
          level = level,
          name = info.name,
          icon = info.iconID,
          rank = rank,
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
    and not isKnown(row.spellID)
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
      icon = (row.kind == "weapon" and WeaponIcons[row.spellID]) or info.iconID,
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
  addPreviousRanks(entries, data, toLevel)
  sort(entries, byGroupThenLevelThenName)
  return entries, TrainerCache.Covered(trainers, class, race) < toLevel
end

ns.SkillList = SkillList
return SkillList
