local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Client = ns.Client or require("LevelUpInfo.Core.Client")

local pairs = pairs

-- Class trainer tables shipped with the addon, keyed by class token:
-- [level] = { [spellID] = { cost = copper, rank = "Rank N" | "" } }, no races.
-- Built once at load from the running client's Data/ClassSpells function;
-- the other clients' functions are never called. Read-only for callers.
local BuiltinSpells = {}

local NO_LEVEL = 0
local EMPTY = {}

local register = ns.ClassSpellData and ns.ClassSpellData[Client.Get()]
if type(register) == "function" then
  for class, levels in pairs(register()) do
    BuiltinSpells[class] = levels
  end
end

-- Highest level key of the class's table; 0 when the class has none.
function BuiltinSpells.MaxLevel(class)
  local highest = NO_LEVEL
  for level in pairs(BuiltinSpells[class] or EMPTY) do
    if level > highest then
      highest = level
    end
  end
  return highest
end

local function liveSpellIDs(live)
  local held = {}
  for _, spells in pairs(live.levels) do
    for spellID in pairs(spells) do
      held[spellID] = true
    end
  end
  return held
end

-- Built-in levels 1..toLevel without the spells the live class cache holds
-- at any level (live wins). nil `live`: the class's whole table as is.
function BuiltinSpells.Candidates(class, live, toLevel)
  local levels = BuiltinSpells[class] or EMPTY
  if live == nil then
    return levels
  end
  local held = liveSpellIDs(live)
  local candidates = {}
  for level, spells in pairs(levels) do
    if level <= toLevel then
      local kept = {}
      for spellID, entry in pairs(spells) do
        if not held[spellID] then
          kept[spellID] = entry
        end
      end
      candidates[level] = kept
    end
  end
  return candidates
end

ns.BuiltinSpells = BuiltinSpells
return BuiltinSpells
