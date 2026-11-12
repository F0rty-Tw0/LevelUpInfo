-- Built-in priest rows: listed before any trainer visit, race-free, and
-- always behind the live trainer cache.
local Assert = require("tests.helpers.assert")
local BuiltinHelper = require("tests.helpers.builtin_spells")
local Wow = require("tests.helpers.wow")

local W
local SkillList

local FORTITUDE_1, RENEW_1, MIND_BLAST_1, RENEW_2, FLAY_2, SHADOW_PROTECTION_1 = 1243, 139, 8092, 6074, 17311, 976

local function row(cost, rank)
  return { cost = cost, rank = rank }
end

local BUILTIN = {
  [1] = { [FORTITUDE_1] = row(10, "Rank 1") },
  [8] = { [RENEW_1] = row(200, "Rank 1") },
  [10] = { [MIND_BLAST_1] = row(1000, "Rank 1") },
  [14] = { [RENEW_2] = row(900, "Rank 2") },
  -- Mind Flay Rank 1 is a talent, not sold.
  [28] = { [FLAY_2] = row(400, "Rank 2") },
  [30] = { [SHADOW_PROTECTION_1] = row(1500, "Rank 1") },
}

local function setup()
  W = Wow.Install()
  W.spells[FORTITUDE_1] = { name = "Power Word: Fortitude", iconID = 135987 }
  W.spells[RENEW_1] = { name = "Renew", iconID = 135953 }
  W.spells[MIND_BLAST_1] = { name = "Mind Blast", iconID = 136224 }
  W.spells[RENEW_2] = { name = "Renew", iconID = 135953 }
  W.spells[FLAY_2] = { name = "Mind Flay", iconID = 136208 }
  W.spells[SHADOW_PROTECTION_1] = { name = "Shadow Protection", iconID = 136121 }
  local ns = { OtherSources = {} }
  ns.BuiltinSpells = BuiltinHelper.load("forever", {
    forever = function()
      return { PRIEST = BUILTIN }
    end,
  })
  assert(loadfile("Data/TrainerCache.lua"))("LevelUpInfo", ns)
  SkillList = assert(loadfile("Data/SkillList.lua"))("LevelUpInfo", ns)
end

local function live(cost, rank)
  return { cost = cost, rank = rank, races = { Scourge = true } }
end

local function groups(entries)
  local list = {}
  for i, entry in ipairs(entries) do
    list[i] = entry.spellID .. ":" .. entry.group
  end
  return table.concat(list, ",")
end

local function find(entries, spellID)
  for _, entry in ipairs(entries) do
    if entry.spellID == spellID then
      return entry
    end
  end
  return nil
end

local function build(trainers, fromLevel, toLevel, race)
  return SkillList.Build(trainers, "PRIEST", race or "Scourge", "Horde", fromLevel, toLevel)
end

local function test_fresh_priest_lists_built_in_skills_without_hint()
  setup()
  local entries, showHint = build({}, 9, 10)
  Assert.equal(groups(entries), "8092:skill,1243:missed,139:missed")
  Assert.equal(find(entries, MIND_BLAST_1).cost, 1000)
  Assert.equal(showHint, false)
end

local function test_hint_shows_only_above_the_built_in_top_level()
  setup()
  local _, atTop = build({}, 29, 30)
  local _, aboveTop = build({}, 30, 31)
  Assert.equal(atTop, false)
  Assert.equal(aboveTop, true)
end

local function test_live_price_overrides_built_in()
  setup()
  local trainers = { PRIEST = { covered = { Scourge = 10 }, levels = { [10] = { [MIND_BLAST_1] = live(777, "Rank 1") } } } }
  Assert.equal(find(build(trainers, 9, 10), MIND_BLAST_1).cost, 777)
end

local function test_known_built_in_rank_supersedes_a_lower_one()
  setup()
  W.known[RENEW_2] = true
  Assert.equal(groups(build({}, 7, 14)), "8092:skill,1243:missed")
end

local function test_another_class_gets_no_rows_and_the_hint()
  setup()
  local entries, showHint = SkillList.Build({}, "WARRIOR", "Scourge", "Horde", 9, 10)
  Assert.equal(#entries, 0)
  Assert.equal(showHint, true)
end

local function test_partial_scan_shows_live_rows_then_built_in_above()
  setup()
  W.known[FORTITUDE_1] = true
  local trainers = {
    PRIEST = {
      covered = { Scourge = 20 },
      levels = { [8] = { [RENEW_1] = live(150, "Rank 1") }, [10] = { [MIND_BLAST_1] = live(900, "Rank 1") } },
    },
  }
  local entries, showHint = build(trainers, 12, 30)
  Assert.equal(groups(entries), "976:skill,6074:rank,139:missed,8092:missed")
  local costs = {}
  for i, entry in ipairs(entries) do
    costs[i] = entry.cost
  end
  Assert.equal(table.concat(costs, "/"), "1500/900/150/900")
  Assert.equal(showHint, false)
end

local function test_spell_at_another_live_level_lists_once_from_live()
  setup()
  local trainers = { PRIEST = { covered = { Scourge = 10 }, levels = { [9] = { [RENEW_1] = live(150, "Rank 1") } } } }
  local entries = build(trainers, 7, 10)
  Assert.equal(groups(entries), "139:skill,8092:skill,1243:missed")
  Assert.equal(find(entries, RENEW_1).level, 9)
  Assert.equal(find(entries, RENEW_1).cost, 150)
end

local function test_talent_rank_hidden_when_a_known_built_in_spell_probes_by_name()
  setup()
  W.known[FORTITUDE_1] = true
  Assert.equal(groups(build({}, 27, 28)), "139:missed,8092:missed,6074:missed")
end

local function test_fresh_priest_new_rank_gets_its_previous_rank()
  setup()
  local entries = build({}, 13, 14)
  Assert.equal(groups(entries), "6074:rank,1243:missed,139:missed,8092:missed")
  Assert.equal(find(entries, RENEW_2).previousSpellID, RENEW_1)
end

local function test_built_in_rows_ignore_race()
  setup()
  local scourge = groups(build({}, 9, 10, "Scourge"))
  Assert.equal(groups(build({}, 9, 10, "Human")), scourge)
  Assert.equal(groups(build({}, 9, 10, "Orc")), scourge)
end

local function test_known_built_in_spell_is_not_listed()
  setup()
  W.known[MIND_BLAST_1] = true
  Assert.equal(find(build({}, 9, 10), MIND_BLAST_1), nil)
end

return function()
  test_fresh_priest_lists_built_in_skills_without_hint()
  test_hint_shows_only_above_the_built_in_top_level()
  test_live_price_overrides_built_in()
  test_known_built_in_rank_supersedes_a_lower_one()
  test_another_class_gets_no_rows_and_the_hint()
  test_partial_scan_shows_live_rows_then_built_in_above()
  test_spell_at_another_live_level_lists_once_from_live()
  test_talent_rank_hidden_when_a_known_built_in_spell_probes_by_name()
  test_fresh_priest_new_rank_gets_its_previous_rank()
  test_built_in_rows_ignore_race()
  test_known_built_in_spell_is_not_listed()
end
