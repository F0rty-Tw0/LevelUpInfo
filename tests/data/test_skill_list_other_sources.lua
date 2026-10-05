local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local SkillList

-- Fresh fake client and module per test, with the given other-sources table.
local function setup(otherSources)
  W = Wow.Install()
  W.spells[139] = { name = "Renew", iconID = 135953 }
  W.spells[8092] = { name = "Mind Blast", iconID = 136224 }
  W.spells[2944] = { name = "Devouring Plague", iconID = 136188 }
  W.spells[2652] = { name = "Touch of Weakness", iconID = 136143 }
  W.spells[227] = { name = "Staves", iconID = 135138 }
  W.spells[1180] = { name = "Daggers", iconID = 135641 }
  W.spells[198] = { name = "Maces", iconID = 133476 }
  local ns = { OtherSources = otherSources }
  assert(loadfile("Data/TrainerCache.lua"))("LevelUpInfo", ns)
  SkillList = assert(loadfile("Data/SkillList.lua"))("LevelUpInfo", ns)
end

local function spell(races, cost, rank)
  return { cost = cost or 100, rank = rank or "Rank 1", races = races }
end

local function priest(covered, levels)
  return { PRIEST = { covered = covered, levels = levels } }
end

local function quest(spellID, level, race)
  return { spellID = spellID, level = level, kind = "quest", race = race, npc = "Quest Giver", place = "Undercity", quest = "A Quest" }
end

local function weapon(spellID, level, faction, npc)
  return { spellID = spellID, level = level, kind = "weapon", faction = faction, npc = npc or "Master", place = "Orgrimmar", cost = 1000 }
end

local function groups(entries)
  local list = {}
  for i, entry in ipairs(entries) do
    list[i] = entry.spellID .. ":" .. entry.group
  end
  return table.concat(list, ",")
end

local function test_quest_racial_shows_for_its_race_only()
  setup({ PRIEST = { quest(2652, 10, "Scourge") } })
  local entries = SkillList.Build({}, "PRIEST", "Scourge", "Horde", 9, 10)
  Assert.equal(groups(entries), "2652:skill")
  Assert.equal(entries[1].source.npc, "Quest Giver")
  Assert.equal(entries[1].rank, "")
  Assert.equal(entries[1].newRank, false)
  Assert.equal(entries[1].cost, nil)
  Assert.equal(groups(SkillList.Build({}, "PRIEST", "Dwarf", "Alliance", 9, 10)), "")
end

local function test_quest_row_at_or_below_from_level_is_not_yet_learned()
  setup({ PRIEST = { quest(2652, 10) } })
  Assert.equal(groups(SkillList.Build({}, "PRIEST", "Scourge", "Horde", 12, 13)), "2652:missed")
end

local function test_quest_row_above_to_level_is_hidden()
  setup({ PRIEST = { quest(2652, 10) } })
  Assert.equal(groups(SkillList.Build({}, "PRIEST", "Scourge", "Horde", 8, 9)), "")
end

local function test_weapon_row_shows_for_its_faction_only_once_per_spell()
  setup({ PRIEST = { weapon(227, 1, "Horde", "A"), weapon(227, 1, "Horde", "B"), weapon(1180, 1, "Alliance", "C") } })
  local horde = SkillList.Build({}, "PRIEST", "Scourge", "Horde", 9, 10)
  Assert.equal(groups(horde), "227:weapon")
  Assert.equal(horde[1].source.npc, "A")
  Assert.equal(groups(SkillList.Build({}, "PRIEST", "Dwarf", "Alliance", 9, 10)), "1180:weapon")
end

-- Level order would be Staves (1), Maces (5), Daggers (10); weapons sort by name instead.
local function test_weapon_rows_sort_by_name()
  setup({ PRIEST = { weapon(227, 1), weapon(198, 5), weapon(1180, 10) } })
  Assert.equal(groups(SkillList.Build({}, "PRIEST", "Scourge", "Horde", 9, 10)), "1180:weapon,198:weapon,227:weapon")
end

local function test_trainer_entry_wins_over_quest_row()
  setup({ PRIEST = { quest(2652, 10) } })
  local trainers = priest({ Scourge = 12 }, { [10] = { [2652] = spell({ Scourge = true }, 300) } })
  local entries = SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)
  Assert.equal(#entries, 1)
  Assert.equal(entries[1].cost, 300)
  Assert.equal(entries[1].source, nil)
end

local function test_weapon_row_wins_over_trainer_entry()
  setup({ PRIEST = { weapon(227, 1, "Horde") } })
  local trainers = priest({ Scourge = 12 }, { [10] = { [227] = spell({ Scourge = true }, 300) } })
  local entries = SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)
  Assert.equal(groups(entries), "227:weapon")
  Assert.equal(entries[1].source.kind, "weapon")
  Assert.equal(entries[1].cost, 1000)
end

local function test_known_other_source_spells_are_hidden()
  setup({ PRIEST = { quest(2652, 10), weapon(227, 1) } })
  W.known[2652] = true
  W.known[227] = true
  Assert.equal(groups(SkillList.Build({}, "PRIEST", "Scourge", "Horde", 9, 10)), "")
end

local function test_nil_faction_skips_faction_rows_only()
  setup({ PRIEST = { quest(2652, 10, "Scourge"), weapon(227, 1, "Horde") } })
  Assert.equal(groups(SkillList.Build({}, "PRIEST", "Scourge", nil, 9, 10)), "2652:skill")
end

local function test_full_group_order()
  setup({ PRIEST = { weapon(227, 1) } })
  local trainers = priest({ Scourge = 12 }, {
    [8] = { [139] = spell({ Scourge = true }) },
    [10] = { [8092] = spell({ Scourge = true }, 100, "Rank 1"), [2944] = spell({ Scourge = true }, 100, "Rank 2") },
  })
  local list = {}
  for i, entry in ipairs(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)) do
    list[i] = entry.group
  end
  Assert.equal(table.concat(list, ","), "skill,rank,missed,weapon")
end

local function test_other_sources_show_without_trainer_cache()
  setup({ PRIEST = { quest(2652, 10, "Scourge"), weapon(227, 1, "Horde") } })
  local entries, showHint = SkillList.Build({}, "PRIEST", "Scourge", "Horde", 9, 10)
  Assert.equal(#entries, 2)
  Assert.equal(showHint, true)
end

return function()
  test_quest_racial_shows_for_its_race_only()
  test_quest_row_at_or_below_from_level_is_not_yet_learned()
  test_quest_row_above_to_level_is_hidden()
  test_weapon_row_shows_for_its_faction_only_once_per_spell()
  test_weapon_rows_sort_by_name()
  test_trainer_entry_wins_over_quest_row()
  test_weapon_row_wins_over_trainer_entry()
  test_known_other_source_spells_are_hidden()
  test_nil_faction_skips_faction_rows_only()
  test_full_group_order()
  test_other_sources_show_without_trainer_cache()
end
