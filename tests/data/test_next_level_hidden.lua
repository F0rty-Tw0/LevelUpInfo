-- NextLevel.Find with hidden skill names: hidden entries never count.
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local NextLevel

local KNOWN_RANK_OFFSET = 100000
local FADE = 586

-- Fresh fake client and modules per test. Renew and Mind Blast each have a
-- known spellbook rank (not in the cache), so their higher ranks can be bought.
local function setup()
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
  local ns = { OtherSources = {} }
  assert(loadfile("Data/TrainerCache.lua"))("LevelUpInfo", ns)
  assert(loadfile("Data/SkillList.lua"))("LevelUpInfo", ns)
  NextLevel = assert(loadfile("Data/NextLevel.lua"))("LevelUpInfo", ns)
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

local function findHidden(trainers, toLevel, hidden)
  return NextLevel.Find(trainers, "PRIEST", "Scourge", "Horde", toLevel, hidden)
end

-- Level 11 holds only Mind Blast.
local function test_a_level_whose_only_skill_is_hidden_is_skipped()
  setup()
  local trainers = priest({ Scourge = 14 }, {
    [11] = { [8092] = spell({ Scourge = true }) },
    [13] = { [588] = spell({ Scourge = true }) },
  })
  Assert.equal((findHidden(trainers, 10, nil)), 11)
  local level, entries = findHidden(trainers, 10, { ["Mind Blast"] = true })
  Assert.equal(level, 13)
  Assert.equal(ids(entries), "588")
end

local function test_only_the_hidden_entries_of_a_level_are_dropped_in_build_order()
  setup()
  local trainers = priest({ Scourge = 14 }, {
    [14] = { [588] = spell({ Scourge = true }), [FADE] = spell({ Scourge = true }), [2652] = spell({ Scourge = true }) },
  })
  local _, all = findHidden(trainers, 10, {})
  Assert.equal(ids(all), "586,588,2652")
  local level, entries = findHidden(trainers, 10, { ["Inner Fire"] = true })
  Assert.equal(level, 14)
  Assert.equal(ids(entries), "586,2652")
end

-- The key is the name, so a rank 2 of a hidden skill is dropped too.
local function test_a_hidden_name_drops_every_rank_of_that_skill()
  setup()
  local trainers = priest({ Scourge = 14 }, {
    [12] = { [139] = spell({ Scourge = true }, 100, "Rank 2") },
    [14] = { [FADE] = spell({ Scourge = true }) },
  })
  Assert.equal((findHidden(trainers, 10, nil)), 12)
  local level, entries = findHidden(trainers, 10, { Renew = true })
  Assert.equal(level, 14)
  Assert.equal(ids(entries), "586")
end

local function test_everything_above_hidden_gives_nil()
  setup()
  local trainers = priest({ Scourge = 14 }, {
    [11] = { [8092] = spell({ Scourge = true }) },
    [14] = { [FADE] = spell({ Scourge = true }) },
  })
  local level, entries = findHidden(trainers, 10, { ["Mind Blast"] = true, Fade = true })
  Assert.equal(level, nil)
  Assert.equal(entries, nil)
end

local function test_a_hidden_name_that_matches_nothing_changes_nothing()
  setup()
  local trainers = priest({ Scourge = 14 }, { [11] = { [8092] = spell({ Scourge = true }) } })
  local level, entries = findHidden(trainers, 10, { Smite = true, ["Mind Blast"] = false })
  Assert.equal(level, 11)
  Assert.equal(ids(entries), "8092")
end

return function()
  test_a_level_whose_only_skill_is_hidden_is_skipped()
  test_only_the_hidden_entries_of_a_level_are_dropped_in_build_order()
  test_a_hidden_name_drops_every_rank_of_that_skill()
  test_everything_above_hidden_gives_nil()
  test_a_hidden_name_that_matches_nothing_changes_nothing()
end
