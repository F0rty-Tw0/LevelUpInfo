local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Weapon masters and which class may train which weapon skill, per client.
-- Data/OtherSources.lua turns these into weapon rows.
-- Sources: Wowhead WoW: Forever, TBC Classic and Classic NPC pages ("Teaches" tab),
-- warcraft.wiki.gg/wiki/Weapon_master. Price: same as Classic per user (2026-10-06);
-- https://blizzardwatch.com/2024/11/27/weapon-trainers-wow-classic-forever/
local WeaponMasters = {}

-- Preference order: when several masters teach a skill, the window shows the
-- first one of your faction, so capitals come first. `clients` nil = all clients.
-- `race` set = only that race is sent here; those masters come first so a
-- Blood Elf or Draenei is sent to their home city, everyone else to the capitals.
WeaponMasters.MASTERS = {
  -- https://www.wowhead.com/tbc/npc=16773/handiir
  {
    npc = "Handiir",
    place = "The Exodar",
    race = "Draenei",
    faction = "Alliance",
    skills = { 198, 199, 201, 202, 1180, 5011 },
    clients = { tbc = true },
  },
  -- https://www.wowhead.com/tbc/npc=16621/ileda
  {
    npc = "Ileda",
    place = "Silvermoon City",
    race = "BloodElf",
    faction = "Horde",
    skills = { 200, 201, 202, 264, 1180, 2567 },
    clients = { tbc = true },
  },
  -- https://www.wowhead.com/tbc/npc=17005 (Falconwing Square)
  {
    npc = "Duelist Larenis",
    place = "Eversong Woods",
    race = "BloodElf",
    faction = "Horde",
    skills = { 200, 201, 202, 264, 1180, 2567 },
    clients = { tbc = true },
  },
  -- https://www.wowhead.com/forever/npc=11867/woo-ping
  { npc = "Woo Ping", place = "Stormwind", faction = "Alliance", skills = { 200, 201, 202, 227, 1180, 5011 } },
  -- https://www.wowhead.com/forever/npc=13084/bixi-wobblebonk
  { npc = "Bixi Wobblebonk", place = "Ironforge", faction = "Alliance", skills = { 1180, 2567, 5011 } },
  -- https://www.wowhead.com/forever/npc=11865/buliwyf-stonehand
  {
    npc = "Buliwyf Stonehand",
    place = "Ironforge",
    faction = "Alliance",
    skills = { 196, 197, 198, 199, 266, 15590 },
  },
  -- https://www.wowhead.com/forever/npc=11866/ilyenia-moonfire
  { npc = "Ilyenia Moonfire", place = "Darnassus", faction = "Alliance", skills = { 227, 264, 1180, 2567, 15590 } },
  -- https://www.wowhead.com/forever/npc=2704/hanashi
  { npc = "Hanashi", place = "Orgrimmar", faction = "Horde", skills = { 264, 196, 227, 2567, 197 } },
  -- https://www.wowhead.com/forever/npc=11868/sayoc
  { npc = "Sayoc", place = "Orgrimmar", faction = "Horde", skills = { 196, 197, 264, 1180, 2567, 15590 } },
  -- https://www.wowhead.com/forever/npc=11869/ansekhwa
  { npc = "Ansekhwa", place = "Thunder Bluff", faction = "Horde", skills = { 198, 199, 227, 266 } },
  -- https://www.wowhead.com/forever/npc=11870/archibald
  { npc = "Archibald", place = "Undercity", faction = "Horde", skills = { 200, 201, 202, 1180, 5011 } },
}

-- Classes per weapon skill on Classic Era and TBC (Wowhead TBC spell pages, "reqclass").
local CLASSIC_SKILL_CLASSES = {
  [196] = { "WARRIOR", "PALADIN", "HUNTER", "SHAMAN" }, -- One-Handed Axes
  [197] = { "WARRIOR", "PALADIN", "HUNTER", "SHAMAN" }, -- Two-Handed Axes
  [198] = { "WARRIOR", "PALADIN", "ROGUE", "PRIEST", "SHAMAN", "DRUID" }, -- One-Handed Maces
  [199] = { "WARRIOR", "PALADIN", "SHAMAN", "DRUID" }, -- Two-Handed Maces
  [200] = { "WARRIOR", "PALADIN", "HUNTER" }, -- Polearms
  [201] = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "MAGE", "WARLOCK" }, -- One-Handed Swords
  [202] = { "WARRIOR", "PALADIN", "HUNTER" }, -- Two-Handed Swords
  [227] = { "WARRIOR", "HUNTER", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }, -- Staves
  [264] = { "WARRIOR", "HUNTER", "ROGUE" }, -- Bows
  [266] = { "WARRIOR", "HUNTER", "ROGUE" }, -- Guns
  [1180] = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }, -- Daggers
  [2567] = { "WARRIOR", "HUNTER", "ROGUE" }, -- Thrown
  [5011] = { "WARRIOR", "HUNTER", "ROGUE" }, -- Crossbows
  [15590] = { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "DRUID" }, -- Fist Weapons
}

-- Forever also lets druids train Polearms and rogues One-Handed Axes
-- (https://www.warcrafttavern.com/forever/guides/weapon-trainers/).
local FOREVER_EXTRA_SKILLS = { DRUID = { 200 }, ROGUE = { 196 } }

local CLASS_TOKENS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- class token -> { [skill spellID] = true }, one set per class token.
local function classSkills(extraSkills)
  local byClass = {}
  for _, class in ipairs(CLASS_TOKENS) do
    byClass[class] = {}
  end
  for skill, classes in pairs(CLASSIC_SKILL_CLASSES) do
    for _, class in ipairs(classes) do
      byClass[class][skill] = true
    end
  end
  for class, skills in pairs(extraSkills) do
    for _, skill in ipairs(skills) do
      byClass[class][skill] = true
    end
  end
  return byClass
end

-- Era: no druid Polearms (Wowhead classic data still lists druids; unconfirmed in game).
WeaponMasters.CLASS_SKILLS = {
  forever = classSkills(FOREVER_EXTRA_SKILLS),
  era = classSkills({}),
  tbc = classSkills({}),
}

-- Every skill is level 1 for 10 silver, except Polearms: level 20 for 1 gold
-- (warcraft.wiki.gg/wiki/Weapon_master; warcrafttavern Forever guide).
WeaponMasters.SKILL_LEVEL = { [200] = 20 }
WeaponMasters.SKILL_COST = { [200] = 10000 }

ns.WeaponMasters = WeaponMasters
return WeaponMasters
