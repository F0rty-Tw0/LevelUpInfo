-- TBC Anniversary: which weapon master the window names, through SkillList.Build.
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Helper = require("tests.helpers.other_sources")

local WEAPON_SKILLS = { 196, 197, 198, 199, 200, 201, 202, 227, 264, 266, 1180, 2567, 5011, 15590 }
local POLEARMS = 200
local ONE_HANDED_MACES = 198
local FROM_LEVEL = 59
local TO_LEVEL = 60

local function loadSkillList()
  local W = Wow.Install()
  for _, id in ipairs(WEAPON_SKILLS) do
    W.spells[id] = { name = "Weapon " .. id, iconID = 1 }
  end
  local rows, ns = Helper.buildFor("tbc")
  ns.OtherSources = rows
  assert(loadfile("Data/TrainerCache.lua"))("LevelUpInfo", ns)
  assert(loadfile("Data/WeaponIcons.lua"))("LevelUpInfo", ns)
  return assert(loadfile("Data/SkillList.lua"))("LevelUpInfo", ns)
end

local function shownMaster(class, race, faction, spellID)
  local entries = loadSkillList().Build({}, class, race, faction, FROM_LEVEL, TO_LEVEL)
  for _, entry in ipairs(entries) do
    if entry.spellID == spellID then
      return entry.source and entry.source.npc
    end
  end
  return nil
end

local function test_blood_elf_paladin_is_sent_to_ileda_for_polearms()
  Assert.equal(shownMaster("PALADIN", "BloodElf", "Horde", POLEARMS), "Ileda")
end

local function test_draenei_shaman_is_sent_to_handiir_for_maces()
  Assert.equal(shownMaster("SHAMAN", "Draenei", "Alliance", ONE_HANDED_MACES), "Handiir")
end

local function test_tauren_warrior_still_sent_to_archibald_for_polearms()
  Assert.equal(shownMaster("WARRIOR", "Tauren", "Horde", POLEARMS), "Archibald")
end

local function test_human_warrior_still_sent_to_woo_ping_for_polearms()
  Assert.equal(shownMaster("WARRIOR", "Human", "Alliance", POLEARMS), "Woo Ping")
end

return function()
  test_blood_elf_paladin_is_sent_to_ileda_for_polearms()
  test_draenei_shaman_is_sent_to_handiir_for_maces()
  test_tauren_warrior_still_sent_to_archibald_for_polearms()
  test_human_warrior_still_sent_to_woo_ping_for_polearms()
end
