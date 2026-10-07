local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Events = ns.Events or require("LevelUpInfo.Core.Events")
local Window = ns.Window or require("LevelUpInfo.UI.Window")

local pairs = pairs
local select = select

local LevelUp = {}

local db
-- PLAYER_REGEN_ENABLED is registered only while one of these exists:
-- a record waiting for combat to end, or a shown record whose stats were secret.
local pending
local awaitingStats

local STAT_COUNT = 5
local MIN_PREVIEW_LEVEL = 2
local MAX_PREVIEW_LEVEL = 60
local STAT_KEYS = { "strength", "agility", "stamina", "intellect", "spirit" }
local SAMPLE_GAINS = { health = 15, power = 20, talents = 0, strength = 0, agility = 0, stamina = 1, intellect = 0, spirit = 0 }

-- In combat, Forever returns secret numbers that addon code may not do math
-- on; a secret value is dropped, so its gain line shows `+N` only.
local function readable(value)
  local isSecret = _G.issecretvalue
  if isSecret and isSecret(value) then
    return nil
  end
  return value
end

-- Reads the player's current maximums; UnitStat's second return is the effective value.
local function snapshot()
  local before = {
    health = readable(_G.UnitHealthMax("player")),
    power = readable(_G.UnitPowerMax("player", _G.Enum.PowerType.Mana)),
  }
  for index = 1, STAT_COUNT do
    before[STAT_KEYS[index]] = readable(select(2, _G.UnitStat("player", index)))
  end
  return before
end

-- After combat the gains are in the live values: a before value that was
-- secret at the ding becomes live - gain. A live 0 (no mana) drops the gain,
-- as ShowTest does, so its line hides.
local function fillMissingBefore(record)
  local live = snapshot()
  local before, gains = record.before, record.gains
  for key, value in pairs(live) do
    if before[key] == nil then
      if value == 0 then
        gains[key] = 0
      else
        before[key] = value - gains[key]
      end
    end
  end
end

local function hasMissingBefore(record)
  for key, amount in pairs(record.gains) do
    if key ~= "talents" and amount ~= 0 and record.before[key] == nil then
      return true
    end
  end
  return false
end

local function newRecord(fromLevel, toLevel)
  return {
    fromLevel = fromLevel,
    toLevel = toLevel,
    gains = { health = 0, power = 0, talents = 0, strength = 0, agility = 0, stamina = 0, intellect = 0, spirit = 0 },
    before = snapshot(),
  }
end

local function addGains(record, level, health, power, talents, _pvpSlots, strength, agility, stamina, intellect, spirit)
  local gains = record.gains
  record.toLevel = level
  gains.health = gains.health + (health or 0)
  gains.power = gains.power + (power or 0)
  gains.talents = gains.talents + (talents or 0)
  gains.strength = gains.strength + (strength or 0)
  gains.agility = gains.agility + (agility or 0)
  gains.stamina = gains.stamina + (stamina or 0)
  gains.intellect = gains.intellect + (intellect or 0)
  gains.spirit = gains.spirit + (spirit or 0)
end

-- A waiting ding shows now; else a window still showing the record it showed
-- in combat refills in place with the readable values.
local function onRegenEnabled()
  Events.Off("PLAYER_REGEN_ENABLED")
  local record, shown = pending, awaitingStats
  pending, awaitingStats = nil, nil
  if record then
    fillMissingBefore(record)
    Window.Show(record)
  elseif shown and Window.Current() == shown then
    fillMissingBefore(shown)
    Window.Refresh()
  end
end

-- Shows now; in combat, a stat line left at `+N` waits for combat to end.
local function show(record)
  Window.Show(record)
  if _G.InCombatLockdown() and hasMissingBefore(record) then
    awaitingStats = record
    Events.On("PLAYER_REGEN_ENABLED", onRegenEnabled)
  end
end

local function onLevelUp(level, ...)
  if not db.enabled then
    return
  end
  local shown = Window.Current()
  if shown and not shown.isTest then
    addGains(shown, level, ...)
    show(shown)
    return
  end
  if pending then
    addGains(pending, level, ...)
    return
  end
  local record = newRecord(level - 1, level)
  addGains(record, level, ...)
  if db.waitForCombat and _G.InCombatLockdown() then
    pending = record
    Events.On("PLAYER_REGEN_ENABLED", onRegenEnabled)
  else
    show(record)
  end
end

function LevelUp.Install(savedDB)
  db = savedDB
  Events.On("PLAYER_LEVEL_UP", onLevelUp)
end

-- Preview of a ding to `level` (default and out of range: the current level)
-- with sample gains; ignores Enabled and Wait for combat.
-- A gain whose live value is 0 (no mana on a Warrior) stays 0, so its line hides.
function LevelUp.ShowTest(level)
  if not level or level < MIN_PREVIEW_LEVEL or level > MAX_PREVIEW_LEVEL then
    level = _G.UnitLevel("player")
  end
  local record = newRecord(level - 1, level)
  record.isTest = true
  for key, amount in pairs(SAMPLE_GAINS) do
    local live = record.before[key]
    if live ~= 0 then
      record.gains[key] = amount
      if live then
        record.before[key] = live - amount
      end
    end
  end
  show(record)
end

ns.LevelUp = LevelUp
return LevelUp
