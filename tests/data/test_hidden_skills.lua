local Assert = require("tests.helpers.assert")

local HiddenSkills

local function setup()
  HiddenSkills = assert(loadfile("Data/HiddenSkills.lua"))("LevelUpInfo", {})
end

local function entries()
  return { { name = "Renew" }, { name = "Mind Flay" }, { name = "Smite" } }
end

local function flags(list)
  local out = {}
  for i, entry in ipairs(list) do
    out[i] = tostring(entry.hidden)
  end
  return table.concat(out, ",")
end

local function test_a_listed_name_is_marked_and_the_others_are_not()
  setup()
  local list = entries()
  HiddenSkills.Mark(list, { ["Mind Flay"] = true })
  Assert.equal(flags(list), "false,true,false")
end

local function test_every_rank_with_the_same_name_is_marked()
  setup()
  local list = { { name = "Renew", rank = "Rank 1" }, { name = "Smite" }, { name = "Renew", rank = "Rank 2" } }
  HiddenSkills.Mark(list, { Renew = true })
  Assert.equal(flags(list), "true,false,true")
end

local function test_marking_again_overwrites_a_stale_flag()
  setup()
  local list = entries()
  HiddenSkills.Mark(list, { Renew = true, Smite = true })
  Assert.equal(flags(list), "true,false,true")
  HiddenSkills.Mark(list, { ["Mind Flay"] = true })
  Assert.equal(flags(list), "false,true,false")
  HiddenSkills.Mark(list, {})
  Assert.equal(flags(list), "false,false,false")
end

local function test_a_name_not_in_the_table_is_false_not_nil()
  setup()
  local list = entries()
  HiddenSkills.Mark(list, { Fade = true })
  for _, entry in ipairs(list) do
    Assert.equal(entry.hidden, false)
  end
end

local function test_an_empty_table_and_an_empty_list_are_fine()
  setup()
  local list = entries()
  HiddenSkills.Mark(list, {})
  Assert.equal(flags(list), "false,false,false")
  HiddenSkills.Mark({}, { Renew = true })
end

local function test_only_the_value_true_counts()
  setup()
  local list = entries()
  HiddenSkills.Mark(list, { Renew = 1, ["Mind Flay"] = "yes", Smite = false })
  Assert.equal(flags(list), "false,false,false")
end

local function test_mark_returns_nothing()
  setup()
  Assert.equal(select("#", HiddenSkills.Mark(entries(), { Renew = true })), 0)
end

local function test_mark_keeps_the_list_order()
  setup()
  local list = entries()
  HiddenSkills.Mark(list, { Renew = true })
  Assert.equal(list[1].name .. "," .. list[2].name .. "," .. list[3].name, "Renew,Mind Flay,Smite")
end

local function test_mark_leaves_the_hidden_table_alone()
  setup()
  local hidden = { Renew = true }
  HiddenSkills.Mark(entries(), hidden)
  Assert.equal(next(hidden), "Renew")
  Assert.equal(next(hidden, "Renew"), nil)
  Assert.equal(hidden.Renew, true)
end

return function()
  test_a_listed_name_is_marked_and_the_others_are_not()
  test_every_rank_with_the_same_name_is_marked()
  test_marking_again_overwrites_a_stale_flag()
  test_a_name_not_in_the_table_is_false_not_nil()
  test_an_empty_table_and_an_empty_list_are_fine()
  test_only_the_value_true_counts()
  test_mark_returns_nothing()
  test_mark_keeps_the_list_order()
  test_mark_leaves_the_hidden_table_alone()
end
