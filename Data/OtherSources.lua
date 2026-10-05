local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Spells no class trainer sells, keyed by class token; one array of rows per class.
-- Quest row:  { spellID, level, kind = "quest", race?, faction?, npc, place, quest }
-- Weapon row: { spellID, level, kind = "weapon", race?, faction, npc, place, cost }
-- level is the lowest character level that can learn it (1 when none); cost is copper.
-- Several weapon masters for one skill: one row each, preferred master (capital) first.
local OtherSources = {
  WARRIOR = {},
  PALADIN = {},
  HUNTER = {},
  ROGUE = {},
  PRIEST = {},
  SHAMAN = {},
  MAGE = {},
  WARLOCK = {},
  DRUID = {},
}

ns.OtherSources = OtherSources
return OtherSources
