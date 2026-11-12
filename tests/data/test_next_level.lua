local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local ns
local NextLevel

local KNOWN_RANK_OFFSET = 100000
local FADE = 586
local FLAY_1, FLAY_2, FLAY_3 = 15407, 17311, 17312
local SMITE_2 = 591

local function loadModules(otherSources)
  ns = { OtherSources = otherSources or {} }
  assert(loadfile("Data/TrainerCache.lua"))("LevelUpInfo", ns)
  assert(loadfile("Data/SkillList.lua"))("LevelUpInfo", ns)
  NextLevel = assert(loadfile("Data/NextLevel.lua"))("LevelUpInfo", ns)
end

-- Fresh fake client and modules per test. Renew and Mind Blast each have a
-- known spellbook rank (not in the cache), so their higher ranks can be bought.
local function setup(otherSources)
  W = Wow.Install()
  W.spells[139] = { name = "Renew", iconID = 135953 }
  W.spells[8092] = { name = "Mind Blast", iconID = 136224 }
  for _, spellID in ipairs({ 139, 8092 }) do
    W.spells[spellID + KNOWN_RANK_OFFSET] = { name = W.spells[spellID].name, iconID = W.spells[spellID].iconID }
    W.known[spellID + KNOWN_RANK_OFFSET] = true
  end
  W.spells[588] = { name = "Inner Fire", iconID = 135926 }
  W.spells[FADE] = { name = "Fade", iconID = 135994 }
  W.spells[2652] = { name = "Touch of Weakness", iconID = 136143 }
  W.spells[227] = { name = "Staves", iconID = 135138 }
  loadModules(otherSources)
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

local function ids(entries)
  local list = {}
  for i, entry in ipairs(entries) do
    list[i] = tostring(entry.spellID)
  end
  return table.concat(list, ",")
end

local function find(trainers, toLevel)
  return NextLevel.Find(trainers, "PRIEST", "Scourge", "Horde", toLevel)
end

-- Wraps SkillList.Build with a call counter.
local function countBuilds()
  local counter = { count = 0 }
  local build = ns.SkillList.Build
  ns.SkillList.Build = function(...)
    counter.count = counter.count + 1
    return build(...)
  end
  return counter
end

-- Mind Flay Rank 1 is a talent the priest never took; Smite Rank 2 is the
-- known by-name probe (fixture from test_skill_list_talent_rank.lua).
local function setupFlay()
  W = Wow.Install()
  W.spells[SMITE_2] = { name = "Smite", iconID = 135924 }
  W.known[SMITE_2] = true
  W.spells[FLAY_1] = { name = "Mind Flay", iconID = 136208, subtext = "Rank 1" }
  W.spells[FLAY_2] = { name = "Mind Flay", iconID = 136208 }
  W.spells[FLAY_3] = { name = "Mind Flay", iconID = 136208 }
  W.spells[FADE] = { name = "Fade", iconID = 135994 }
  loadModules()
end

local function flaySpell(rank)
  return { cost = 100, rank = rank, races = { Scourge = true } }
end

local function flayRanks()
  return {
    PRIEST = {
      covered = { Scourge = 40 },
      levels = {
        [6] = { [SMITE_2] = flaySpell("Rank 2") },
        [28] = { [FLAY_2] = flaySpell("Rank 2") },
        [36] = { [FLAY_3] = flaySpell("Rank 3") },
      },
    },
  }
end

-- Success criterion 1 (unit): priest cache 10, 12, 14; toLevel 12.
local function test_next_level_is_the_lowest_cached_level_above_to_level()
  setup()
  local trainers = priest({ Scourge = 14 }, {
    [10] = { [8092] = spell({ Scourge = true }) },
    [12] = { [588] = spell({ Scourge = true }) },
    [14] = { [FADE] = spell({ Scourge = true }) },
  })
  local level, entries = find(trainers, 12)
  Assert.equal(level, 14)
  Assert.equal(ids(entries), "586")
end

local function test_levels_with_no_key_are_skipped_without_a_build()
  setup()
  local builds = countBuilds()
  local trainers = priest({ Scourge = 14 }, { [10] = { [8092] = spell({ Scourge = true }) }, [14] = { [FADE] = spell({ Scourge = true }) } })
  Assert.equal((find(trainers, 10)), 14)
  Assert.equal(builds.count, 1) -- only level 14, never 11-13
end

-- 11: known; 12: another race's racial; 13: buyable.
local function test_level_with_only_hidden_entries_is_skipped()
  setup()
  W.known[8092] = true
  local trainers = priest({ Scourge = 14, Dwarf = 20 }, {
    [11] = { [8092] = spell({ Scourge = true }) },
    [12] = { [2652] = spell({ Dwarf = true }) },
    [13] = { [588] = spell({ Scourge = true }) },
  })
  local level, entries = find(trainers, 10)
  Assert.equal(level, 13)
  Assert.equal(ids(entries), "588")
end

local function test_unbuyable_ranks_do_not_make_a_level()
  setupFlay()
  local trainers = flayRanks()
  Assert.equal(find(trainers, 20), nil)
  trainers.PRIEST.levels[40] = { [FADE] = flaySpell("Rank 1") }
  Assert.equal((find(trainers, 20)), 40)
end

local function test_quest_and_weapon_rows_never_make_a_level()
  setup({ PRIEST = { quest(588, 12), weapon(227, 12, "Horde") } })
  local trainers = priest({ Scourge = 14 }, {
    [10] = { [8092] = spell({ Scourge = true }) },
    [12] = {},
    [14] = { [FADE] = spell({ Scourge = true }) },
  })
  local level, entries = find(trainers, 10)
  Assert.equal(level, 14)
  Assert.equal(ids(entries), "586")
end

local function test_entries_come_back_in_build_order()
  setup()
  local trainers = priest({ Scourge = 14 }, {
    [14] = {
      [588] = spell({ Scourge = true }),
      [FADE] = spell({ Scourge = true }),
      [139] = spell({ Scourge = true }, 100, "Rank 2"),
    },
  })
  local level, entries = find(trainers, 10)
  Assert.equal(level, 14)
  Assert.equal(ids(entries), "586,588,139")
  for _, entry in ipairs(entries) do
    Assert.equal(entry.level, 14)
    Assert.equal(entry.source, nil)
  end
end

local function test_missed_entries_below_the_level_are_not_returned()
  setup()
  local trainers = priest({ Scourge = 14 }, {
    [8] = { [139] = spell({ Scourge = true }) },
    [14] = { [FADE] = spell({ Scourge = true }) },
  })
  local _, entries = find(trainers, 10)
  Assert.equal(ids(entries), "586")
end

local function test_no_class_data_gives_nil()
  setup()
  local level, entries = find({}, 10)
  Assert.equal(level, nil)
  Assert.equal(entries, nil)
end

local function test_nothing_cached_above_gives_nil()
  setup()
  local trainers = priest({ Scourge = 10 }, { [10] = { [8092] = spell({ Scourge = true }) } })
  for _, toLevel in ipairs({ 10, 12 }) do
    local level, entries = find(trainers, toLevel)
    Assert.equal(level, nil)
    Assert.equal(entries, nil)
  end
end

return function()
  test_next_level_is_the_lowest_cached_level_above_to_level()
  test_levels_with_no_key_are_skipped_without_a_build()
  test_level_with_only_hidden_entries_is_skipped()
  test_unbuyable_ranks_do_not_make_a_level()
  test_quest_and_weapon_rows_never_make_a_level()
  test_entries_come_back_in_build_order()
  test_missed_entries_below_the_level_are_not_returned()
  test_no_class_data_gives_nil()
  test_nothing_cached_above_gives_nil()
end
