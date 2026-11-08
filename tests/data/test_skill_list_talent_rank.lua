-- A rank you cannot buy yet stays hidden: Mind Flay Rank 1 is a talent, so
-- the trainer lists Rank 2 and up to priests who never took it.
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local SkillList

local FLAY_1, FLAY_2, FLAY_3 = 15407, 17311, 17312
local WEAKNESS_1, WEAKNESS_2 = 2652, 19261
local SMITE_2 = 591
local EMBRACE_2 = 99002

local function setup(otherSources)
  W = Wow.Install()
  W.spells[SMITE_2] = { name = "Smite", iconID = 135924 }
  W.known[SMITE_2] = true
  W.spells[FLAY_1] = { name = "Mind Flay", iconID = 136208, subtext = "Rank 1" }
  W.spells[FLAY_2] = { name = "Mind Flay", iconID = 136208 }
  W.spells[FLAY_3] = { name = "Mind Flay", iconID = 136208 }
  W.spells[WEAKNESS_1] = { name = "Touch of Weakness", iconID = 136143 }
  W.spells[WEAKNESS_2] = { name = "Touch of Weakness", iconID = 136143 }
  local ns = { OtherSources = otherSources or {} }
  assert(loadfile("Data/TrainerCache.lua"))("LevelUpInfo", ns)
  SkillList = assert(loadfile("Data/SkillList.lua"))("LevelUpInfo", ns)
end

local function spell(rank)
  return { cost = 100, rank = rank, races = { Scourge = true } }
end

-- Smite Rank 2 is cached and known: the probe proving lookups by name work.
local function flayRanks()
  return {
    PRIEST = {
      covered = { Scourge = 40 },
      levels = {
        [6] = { [SMITE_2] = spell("Rank 2") },
        [28] = { [FLAY_2] = spell("Rank 2") },
        [36] = { [FLAY_3] = spell("Rank 3") },
      },
    },
  }
end

-- Replaces the by-name lookup; by-ID lookups stay. Counts calls per name.
local function stubByName(lookup)
  local byID = _G.C_Spell.GetSpellInfo
  local asked = {}
  _G.C_Spell.GetSpellInfo = function(arg)
    if type(arg) == "string" then
      asked[arg] = (asked[arg] or 0) + 1
      return lookup(arg, byID)
    end
    return byID(arg)
  end
  return asked
end

local function ids(entries)
  local list = {}
  for i, entry in ipairs(entries) do
    list[i] = entry.spellID .. ":" .. entry.group
  end
  return table.concat(list, ",")
end

local function build(trainers, fromLevel, toLevel)
  return ids(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", fromLevel, toLevel))
end

local function test_ranks_of_an_untaken_talent_are_hidden()
  setup()
  Assert.equal(ids(SkillList.Build(flayRanks(), "PRIEST", "Scourge", "Horde", 35, 36)), "")
end

local function test_ranks_list_once_the_talent_rank_is_known()
  setup()
  W.known[FLAY_1] = true
  Assert.equal(ids(SkillList.Build(flayRanks(), "PRIEST", "Scourge", "Horde", 35, 36)), "17312:rank,17311:missed")
end

-- A by-name result you don't know (the talent spell itself) is not a known rank.
local function test_unknown_spell_by_name_hides_the_rank()
  setup()
  stubByName(function(name, byID)
    return name == "Mind Flay" and byID(FLAY_1) or byID(SMITE_2)
  end)
  Assert.equal(build(flayRanks(), 27, 28), "")
end

-- A client whose lookup by name finds nothing, not even a known spell, can't tell.
local function test_lookup_that_never_finds_a_known_spell_keeps_the_rank()
  setup()
  stubByName(function()
    return nil
  end)
  Assert.equal(build(flayRanks(), 27, 28), "17311:rank")
end

-- No known cached spell to prove the lookup works: the rank is kept.
local function test_no_known_cached_spell_keeps_the_rank()
  setup()
  W.known[SMITE_2] = nil
  Assert.equal(build(flayRanks(), 27, 28), "17311:rank,591:missed")
end

-- A known cached Rank 2 vouches for Rank 3 without asking the spellbook.
local function test_known_cached_rank_keeps_the_next_rank()
  setup()
  W.known[FLAY_2] = true
  stubByName(function(name, byID)
    return name == "Mind Flay" and byID(FLAY_1) or byID(SMITE_2)
  end)
  Assert.equal(build(flayRanks(), 35, 36), "17312:rank")
end

-- Every rank is dropped, so no previous-rank lookup adds a call; two talent
-- names reach the spellbook, and the client probe still runs once.
local function test_spellbook_is_asked_once_per_name()
  setup()
  W.spells[EMBRACE_2] = { name = "Vampiric Embrace", iconID = 136230 }
  local trainers = flayRanks()
  trainers.PRIEST.levels[30] = { [EMBRACE_2] = spell("Rank 2") }
  local asked = stubByName(function(name, byID)
    return name == "Smite" and byID(SMITE_2) or nil
  end)
  Assert.equal(build(trainers, 35, 36), "")
  Assert.equal(asked["Mind Flay"], 1)
  Assert.equal(asked["Smite"], 1)
end

-- Rank text can be empty; a listed entry of the name without a number vouches.
local function test_listed_entry_without_rank_number_keeps_the_next_rank()
  setup()
  W.spells[FLAY_1].subtext = nil
  local trainers = flayRanks()
  trainers.PRIEST.levels[20] = { [FLAY_1] = spell("") }
  Assert.equal(build(trainers, 27, 28), "17311:rank,15407:missed")
end

-- A client that rejects the by-name call can't tell; the rank is kept.
local function test_by_name_lookup_error_keeps_the_rank()
  setup()
  local byID = _G.C_Spell.GetSpellInfo
  _G.C_Spell.GetSpellInfo = function(arg)
    if type(arg) == "string" then
      error("bad argument")
    end
    return byID(arg)
  end
  Assert.equal(ids(SkillList.Build(flayRanks(), "PRIEST", "Scourge", "Horde", 27, 28)), "17311:rank")
end

local function test_quest_rank_one_keeps_trainer_rank_two()
  setup({
    PRIEST = {
      { spellID = WEAKNESS_1, level = 10, kind = "quest", race = "Scourge", npc = "Quest Giver", place = "Undercity", quest = "A Quest" },
    },
  })
  local trainers = { PRIEST = { covered = { Scourge = 20 }, levels = { [20] = { [WEAKNESS_2] = spell("Rank 2") } } } }
  Assert.equal(ids(SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", 19, 20)), "19261:rank,2652:missed")
end

return function()
  test_ranks_of_an_untaken_talent_are_hidden()
  test_ranks_list_once_the_talent_rank_is_known()
  test_unknown_spell_by_name_hides_the_rank()
  test_lookup_that_never_finds_a_known_spell_keeps_the_rank()
  test_no_known_cached_spell_keeps_the_rank()
  test_known_cached_rank_keeps_the_next_rank()
  test_spellbook_is_asked_once_per_name()
  test_listed_entry_without_rank_number_keeps_the_next_rank()
  test_by_name_lookup_error_keeps_the_rank()
  test_quest_rank_one_keeps_trainer_rank_two()
end
