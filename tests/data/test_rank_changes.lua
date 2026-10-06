local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W = "|cffffffff"
local R = "|r"

local RankChanges

local function setup()
  Wow.Install()
  local ns = {}
  assert(loadfile("Core/Localization.lua"))("LevelUpInfo", ns)
  RankChanges = assert(loadfile("Data/RankChanges.lua"))("LevelUpInfo", ns)
end

local function facts(description, extra)
  local result = { description = description }
  for key, value in pairs(extra or {}) do
    result[key] = value
  end
  return result
end

local function same(actual, expected)
  Assert.equal(table.concat(actual, "\n"), table.concat(expected, "\n"))
  Assert.equal(#actual, #expected)
end

local function test_heal_range_changes()
  setup()
  local lines = RankChanges.Lines(facts("Heals a friendly target for 47 to 58."), facts("Heals a friendly target for 76 to 91."))
  same(lines, { "Healing: 47-58 → " .. W .. "76-91" .. R })
end

local function test_absorb_wins_over_damage()
  setup()
  local lines = RankChanges.Lines(facts("Absorbs 44 damage. Lasts 30 sec."), facts("Absorbs 88 damage. Lasts 30 sec."))
  same(lines, { "Absorb: 44 → " .. W .. "88" .. R })
end

local function test_damage_line()
  setup()
  local lines = RankChanges.Lines(facts("Causes 30 Shadow damage over 18 sec."), facts("Causes 66 Shadow damage over 18 sec."))
  same(lines, { "Damage: 30 → " .. W .. "66" .. R })
end

local function test_armor_line()
  setup()
  local lines = RankChanges.Lines(facts("Increases armor by 30 for 30 min."), facts("Increases armor by 60 for 30 min."))
  same(lines, { "Armor: 30 → " .. W .. "60" .. R })
end

local function test_health_is_not_healing()
  setup()
  local lines = RankChanges.Lines(facts("Converts 38 health into 38 mana."), facts("Converts 68 health into 68 mana."))
  same(lines, { "Mana: 38 → " .. W .. "68" .. R, "Mana: 38 → " .. W .. "68" .. R })
end

local function test_duration_keeps_unit()
  setup()
  local lines = RankChanges.Lines(facts("Causes 30 Shadow damage over 15 sec."), facts("Causes 30 Shadow damage over 18 sec."))
  same(lines, { "Duration: 15 sec → " .. W .. "18 sec" .. R })
end

local function test_percent_kept_in_value()
  setup()
  local lines = RankChanges.Lines(facts("Increases spell power by 10%."), facts("Increases spell power by 15%."))
  same(lines, { "Effect: 10% → " .. W .. "15%" .. R })
end

local function test_decimal_is_one_value()
  setup()
  local lines = RankChanges.Lines(facts("Stuns the target for 1.5 sec."), facts("Stuns the target for 2 sec."))
  same(lines, { "Duration: 1.5 sec → " .. W .. "2 sec" .. R })
end

local function test_thousands_separator_is_one_value()
  setup()
  local lines = RankChanges.Lines(facts("Absorbing 1,000 damage."), facts("Absorbing 1,200 damage."))
  same(lines, { "Absorb: 1,000 → " .. W .. "1,200" .. R })
end

local function test_comma_before_four_digits_splits()
  setup()
  local lines = RankChanges.Lines(facts("Deals 1,2345 damage."), facts("Deals 1,2346 damage."))
  same(lines, { "Damage: 2345 → " .. W .. "2346" .. R })
end

local function test_template_differs_keeps_cost_line()
  setup()
  local lines = RankChanges.Lines(
    facts("Heals you for 30.", { cost = 30, powerToken = "MANA" }),
    facts("Heals a friendly target for 45 over time.", { cost = 45, powerToken = "MANA" })
  )
  same(lines, { "Mana cost: 30 → " .. W .. "45" .. R })
end

local function test_only_cost_changed()
  setup()
  local lines =
    RankChanges.Lines(facts("Heals you for 30.", { cost = 30, powerToken = "MANA" }), facts("Heals you for 30.", { cost = 45, powerToken = "MANA" }))
  same(lines, { "Mana cost: 30 → " .. W .. "45" .. R })
end

local function test_cost_label_fallback()
  setup()
  local lines = RankChanges.Lines(facts("Shoots.", { cost = 30, powerToken = "FOCUS" }), facts("Shoots.", { cost = 45, powerToken = "FOCUS" }))
  same(lines, { "Cost: 30 → " .. W .. "45" .. R })
end

local function test_cast_time_instant_to_seconds()
  setup()
  same(
    RankChanges.Lines(facts("Heals.", { castTime = 0 }), facts("Heals.", { castTime = 1500 })),
    { "Cast time: Instant → " .. W .. "1.5 sec" .. R }
  )
  same(
    RankChanges.Lines(facts("Heals.", { castTime = 1500 }), facts("Heals.", { castTime = 2000 })),
    { "Cast time: 1.5 sec → " .. W .. "2 sec" .. R }
  )
end

local function test_cooldown_minutes_and_none()
  setup()
  same(
    RankChanges.Lines(facts("Shields.", { cooldown = 0 }), facts("Shields.", { cooldown = 120000 })),
    { "Cooldown: None → " .. W .. "2 min" .. R }
  )
  same(
    RankChanges.Lines(facts("Shields.", { cooldown = 10000 }), facts("Shields.", { cooldown = 8000 })),
    { "Cooldown: 10 sec → " .. W .. "8 sec" .. R }
  )
end

local function test_nil_stat_makes_no_line()
  setup()
  same(RankChanges.Lines(facts("Heals.", { castTime = 1500 }), facts("Heals.")), {})
end

local function test_identical_facts_empty()
  setup()
  local stats = { castTime = 1500, cooldown = 0, cost = 30, powerToken = "MANA" }
  same(RankChanges.Lines(facts("Heals you for 47 to 58.", stats), facts("Heals you for 47 to 58.", stats)), {})
end

local function test_cap_four_in_order()
  setup()
  local lines = RankChanges.Lines(
    facts("Deals 10 damage. Heals you for 5. Lasts 10 sec.", { cost = 30, powerToken = "MANA", castTime = 1500 }),
    facts("Deals 20 damage. Heals you for 8. Lasts 12 sec.", { cost = 45, powerToken = "MANA", castTime = 2000 })
  )
  same(lines, {
    "Damage: 10 → " .. W .. "20" .. R,
    "Healing: 5 → " .. W .. "8" .. R,
    "Duration: 10 sec → " .. W .. "12 sec" .. R,
    "Mana cost: 30 → " .. W .. "45" .. R,
  })
end

return function()
  test_heal_range_changes()
  test_absorb_wins_over_damage()
  test_damage_line()
  test_armor_line()
  test_health_is_not_healing()
  test_duration_keeps_unit()
  test_percent_kept_in_value()
  test_decimal_is_one_value()
  test_thousands_separator_is_one_value()
  test_comma_before_four_digits_splits()
  test_template_differs_keeps_cost_line()
  test_only_cost_changed()
  test_cost_label_fallback()
  test_cast_time_instant_to_seconds()
  test_cooldown_minutes_and_none()
  test_nil_stat_makes_no_line()
  test_identical_facts_empty()
  test_cap_four_in_order()
end
