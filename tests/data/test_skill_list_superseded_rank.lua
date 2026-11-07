-- A rank is superseded once a higher rank of the same spell is known, even
-- when the client reports the lower rank itself as unknown.
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local SkillList

local REND_1, REND_2, REND_3 = 772, 6546, 6547
local HEROIC_STRIKE_2 = 284
local WEAKNESS_1, WEAKNESS_2 = 2652, 19261

local function setup(otherSources)
  W = Wow.Install()
  W.spells[REND_1] = { name = "Rend", iconID = 132155 }
  W.spells[REND_2] = { name = "Rend", iconID = 132155 }
  W.spells[REND_3] = { name = "Rend", iconID = 132155 }
  W.spells[HEROIC_STRIKE_2] = { name = "Heroic Strike", iconID = 132282 }
  W.spells[WEAKNESS_1] = { name = "Touch of Weakness", iconID = 136143 }
  W.spells[WEAKNESS_2] = { name = "Touch of Weakness", iconID = 136143 }
  local ns = { OtherSources = otherSources or {} }
  assert(loadfile("Data/TrainerCache.lua"))("LevelUpInfo", ns)
  SkillList = assert(loadfile("Data/SkillList.lua"))("LevelUpInfo", ns)
end

local function spell(rank)
  return { cost = 100, rank = rank, races = { Orc = true } }
end

local function warrior(levels)
  return { WARRIOR = { covered = { Orc = 20 }, levels = levels } }
end

local function ids(entries)
  local list = {}
  for i, entry in ipairs(entries) do
    list[i] = entry.spellID .. ":" .. entry.group
  end
  return table.concat(list, ",")
end

local function rendRanks()
  return warrior({
    [4] = { [REND_1] = spell("Rank 1") },
    [10] = { [REND_2] = spell("Rank 2"), [HEROIC_STRIKE_2] = spell("Rank 2") },
    [20] = { [REND_3] = spell("Rank 3") },
  })
end

local function test_rank_one_is_hidden_once_rank_two_is_known()
  setup()
  W.known[REND_2] = true
  W.known[HEROIC_STRIKE_2] = true
  Assert.equal(ids(SkillList.Build(rendRanks(), "WARRIOR", "Orc", "Horde", 10, 11)), "")
end

local function test_rank_above_the_known_rank_still_lists()
  setup()
  W.known[REND_2] = true
  W.known[HEROIC_STRIKE_2] = true
  Assert.equal(ids(SkillList.Build(rendRanks(), "WARRIOR", "Orc", "Horde", 19, 20)), "6547:rank")
end

local function test_a_known_rank_of_another_spell_hides_nothing()
  setup()
  W.known[HEROIC_STRIKE_2] = true
  Assert.equal(ids(SkillList.Build(rendRanks(), "WARRIOR", "Orc", "Horde", 10, 11)), "772:missed,6546:missed")
end

local function test_quest_rank_one_is_hidden_once_trainer_rank_two_is_known()
  setup({
    { spellID = WEAKNESS_1, level = 10, kind = "quest", race = "Scourge", npc = "Quest Giver", place = "Undercity", quest = "A Quest" },
  })
  W.known[WEAKNESS_2] = true
  local rank2 = { cost = 100, rank = "Rank 2", races = { Scourge = true } }
  local trainers = { PRIEST = { covered = { Scourge = 20 }, levels = { [20] = { [WEAKNESS_2] = rank2 } } } }
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 20, 21)), "")
end

return function()
  test_rank_one_is_hidden_once_rank_two_is_known()
  test_rank_above_the_known_rank_still_lists()
  test_a_known_rank_of_another_spell_hides_nothing()
  test_quest_rank_one_is_hidden_once_trainer_rank_two_is_known()
end
