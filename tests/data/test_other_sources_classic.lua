-- Classic Era and TBC Anniversary rows (spec 2026-11-04 tables).
local Assert = require("tests.helpers.assert")
local Helper = require("tests.helpers.other_sources")

local CLASS_TOKENS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local TBC_MASTERS = { Handiir = true, Ileda = true, ["Duelist Larenis"] = true }

-- Expected Era priest quest rows: race, spellID, level, npc, place, quest.
local ERA_PRIEST_QUESTS = {
  { "Human", 13908, 10, "High Priestess Laurena", "Stormwind", "Desperate Prayer" },
  { "Human", 13896, 20, "High Priestess Laurena", "Stormwind", "Arcane Feedback" },
  { "Dwarf", 13908, 10, "High Priestess Laurena", "Stormwind", "Desperate Prayer" },
  { "Dwarf", 6346, 20, "High Priest Rohan", "Ironforge", "A Lack of Fear" },
  { "NightElf", 10797, 10, "Priestess Alathea", "Darnassus", "Stars of Elune" },
  { "NightElf", 2651, 20, "Priestess Alathea", "Darnassus", "Elune's Grace" },
  { "Scourge", 2652, 10, "Aelthalyste", "Undercity", "Touch of Weakness" },
  { "Scourge", 2944, 20, "Aelthalyste", "Undercity", "Devouring Plague" },
  { "Troll", 9035, 10, "Ur'kyo", "Orgrimmar", "Hex of Weakness" },
  { "Troll", 18137, 20, "Ur'kyo", "Orgrimmar", "Shadowguard" },
}

local function findRow(rows, matches)
  for _, row in ipairs(rows) do
    if matches(row) then
      return row
    end
  end
  return nil
end

local function hasSkill(rows, spellID)
  return findRow(rows, function(row)
    return row.spellID == spellID
  end) ~= nil
end

local function rowFrom(rows, npc, spellID)
  return findRow(rows, function(row)
    return row.npc == npc and (spellID == nil or row.spellID == spellID)
  end)
end

local function questRows(rows)
  local found = {}
  for _, row in ipairs(rows) do
    if row.kind == "quest" then
      found[#found + 1] = row
    end
  end
  return found
end

local function test_era_druid_has_no_polearms()
  Assert.equal(hasSkill(Helper.buildFor("era").DRUID, 200), false)
end

local function test_era_rogue_has_no_one_handed_axes()
  Assert.equal(hasSkill(Helper.buildFor("era").ROGUE, 196), false)
end

local function test_era_priest_quest_rows_match_spec()
  local rows = questRows(Helper.buildFor("era").PRIEST)
  Assert.equal(#rows, #ERA_PRIEST_QUESTS)
  for index, want in ipairs(ERA_PRIEST_QUESTS) do
    local row, label = rows[index], "era quest[" .. index .. "]"
    Assert.equal(row.race, want[1], label .. " race")
    Assert.equal(row.spellID, want[2], label .. " spellID")
    Assert.equal(row.level, want[3], label .. " level")
    Assert.equal(row.npc, want[4], label .. " npc")
    Assert.equal(row.place, want[5], label .. " place")
    Assert.equal(row.quest, want[6], label .. " quest")
  end
end

local function test_era_has_no_tbc_masters()
  for class, rows in pairs(Helper.buildFor("era")) do
    for _, row in ipairs(rows) do
      Assert.equal(TBC_MASTERS[row.npc], nil, class .. " has TBC master " .. row.npc)
    end
  end
end

local function test_tbc_priest_has_no_quest_rows()
  Assert.equal(#questRows(Helper.buildFor("tbc").PRIEST), 0)
end

local function test_tbc_paladin_trains_polearms_at_archibald_level_20()
  local row = rowFrom(Helper.buildFor("tbc").PALADIN, "Archibald", 200)
  Assert.equal(type(row), "table", "no Archibald polearms row")
  Assert.equal(row.faction, "Horde")
  Assert.equal(row.level, 20)
  Assert.equal(row.cost, 10000)
end

local function test_tbc_paladin_has_ileda_and_larenis_rows()
  local rows = Helper.buildFor("tbc").PALADIN
  Assert.equal(rowFrom(rows, "Ileda").place, "Silvermoon City")
  Assert.equal(rowFrom(rows, "Duelist Larenis").place, "Eversong Woods")
end

local function test_tbc_shaman_has_alliance_rows_from_buliwyf_and_handiir()
  local rows = Helper.buildFor("tbc").SHAMAN
  Assert.equal(rowFrom(rows, "Buliwyf Stonehand").faction, "Alliance")
  local handiir = rowFrom(rows, "Handiir")
  Assert.equal(handiir.place, "The Exodar")
  Assert.equal(handiir.faction, "Alliance")
end

local function test_tbc_druid_has_no_polearms()
  Assert.equal(hasSkill(Helper.buildFor("tbc").DRUID, 200), false)
end

local function test_tbc_rogue_has_no_one_handed_axes()
  Assert.equal(hasSkill(Helper.buildFor("tbc").ROGUE, 196), false)
end

local function test_every_client_has_all_nine_class_tokens()
  for _, client in ipairs(Helper.CLIENTS) do
    local built = Helper.buildFor(client)
    for _, class in ipairs(CLASS_TOKENS) do
      Assert.equal(type(built[class]), "table", client .. " lacks " .. class)
    end
  end
end

local function test_tbc_rows_published_at_load_with_real_client()
  _G.C_TooltipInfo = {}
  _G.GetClassicExpansionLevel = function()
    return 1
  end
  local ns = {}
  for _, path in ipairs({ "Core/Client.lua", "Data/WeaponMasters.lua", "Data/QuestSpells.lua", "Data/OtherSources.lua" }) do
    assert(loadfile(path))("LevelUpInfo", ns)
  end
  _G.C_TooltipInfo = nil
  _G.GetClassicExpansionLevel = nil
  Assert.equal(type(rowFrom(ns.OtherSources.PALADIN, "Ileda")), "table")
end

return function()
  test_era_druid_has_no_polearms()
  test_era_rogue_has_no_one_handed_axes()
  test_era_priest_quest_rows_match_spec()
  test_era_has_no_tbc_masters()
  test_tbc_priest_has_no_quest_rows()
  test_tbc_paladin_trains_polearms_at_archibald_level_20()
  test_tbc_paladin_has_ileda_and_larenis_rows()
  test_tbc_shaman_has_alliance_rows_from_buliwyf_and_handiir()
  test_tbc_druid_has_no_polearms()
  test_tbc_rogue_has_no_one_handed_axes()
  test_every_client_has_all_nine_class_tokens()
  test_tbc_rows_published_at_load_with_real_client()
end
