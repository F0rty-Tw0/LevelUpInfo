local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Client = ns.Client or require("LevelUpInfo.Core.Client")
local WeaponMasters = ns.WeaponMasters or require("LevelUpInfo.Data.WeaponMasters")
local QuestSpells = ns.QuestSpells or require("LevelUpInfo.Data.QuestSpells")

local ipairs = ipairs
local pairs = pairs

-- Spells no class trainer sells, keyed by class token; one array of rows per class.
-- Quest row:  { spellID, level, kind = "quest", race?, faction?, npc, place, quest }
-- Weapon row: { spellID, level, kind = "weapon", race?, faction, npc, place, cost }
-- level is the lowest character level that can learn it (1 when none); cost is copper.
-- Several weapon masters for one skill: one row each, preferred master first
-- (a race's home-city master, then the capitals).
-- Built once at load for the running client, from Data/QuestSpells.lua and
-- Data/WeaponMasters.lua; every key stays a class token.
local DEFAULT_LEVEL = 1
local DEFAULT_COST = 1000

local function servesClient(master, client)
  return master.clients == nil or master.clients[client] == true
end

local function addWeaponRows(rows, client, skills)
  for _, master in ipairs(WeaponMasters.MASTERS) do
    if servesClient(master, client) then
      for _, skill in ipairs(master.skills) do
        if skills[skill] then
          rows[#rows + 1] = {
            spellID = skill,
            level = WeaponMasters.SKILL_LEVEL[skill] or DEFAULT_LEVEL,
            kind = "weapon",
            race = master.race,
            faction = master.faction,
            npc = master.npc,
            place = master.place,
            cost = WeaponMasters.SKILL_COST[skill] or DEFAULT_COST,
          }
        end
      end
    end
  end
end

local function build(client)
  local questsByClass = QuestSpells[client] or {}
  local sources = {}
  for class, skills in pairs(WeaponMasters.CLASS_SKILLS[client] or {}) do
    local rows = {}
    for _, row in ipairs(questsByClass[class] or {}) do
      rows[#rows + 1] = row
    end
    addWeaponRows(rows, client, skills)
    sources[class] = rows
  end
  return sources
end

local OtherSources = build(Client.Get())

ns.OtherSources = OtherSources
return OtherSources
