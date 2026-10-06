local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local SkillList

local RANK_1 = 2050
local RANK_2 = 2052
local RANK_3 = 2053
local OTHER_RANK_1 = 9999
local APPRENTICE = 7777
local NO_INFO = 5555
local QUEST_SPELL = 2652
local STAVES = 227

-- Fresh fake client and module per test; Lesser Heal ranks have spell info.
local function setup(otherSources)
  W = Wow.Install()
  W.spells[RANK_1] = { name = "Lesser Heal", iconID = 135929 }
  W.spells[RANK_2] = { name = "Lesser Heal", iconID = 135929 }
  W.spells[RANK_3] = { name = "Lesser Heal", iconID = 135929 }
  W.spells[OTHER_RANK_1] = { name = "Lesser Heal", iconID = 135929 }
  W.spells[APPRENTICE] = { name = "Lesser Heal", iconID = 135929 }
  W.spells[QUEST_SPELL] = { name = "Touch of Weakness", iconID = 136143 }
  W.spells[STAVES] = { name = "Staves", iconID = 135138 }
  local ns = { OtherSources = otherSources or {} }
  assert(loadfile("Data/TrainerCache.lua"))("LevelUpInfo", ns)
  SkillList = assert(loadfile("Data/SkillList.lua"))("LevelUpInfo", ns)
end

local function spell(rank)
  return { cost = 100, rank = rank, races = { Scourge = true } }
end

local function priest(levels)
  return { PRIEST = { covered = { Scourge = 20 }, levels = levels } }
end

local function build(trainers, fromLevel, toLevel)
  return SkillList.Build(trainers, "PRIEST", "Scourge", "Horde", fromLevel, toLevel)
end

local function entryFor(entries, spellID)
  for _, entry in ipairs(entries) do
    if entry.spellID == spellID then
      return entry
    end
  end
  error("no entry for " .. spellID)
end

local function test_new_rank_gets_previous_from_cache()
  setup()
  W.known[RANK_1] = true
  local trainers = priest({ [4] = { [RANK_1] = spell("Rank 1") }, [10] = { [RANK_2] = spell("Rank 2") } })
  Assert.equal(entryFor(build(trainers, 9, 10), RANK_2).previousSpellID, RANK_1)
end

local function test_missed_rank_gets_previous()
  setup()
  local trainers = priest({ [10] = { [RANK_2] = spell("Rank 2") }, [12] = { [RANK_3] = spell("Rank 3") } })
  local entry = entryFor(build(trainers, 13, 14), RANK_3)
  Assert.equal(entry.group, "missed")
  Assert.equal(entry.previousSpellID, RANK_2)
end

local function test_spellbook_fallback_for_starting_spell()
  setup()
  W.known[RANK_1] = true
  W.spells[RANK_1].subtext = "Rank 1"
  local trainers = priest({ [10] = { [RANK_2] = spell("Rank 2") } })
  Assert.equal(entryFor(build(trainers, 9, 10), RANK_2).previousSpellID, RANK_1)
end

local function test_no_subtext_api_gives_nil()
  setup()
  W.known[RANK_1] = true
  W.spells[RANK_1].subtext = "Rank 1"
  _G.C_Spell.GetSpellSubtext = nil
  local trainers = priest({ [10] = { [RANK_2] = spell("Rank 2") } })
  Assert.equal(entryFor(build(trainers, 9, 10), RANK_2).previousSpellID, nil)
end

local function test_by_name_lookup_error_gives_nil()
  setup()
  W.known[RANK_1] = true
  W.spells[RANK_1].subtext = "Rank 1"
  local byID = _G.C_Spell.GetSpellInfo
  _G.C_Spell.GetSpellInfo = function(arg)
    if type(arg) == "string" then
      error("bad argument")
    end
    return byID(arg)
  end
  local trainers = priest({ [4] = { [QUEST_SPELL] = spell("") }, [10] = { [RANK_2] = spell("Rank 2") } })
  local ok, entries = pcall(build, trainers, 9, 10)
  Assert.equal(ok, true)
  Assert.equal(entryFor(entries, RANK_2).previousSpellID, nil)
  Assert.equal(entryFor(entries, QUEST_SPELL).group, "missed")
end

local function test_fallback_wrong_rank_gives_nil()
  setup()
  W.known[RANK_3] = true
  W.spells[RANK_3].subtext = "Rank 3"
  local trainers = priest({ [10] = { [RANK_2] = spell("Rank 2") } })
  Assert.equal(entryFor(build(trainers, 9, 10), RANK_2).previousSpellID, nil)
end

local function test_missing_everywhere_gives_nil()
  setup()
  local trainers = priest({ [10] = { [RANK_2] = spell("Rank 2") } })
  Assert.equal(entryFor(build(trainers, 9, 10), RANK_2).previousSpellID, nil)
end

local function test_rank_text_without_number_skipped()
  setup()
  W.known[APPRENTICE] = true
  local trainers = priest({
    [1] = { [APPRENTICE] = spell("Apprentice"), [OTHER_RANK_1] = spell("") },
    [10] = { [RANK_2] = spell("Rank 2") },
  })
  Assert.equal(entryFor(build(trainers, 9, 10), RANK_2).previousSpellID, nil)
end

local function test_cache_entry_without_spell_info_skipped()
  setup()
  W.known[NO_INFO] = true
  local trainers = priest({ [1] = { [NO_INFO] = spell("Rank 1") }, [10] = { [RANK_2] = spell("Rank 2") } })
  Assert.equal(entryFor(build(trainers, 9, 10), RANK_2).previousSpellID, nil)
end

-- Both level orders, so neither "first seen" nor "last seen" passes by luck.
local function test_duplicate_key_lower_id_wins()
  setup()
  W.known[RANK_1] = true
  W.known[OTHER_RANK_1] = true
  local lowerFirst = priest({
    [1] = { [RANK_1] = spell("Rank 1") },
    [4] = { [OTHER_RANK_1] = spell("Rank 1") },
    [10] = { [RANK_2] = spell("Rank 2") },
  })
  local lowerLast = priest({
    [1] = { [OTHER_RANK_1] = spell("Rank 1") },
    [4] = { [RANK_1] = spell("Rank 1") },
    [10] = { [RANK_2] = spell("Rank 2") },
  })
  Assert.equal(entryFor(build(lowerFirst, 9, 10), RANK_2).previousSpellID, RANK_1)
  Assert.equal(entryFor(build(lowerLast, 9, 10), RANK_2).previousSpellID, RANK_1)
end

local function test_non_rank_entries_have_no_field()
  setup({
    PRIEST = {
      { spellID = QUEST_SPELL, level = 10, kind = "quest", npc = "Quest Giver", place = "Undercity", quest = "A Quest" },
      { spellID = STAVES, level = 1, kind = "weapon", npc = "Master", place = "Orgrimmar", cost = 1000 },
    },
  })
  local trainers = priest({ [10] = { [OTHER_RANK_1] = spell("Rank 1"), [RANK_2] = spell("Rank 2") } })
  local entries = build(trainers, 9, 10)
  Assert.equal(entryFor(entries, RANK_2).previousSpellID, OTHER_RANK_1)
  Assert.equal(entryFor(entries, OTHER_RANK_1).previousSpellID, nil)
  Assert.equal(entryFor(entries, QUEST_SPELL).previousSpellID, nil)
  Assert.equal(entryFor(entries, STAVES).previousSpellID, nil)
end

local function test_no_rank_entry_builds_no_index()
  setup()
  W.known[RANK_3] = true
  local trainers = priest({
    [4] = { [RANK_1] = spell("Rank 1"), [RANK_3] = spell("Rank 3") },
    [10] = { [OTHER_RANK_1] = spell("Rank 1") },
  })
  local entries = build(trainers, 9, 10)
  Assert.equal(#entries, 2)
  Assert.equal(W.calls.GetSpellInfo, 2)
end

return function()
  test_new_rank_gets_previous_from_cache()
  test_missed_rank_gets_previous()
  test_spellbook_fallback_for_starting_spell()
  test_no_subtext_api_gives_nil()
  test_by_name_lookup_error_gives_nil()
  test_fallback_wrong_rank_gives_nil()
  test_missing_everywhere_gives_nil()
  test_rank_text_without_number_skipped()
  test_cache_entry_without_spell_info_skipped()
  test_duplicate_key_lower_id_wins()
  test_non_rank_entries_have_no_field()
  test_no_rank_entry_builds_no_index()
end
