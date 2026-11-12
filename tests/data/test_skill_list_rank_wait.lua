-- A trainer entry above your level has no cached rank text; until the spell's
-- own rank text loads, the window can ask Build to leave it out, so a rank
-- that will turn out unbuyable never shows for a moment.
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local SkillList

local BINDING_2 = 32546
local RENEW_2 = 6074

local function setup()
  W = Wow.Install()
  W.spells[BINDING_2] = { name = "Binding Heal", iconID = 135883 }
  W.spells[RENEW_2] = { name = "Renew", iconID = 135953 }
  local ns = { OtherSources = {} }
  assert(loadfile("Data/TrainerCache.lua"))("LevelUpInfo", ns)
  SkillList = assert(loadfile("Data/SkillList.lua"))("LevelUpInfo", ns)
end

local function spell(rank)
  return { cost = 100, rank = rank, races = { Scourge = true } }
end

local function trainers()
  return { PRIEST = { covered = { Scourge = 60 }, levels = { [60] = { [BINDING_2] = spell("") } } } }
end

local function ids(entries)
  local list = {}
  for i, entry in ipairs(entries) do
    list[i] = entry.spellID .. ":" .. entry.group
  end
  return table.concat(list, ",")
end

local function build(data, isWaiting)
  return ids(SkillList.Build(data, "PRIEST", "Scourge", "Horde", 59, 60, isWaiting))
end

local function always(answer)
  return function()
    return answer
  end
end

local function test_unloaded_rank_text_is_left_out_while_waiting()
  setup()
  Assert.equal(build(trainers(), always(true)), "")
end

local function test_unloaded_rank_text_is_kept_when_not_waiting()
  setup()
  Assert.equal(build(trainers(), always(false)), "32546:skill")
end

local function test_unloaded_rank_text_is_kept_without_a_predicate()
  setup()
  Assert.equal(build(trainers()), "32546:skill")
end

-- Cached rank text or a loaded subtext needs no wait, so the predicate is not asked.
local function test_entry_with_rank_text_does_not_ask()
  setup()
  W.spells[BINDING_2].subtext = "Rank 1"
  local data = trainers()
  data.PRIEST.levels[60][RENEW_2] = spell("Rank 1")
  local asked = 0
  Assert.equal(
    build(data, function()
      asked = asked + 1
      return true
    end),
    "32546:skill,6074:skill"
  )
  Assert.equal(asked, 0)
end

return function()
  test_unloaded_rank_text_is_left_out_while_waiting()
  test_unloaded_rank_text_is_kept_when_not_waiting()
  test_unloaded_rank_text_is_kept_without_a_predicate()
  test_entry_with_rank_text_does_not_ask()
end
