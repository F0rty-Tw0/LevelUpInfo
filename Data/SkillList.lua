local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TrainerCache = ns.TrainerCache or require("LevelUpInfo.Data.TrainerCache")
local OtherSources = ns.OtherSources or require("LevelUpInfo.Data.OtherSources")
local WeaponIcons = ns.WeaponIcons or require("LevelUpInfo.Data.WeaponIcons")
local BuiltinSpells = ns.BuiltinSpells or require("LevelUpInfo.Data.BuiltinSpells")

local ipairs = ipairs
local match = string.match
local next = next
local pairs = pairs
local pcall = pcall
local sort = table.sort
local tonumber = tonumber

local SkillList = {}

local MIN_PRICED_FOR_TOTAL = 2
local NO_DATA = { covered = {}, levels = {} }
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

-- No cached rank text and no subtext yet, and the caller still waits for it:
-- the entry is left out until the text arrives (it may be an unbuyable rank).
local function isRankPending(spellID, entry, isWaiting)
  local getSubtext = _G.C_Spell.GetSpellSubtext
  return isWaiting ~= nil and entry.rank == "" and getSubtext ~= nil and (getSubtext(spellID) or "") == "" and isWaiting(spellID)
end

local function isNewRank(rank)
  return (rankNumber(rank) or 0) >= FIRST_NEW_RANK
end

local function rankKey(name, number)
  return name .. ":" .. number
end

-- Class cache and built-in rows over levels 1..toLevel: spell name + rank
-- number to the lowest spellID.
local function rankIndex(sources, toLevel)
  local index = {}
  for _, source in ipairs(sources) do
    for level = 1, toLevel do
      for spellID, entry in pairs(source.levels[level] or {}) do
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
local function addPreviousRanks(entries, sources, toLevel)
  local index
  for _, entry in ipairs(entries) do
    if entry.newRank then
      index = index or rankIndex(sources, toLevel)
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

local function addTrainerEntry(bySpell, spellID, entry, level, fromLevel)
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

-- Highest known rank number per spell name.
local function recordKnownRank(knownRanks, spellID, entry)
  local number = rankNumber(rankOf(spellID, entry))
  local info = number and _G.C_Spell.GetSpellInfo(spellID)
  if info and number > (knownRanks[info.name] or 0) then
    knownRanks[info.name] = number
  end
end

-- Built-in rows have no `covered` and no races: no race rule.
local function addLevel(bySpell, knownRanks, data, race, level, fromLevel, isWaiting)
  for spellID, entry in pairs(data.levels[level] or {}) do
    if isKnown(spellID) then
      recordKnownRank(knownRanks, spellID, entry)
    elseif (data.covered == nil or isVisible(data.covered, race, level, entry)) and not isRankPending(spellID, entry, isWaiting) then
      addTrainerEntry(bySpell, spellID, entry, level, fromLevel)
    end
  end
end

-- Some clients report a lower rank unknown once a higher one is learned.
-- Quest rows count as Rank 1; a trainer entry without a rank number is kept.
local function isSuperseded(entry, knownRanks)
  if entry.group == "weapon" then
    return false
  end
  local number = rankNumber(entry.rank) or (entry.source and 1)
  return number ~= nil and number < (knownRanks[entry.name] or 0)
end

local UNNUMBERED = 0

-- Rank numbers per remaining entry, by name; quest rows count as Rank 1, and
-- trainer entries with empty rank text as UNNUMBERED.
local function listedRanks(entries)
  local listed = {}
  for _, entry in ipairs(entries) do
    local isQuest = entry.source ~= nil and entry.source.kind == "quest"
    local number = rankNumber(entry.rank) or (isQuest and 1) or (entry.source == nil and UNNUMBERED)
    if number then
      listed[entry.name] = listed[entry.name] or {}
      listed[entry.name][number] = true
    end
  end
  return listed
end

-- Whether this client finds known spells by name, tried once on a known cached
-- spell. No known cached spell, an error or nil: it can't tell.
local function findsByName(knownRanks)
  local name = next(knownRanks)
  if name == nil then
    return false
  end
  local ok, known = pcall(_G.C_Spell.GetSpellInfo, name)
  return ok and known ~= nil
end

-- The cache holds every rank a trainer sells, so a missing earlier rank is a
-- starting spell or a talent: any known spell of the name means you have it.
-- A client that can't look spells up by name keeps the rank.
local function isKnownByName(name, reach)
  if reach.findsByName == nil then
    reach.findsByName = findsByName(reach.known)
  end
  if not reach.findsByName then
    return true
  end
  local ok, known = pcall(_G.C_Spell.GetSpellInfo, name)
  return not ok or (known ~= nil and isKnown(known.spellID))
end

-- Rank N can be bought when Rank N - 1 is known, or listed and itself buyable;
-- a listed entry of the name without a rank number vouches for any rank.
-- The spellbook is asked once per name, only when the cache can't tell.
local function isBuyable(name, number, reach)
  if number <= 1 or (reach.known[name] or 0) >= number - 1 or reach.listed[name][UNNUMBERED] then
    return true
  end
  if reach.listed[name][number - 1] then
    return isBuyable(name, number - 1, reach)
  end
  if reach.byName[name] == nil then
    reach.byName[name] = isKnownByName(name, reach)
  end
  return reach.byName[name]
end

-- Drops new ranks whose earlier rank you can't get here (an untaken talent).
local function dropUnbuyable(entries, knownRanks)
  local reach = { known = knownRanks, listed = listedRanks(entries), byName = {} }
  local kept = {}
  for _, entry in ipairs(entries) do
    if not entry.newRank or isBuyable(entry.name, rankNumber(entry.rank), reach) then
      kept[#kept + 1] = entry
    end
  end
  return kept
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

-- Unlearned trainer, built-in, quest and weapon-master skills up to toLevel:
-- new skills and new ranks from (fromLevel, toLevel], then the ones skipped at
-- or below fromLevel, then weapon skills; plus whether to show the hint row
-- (neither the trainer scan nor the built-in table reaches toLevel).
-- Built-in rows skip any spell the trainer cache holds at any level.
-- `isWaiting(spellID)` (optional): true leaves out a trainer entry whose rank
-- text is not loaded yet.
function SkillList.Build(trainers, class, race, faction, fromLevel, toLevel, isWaiting)
  local bySpell = {}
  local knownRanks = {}
  local live = trainers[class] or NO_DATA
  local builtin = { levels = BuiltinSpells.Candidates(class, trainers[class], toLevel) }
  for level = 1, toLevel do
    addLevel(bySpell, knownRanks, live, race, level, fromLevel, isWaiting)
    addLevel(bySpell, knownRanks, builtin, race, level, fromLevel, isWaiting)
  end
  for _, row in ipairs(OtherSources[class] or {}) do
    if rowApplies(row, race, faction, toLevel) then
      addOtherSource(bySpell, row, fromLevel)
    end
  end
  local entries = {}
  for _, entry in pairs(bySpell) do
    if not isSuperseded(entry, knownRanks) then
      entries[#entries + 1] = entry
    end
  end
  entries = dropUnbuyable(entries, knownRanks)
  addPreviousRanks(entries, { live, builtin }, toLevel)
  sort(entries, byGroupThenLevelThenName)
  return entries, TrainerCache.Covered(trainers, class, race) < toLevel and BuiltinSpells.MaxLevel(class) < toLevel
end

-- Summed price of one group's priced entries; nil under two (quest rows have no cost).
function SkillList.GroupTotal(entries, group)
  local total = 0
  local priced = 0
  for _, entry in ipairs(entries) do
    if entry.group == group and entry.cost ~= nil then
      total = total + entry.cost
      priced = priced + 1
    end
  end
  if priced < MIN_PRICED_FOR_TOTAL then
    return nil
  end

  return total
end

ns.SkillList = SkillList
return SkillList
