local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Events = ns.Events or require("LevelUpInfo.Core.Events")
local RankChanges = ns.RankChanges or require("LevelUpInfo.Data.RankChanges")

local next = next

-- Reads one spell's facts for the rank change lines. A spell whose text is
-- not loaded yet is requested once per window lifetime (until Stop); the
-- load event is registered only while a request is pending.
local SpellFacts = {}

local LOAD_EVENT = "SPELL_DATA_LOAD_RESULT"

local requested = {}
local pending = {}
local onLoaded

local function call(fn, spellID)
  if fn then
    return fn(spellID)
  end
end

local function readDescription(spellID)
  return call(_G.C_Spell.GetSpellDescription, spellID) or ""
end

local function onLoadResult(spellID)
  if not pending[spellID] then
    return
  end
  pending[spellID] = nil
  if next(pending) == nil then
    Events.Off(LOAD_EVENT)
  end
  if onLoaded then
    onLoaded()
  end
end

local function canRequest(spellID)
  local C_Spell = _G.C_Spell
  return not requested[spellID] and C_Spell.GetSpellDescription ~= nil and C_Spell.RequestLoadSpellData ~= nil
end

-- Registers the event before the request, since the result may arrive
-- inside the call. True when the spell still waits for its result.
local function request(spellID)
  requested[spellID] = true
  if next(pending) == nil then
    Events.On(LOAD_EVENT, onLoadResult)
  end
  pending[spellID] = true
  _G.C_Spell.RequestLoadSpellData(spellID)
  return pending[spellID] == true
end

local function buildFacts(spellID, description)
  local C_Spell = _G.C_Spell
  local info = call(C_Spell.GetSpellInfo, spellID)
  local costs = call(C_Spell.GetSpellPowerCost, spellID)
  local firstCost = costs and costs[1]
  local cooldown = call(_G.GetSpellBaseCooldown, spellID)
  return {
    description = description,
    castTime = info and info.castTime,
    cooldown = cooldown,
    cost = firstCost and firstCost.cost,
    powerToken = firstCost and firstCost.name,
  }
end

function SpellFacts.Install(callback)
  onLoaded = callback
end

function SpellFacts.Read(spellID)
  if pending[spellID] then
    return nil
  end
  local description = readDescription(spellID)
  if description == "" and canRequest(spellID) then
    if request(spellID) then
      return nil
    end
    description = readDescription(spellID)
  end
  return buildFacts(spellID, description)
end

-- Reads both spells first, so one wait covers both.
function SpellFacts.Changes(previousSpellID, spellID)
  local oldFacts = SpellFacts.Read(previousSpellID)
  local newFacts = SpellFacts.Read(spellID)
  if not oldFacts or not newFacts then
    return nil
  end
  return RankChanges.Lines(oldFacts, newFacts)
end

function SpellFacts.Stop()
  Events.Off(LOAD_EVENT)
  _G.wipe(requested)
  _G.wipe(pending)
end

ns.SpellFacts = SpellFacts
return SpellFacts
