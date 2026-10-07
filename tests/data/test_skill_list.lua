local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local SkillList

-- Fresh fake client and module per test; every spell used here has spell info.
local function setup(otherSources)
  W = Wow.Install()
  W.spells[139] = { name = "Renew", iconID = 135953 }
  W.spells[8092] = { name = "Mind Blast", iconID = 136224 }
  W.spells[2944] = { name = "Devouring Plague", iconID = 136188 }
  W.spells[2652] = { name = "Touch of Weakness", iconID = 136143 }
  W.spells[588] = { name = "Inner Fire", iconID = 135926 }
  local ns = { OtherSources = otherSources or {} }
  assert(loadfile("Data/TrainerCache.lua"))("LevelUpInfo", ns)
  SkillList = assert(loadfile("Data/SkillList.lua"))("LevelUpInfo", ns)
end

local function spell(races, cost, rank)
  return { cost = cost or 100, rank = rank or "Rank 1", races = races }
end

local function priest(covered, levels)
  return { PRIEST = { covered = covered, levels = levels } }
end

local function ids(entries)
  local list = {}
  for i, entry in ipairs(entries) do
    list[i] = tostring(entry.spellID)
  end
  return table.concat(list, ",")
end

local function groups(entries)
  local list = {}
  for i, entry in ipairs(entries) do
    list[i] = entry.spellID .. ":" .. entry.group
  end
  return table.concat(list, ",")
end

-- Level 9 Renew is at or below fromLevel, so it lists as Not yet learned after the new skill.
local function test_levels_above_to_level_are_excluded()
  setup()
  local trainers = priest({ Scourge = 12 }, {
    [9] = { [139] = spell({ Scourge = true }) },
    [10] = { [8092] = spell({ Scourge = true }) },
    [11] = { [588] = spell({ Scourge = true }) },
  })
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)), "8092,139")
end

local function test_skipped_trainer_spell_is_not_yet_learned()
  setup()
  local trainers = priest({ Scourge = 12 }, {
    [8] = { [139] = spell({ Scourge = true }, 100, "Rank 1") },
    [10] = {
      [8092] = spell({ Scourge = true }, 100, "Rank 1"),
      [2944] = spell({ Scourge = true }, 100, "Rank 2"),
    },
  })
  Assert.equal(groups(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)), "8092:skill,2944:rank,139:missed")
end

local function test_learned_spells_are_hidden_in_missed_too()
  setup()
  W.known[139] = true
  local trainers = priest({ Scourge = 12 }, { [8] = { [139] = spell({ Scourge = true }) } })
  Assert.equal(groups(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)), "")
end

local function test_missed_sorts_lowest_level_first_then_name()
  setup()
  local trainers = priest({ Scourge = 12 }, {
    [3] = { [588] = spell({ Scourge = true }) },
    [5] = { [139] = spell({ Scourge = true }), [8092] = spell({ Scourge = true }) },
  })
  Assert.equal(groups(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)), "588:missed,8092:missed,139:missed")
end

local function test_known_spells_are_hidden()
  setup()
  W.known[8092] = true
  local trainers = priest({ Scourge = 12 }, { [10] = { [8092] = spell({ Scourge = true }) } })
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)), "")
end

-- Classic Era / TBC: IsPlayerSpell is gone unless a deprecation CVar is on.
local function test_known_spell_is_hidden_when_only_spellbook_api_exists()
  setup()
  rawset(_G, "IsPlayerSpell", nil)
  rawset(_G, "C_SpellBook", {
    IsSpellKnown = function(spellID)
      return spellID == 8092
    end,
  })
  local trainers = priest({ Scourge = 12 }, {
    [10] = { [8092] = spell({ Scourge = true }), [2944] = spell({ Scourge = true }) },
  })
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)), "2944")
end

local function test_own_race_saw_it_shows()
  setup()
  local trainers = priest({ Scourge = 12, Dwarf = 20 }, { [10] = { [2944] = spell({ Scourge = true }) } })
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)), "2944")
end

local function test_other_race_racial_hidden_when_own_race_covered()
  setup()
  local trainers = priest({ Dwarf = 12 }, { [10] = { [2944] = spell({ Scourge = true }) } })
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Dwarf", "Horde", 9, 10)), "")
end

local function test_other_race_racial_hidden_when_another_covering_race_lacks_it()
  setup()
  local trainers = priest({ Scourge = 12, Human = 12 }, { [10] = { [2944] = spell({ Scourge = true }) } })
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Dwarf", "Horde", 9, 10)), "")
end

-- Coverage at the boundary: Human covered exactly level 10, Dwarf only 9.
local function test_racial_hidden_when_covering_race_covered_exactly_its_level()
  setup()
  local trainers = priest({ Dwarf = 9, Human = 10 }, { [10] = { [2944] = spell({ Scourge = true }) } })
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Dwarf", "Horde", 9, 10)), "")
end

local function test_unknown_origin_shows_before_any_coverage()
  setup()
  local trainers = priest({ Scourge = 12 }, { [10] = { [2652] = spell({ Scourge = true }) } })
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Dwarf", "Horde", 9, 10)), "2652")
end

local function test_hint_when_own_coverage_below_to_level()
  setup()
  local _, below = SkillList.Build(priest({ Scourge = 9 }, {}), "PRIEST", "Scourge", "Horde", 9, 10)
  local _, reached = SkillList.Build(priest({ Scourge = 10 }, {}), "PRIEST", "Scourge", "Horde", 9, 10)
  Assert.equal(below, true)
  Assert.equal(reached, false)
end

local function test_entry_carries_spell_info_and_cache_fields()
  setup()
  local trainers = priest({ Scourge = 12 }, { [10] = { [8092] = spell({ Scourge = true }, 300, "Rank 2") } })
  local entry = SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)[1]
  Assert.equal(entry.spellID, 8092)
  Assert.equal(entry.level, 10)
  Assert.equal(entry.name, "Mind Blast")
  Assert.equal(entry.icon, 136224)
  Assert.equal(entry.rank, "Rank 2")
  Assert.equal(entry.cost, 300)
end

local function test_missing_spell_info_skips_entry()
  setup()
  local trainers = priest({ Scourge = 12 }, {
    [10] = { [8092] = spell({ Scourge = true }), [99999] = spell({ Scourge = true }) },
  })
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 10)), "8092")
end

local function test_sorted_by_level_then_name()
  setup()
  local trainers = priest({ Scourge = 12 }, {
    [10] = { [139] = spell({ Scourge = true }), [8092] = spell({ Scourge = true }) },
    [12] = { [588] = spell({ Scourge = true }) },
    [11] = { [2944] = spell({ Scourge = true }) },
  })
  -- Mind Blast < Renew at 10, then Devouring Plague (11), Inner Fire (12).
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 9, 12)), "8092,139,2944,588")
end

local function newRanks(ranks)
  setup()
  local level = {}
  for spellID, rank in pairs(ranks) do
    level[spellID] = spell({ Scourge = true }, 100, rank)
  end
  local result = {}
  for _, entry in ipairs(SkillList.Build(priest({ Scourge = 12 }, { [10] = level }), "PRIEST", "Scourge", "Horde", 9, 10)) do
    result[entry.spellID] = entry.newRank
  end
  return result
end

local function test_rank_two_or_more_is_a_new_rank()
  local result = newRanks({ [8092] = "Rank 2", [139] = "Rank 12" })
  Assert.equal(result[8092], true)
  Assert.equal(result[139], true)
end

local function test_rank_one_empty_or_no_number_is_a_new_skill()
  local result = newRanks({ [8092] = "Rank 1", [139] = "", [588] = "Apprentice" })
  Assert.equal(result[8092], false)
  Assert.equal(result[139], false)
  Assert.equal(result[588], false)
end

local function test_new_skills_sort_before_new_ranks()
  setup()
  local trainers = priest({ Scourge = 12 }, {
    [9] = { [139] = spell({ Scourge = true }, 100, "Rank 2") },
    [10] = { [8092] = spell({ Scourge = true }, 100, "Rank 1") },
  })
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 8, 10)), "8092,139")
end

local function test_missing_class_gives_empty_list_and_hint()
  setup()
  local entries, showHint = SkillList.Build({}, "PRIEST", "Scourge", "Horde", 9, 10)
  Assert.equal(#entries, 0)
  Assert.equal(showHint, true)
end

return function()
  test_levels_above_to_level_are_excluded()
  test_skipped_trainer_spell_is_not_yet_learned()
  test_learned_spells_are_hidden_in_missed_too()
  test_missed_sorts_lowest_level_first_then_name()
  test_known_spells_are_hidden()
  test_known_spell_is_hidden_when_only_spellbook_api_exists()
  test_own_race_saw_it_shows()
  test_other_race_racial_hidden_when_own_race_covered()
  test_other_race_racial_hidden_when_another_covering_race_lacks_it()
  test_racial_hidden_when_covering_race_covered_exactly_its_level()
  test_unknown_origin_shows_before_any_coverage()
  test_hint_when_own_coverage_below_to_level()
  test_entry_carries_spell_info_and_cache_fields()
  test_missing_spell_info_skips_entry()
  test_sorted_by_level_then_name()
  test_missing_class_gives_empty_list_and_hint()
  test_rank_two_or_more_is_a_new_rank()
  test_rank_one_empty_or_no_number_is_a_new_skill()
  test_new_skills_sort_before_new_ranks()
end
