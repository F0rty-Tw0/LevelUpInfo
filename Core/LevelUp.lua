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
-- A record waiting for combat to end; PLAYER_REGEN_ENABLED is registered only while it exists.
local pending

local STAT_COUNT = 5
local MIN_PREVIEW_LEVEL = 2
local MAX_PREVIEW_LEVEL = 60
local STAT_KEYS = { "strength", "agility", "stamina", "intellect", "spirit" }
local SAMPLE_GAINS = { health = 15, power = 20, talents = 0, strength = 0, agility = 0, stamina = 1, intellect = 0, spirit = 0 }

-- Reads the player's current maximums; UnitStat's second return is the effective value.
local function snapshot()
  local before = {
    health = _G.UnitHealthMax("player"),
    power = _G.UnitPowerMax("player", _G.Enum.PowerType.Mana),
  }
  for index = 1, STAT_COUNT do
    before[STAT_KEYS[index]] = select(2, _G.UnitStat("player", index))
  end
  return before
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

local function onRegenEnabled()
  Events.Off("PLAYER_REGEN_ENABLED")
  local record = pending
  pending = nil
  Window.Show(record)
end

local function onLevelUp(level, ...)
  if not db.enabled then
    return
  end
  local shown = Window.Current()
  if shown and not shown.isTest then
    addGains(shown, level, ...)
    Window.Show(shown)
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
    Window.Show(record)
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
  Window.Show(record)
end

ns.LevelUp = LevelUp
return LevelUp
