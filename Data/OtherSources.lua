local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Spells no class trainer sells, keyed by class token; one array of rows per class.
-- Quest row:  { spellID, level, kind = "quest", race?, faction?, npc, place, quest }
-- Weapon row: { spellID, level, kind = "weapon", race?, faction, npc, place, cost }
-- level is the lowest character level that can learn it (1 when none); cost is copper.
-- Several weapon masters for one skill: one row each, preferred master (capital) first.
-- Sources: Wowhead WoW: Forever pages (spell "Reward from" tab, quest and NPC pages).
-- npc/place is where every quest version for the spell is handed in.
-- Weapon rows are left out until a Forever source states the training price.
local OtherSources = {
  WARRIOR = {},
  PALADIN = {},
  HUNTER = {},
  ROGUE = {},
  PRIEST = {
    -- https://www.wowhead.com/forever/spell=1277370/divine-grace
    -- https://www.wowhead.com/forever/quest=94773/divine-grace
    {
      spellID = 1277370,
      level = 10,
      kind = "quest",
      race = "Human",
      npc = "High Priestess Laurena",
      place = "Stormwind",
      quest = "Divine Grace",
    },
    -- https://www.wowhead.com/forever/spell=13896/feedback
    -- https://www.wowhead.com/forever/quest=5676/arcane-feedback
    {
      spellID = 13896,
      level = 20,
      kind = "quest",
      race = "Human",
      npc = "High Priestess Laurena",
      place = "Stormwind",
      quest = "Arcane Feedback",
    },
    -- https://www.wowhead.com/forever/spell=1277331/chastise
    -- https://www.wowhead.com/forever/npc=11406/high-priest-rohan (ends quests 5641, 5645, 5647)
    {
      spellID = 1277331,
      level = 20,
      kind = "quest",
      race = "Dwarf",
      npc = "High Priest Rohan",
      place = "Ironforge",
      quest = "Chastise",
    },
    -- https://www.wowhead.com/forever/spell=10797/starshards
    -- https://www.wowhead.com/forever/quest=5627/stars-of-elune
    {
      spellID = 10797,
      level = 10,
      kind = "quest",
      race = "NightElf",
      npc = "Priestess Alathea",
      place = "Darnassus",
      quest = "Stars of Elune",
    },
    -- https://www.wowhead.com/forever/spell=2651/elunes-grace
    -- https://www.wowhead.com/forever/quest=5673/elunes-grace
    {
      spellID = 2651,
      level = 20,
      kind = "quest",
      race = "NightElf",
      npc = "Priestess Alathea",
      place = "Darnassus",
      quest = "Elune's Grace",
    },
    -- https://www.wowhead.com/forever/spell=1277455/confounding-flash
    -- https://www.wowhead.com/forever/quest=94817/confounding-flash
    {
      spellID = 1277455,
      level = 10,
      kind = "quest",
      race = "Gnome",
      npc = "High Priestess Mims",
      place = "Ironforge",
      quest = "Confounding Flash",
    },
    -- https://www.wowhead.com/forever/spell=1277462/contingency-plan
    -- https://www.wowhead.com/forever/quest=94819/contingency-plan
    {
      spellID = 1277462,
      level = 20,
      kind = "quest",
      race = "Gnome",
      npc = "High Priestess Mims",
      place = "Ironforge",
      quest = "Contingency Plan",
    },
    -- https://www.wowhead.com/forever/spell=2652/touch-of-weakness
    -- https://www.wowhead.com/forever/quest=5661/touch-of-weakness
    {
      spellID = 2652,
      level = 10,
      kind = "quest",
      race = "Scourge",
      npc = "Aelthalyste",
      place = "Undercity",
      quest = "Touch of Weakness",
    },
    -- https://www.wowhead.com/forever/spell=1277324/dark-sacrifice
    -- https://www.wowhead.com/forever/quest=5679/dark-sacrifice
    {
      spellID = 1277324,
      level = 20,
      kind = "quest",
      race = "Scourge",
      npc = "Aelthalyste",
      place = "Undercity",
      quest = "Dark Sacrifice",
    },
    -- https://www.wowhead.com/forever/spell=9035/hex-of-weakness
    -- https://www.wowhead.com/forever/quest=5652/hex-of-weakness
    {
      spellID = 9035,
      level = 10,
      kind = "quest",
      race = "Troll",
      npc = "Ur'kyo",
      place = "Orgrimmar",
      quest = "Hex of Weakness",
    },
    -- https://www.wowhead.com/forever/spell=18137/shadowguard
    -- https://www.wowhead.com/forever/quest=5680/shadowguard
    {
      spellID = 18137,
      level = 20,
      kind = "quest",
      race = "Troll",
      npc = "Ur'kyo",
      place = "Orgrimmar",
      quest = "Shadowguard",
    },
  },
  SHAMAN = {},
  MAGE = {},
  WARLOCK = {},
  DRUID = {},
}

ns.OtherSources = OtherSources
return OtherSources
