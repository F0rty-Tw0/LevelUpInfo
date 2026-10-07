local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local ARROW = require("LevelUpInfo.Core.Format").ARROW

local W = "|cffffffff"
local R = "|r"
-- GREEN_FONT_COLOR (0.1, 1, 0.1) and RED_FONT_COLOR (1, 0.1, 0.1) as hex.
local GREEN = "|cff1aff1a"
local RED = "|cffff1a1a"

local RankChanges

local function setup()
  Wow.Install()
  local ns = {}
  assert(loadfile("Core/Localization.lua"))("LevelUpInfo", ns)
  assert(loadfile("Core/Format.lua"))("LevelUpInfo", ns)
  assert(loadfile("Data/RankDiff.lua"))("LevelUpInfo", ns)
  RankChanges = assert(loadfile("Data/RankChanges.lua"))("LevelUpInfo", ns)
  return ns
end

local function facts(description, extra)
  local result = { description = description }
  for key, value in pairs(extra or {}) do
    result[key] = value
  end
  return result
end

-- "Label: old ARROW new (diff)" with the new value white; no diff, no trailing space.
local function line(label, old, new, color, diff)
  local text = label .. ": " .. old .. " " .. ARROW .. " " .. W .. new .. R
  if diff then
    text = text .. " " .. color .. diff .. R
  end
  return text
end

local function same(actual, expected)
  Assert.equal(table.concat(actual, "\n"), table.concat(expected, "\n"))
  Assert.equal(#actual, #expected)
end

local function test_heal_range_changes()
  setup()
  local lines = RankChanges.Lines(facts("Heals a friendly target for 47 to 58."), facts("Heals a friendly target for 76 to 91."))
  same(lines, { line("Healing", "47-58", "76-91", GREEN, "(+29-33)") })
end

local function test_absorb_wins_over_damage()
  setup()
  local lines = RankChanges.Lines(facts("Absorbs 44 damage. Lasts 30 sec."), facts("Absorbs 88 damage. Lasts 30 sec."))
  same(lines, { line("Absorb", "44", "88", GREEN, "(+44)") })
end

local function test_damage_line()
  setup()
  local lines = RankChanges.Lines(facts("Causes 30 Shadow damage over 18 sec."), facts("Causes 66 Shadow damage over 18 sec."))
  same(lines, { line("Damage", "30", "66", GREEN, "(+36)") })
end

local function test_armor_line()
  setup()
  local lines = RankChanges.Lines(facts("Increases armor by 30 for 30 min."), facts("Increases armor by 60 for 30 min."))
  same(lines, { line("Armor", "30", "60", GREEN, "(+30)") })
end

local function test_health_is_not_healing()
  setup()
  local lines = RankChanges.Lines(facts("Converts 38 health into 38 mana."), facts("Converts 68 health into 68 mana."))
  same(lines, { line("Mana", "38", "68", GREEN, "(+30)"), line("Mana", "38", "68", GREEN, "(+30)") })
end

local function test_duration_keeps_unit()
  setup()
  local lines = RankChanges.Lines(facts("Causes 30 Shadow damage over 15 sec."), facts("Causes 30 Shadow damage over 18 sec."))
  same(lines, { line("Duration", "15 sec", "18 sec", GREEN, "(+3)") })
end

local function test_percent_kept_in_value()
  setup()
  local lines = RankChanges.Lines(facts("Increases spell power by 10%."), facts("Increases spell power by 15%."))
  same(lines, { line("Effect", "10%", "15%", GREEN, "(+5%)") })
end

local function test_decimal_is_one_value()
  setup()
  local lines = RankChanges.Lines(facts("Stuns the target for 1.5 sec."), facts("Stuns the target for 2 sec."))
  same(lines, { line("Duration", "1.5 sec", "2 sec", GREEN, "(+0.5)") })
end

local function test_thousands_separator_is_one_value()
  setup()
  local lines = RankChanges.Lines(facts("Absorbing 1,000 damage."), facts("Absorbing 1,200 damage."))
  same(lines, { line("Absorb", "1,000", "1,200", GREEN, "(+200)") })
end

local function test_comma_before_four_digits_splits()
  setup()
  local lines = RankChanges.Lines(facts("Deals 1,2345 damage."), facts("Deals 1,2346 damage."))
  same(lines, { line("Damage", "2345", "2346", GREEN, "(+1)") })
end

local function test_template_differs_keeps_cost_line()
  setup()
  local lines = RankChanges.Lines(
    facts("Heals you for 30.", { cost = 30, powerToken = "MANA" }),
    facts("Heals a friendly target for 45 over time.", { cost = 45, powerToken = "MANA" })
  )
  same(lines, { line("Mana cost", "30", "45", RED, "(+15)") })
end

local function test_only_cost_changed()
  setup()
  local lines =
    RankChanges.Lines(facts("Heals you for 30.", { cost = 30, powerToken = "MANA" }), facts("Heals you for 30.", { cost = 45, powerToken = "MANA" }))
  same(lines, { line("Mana cost", "30", "45", RED, "(+15)") })
end

local function test_cost_label_fallback()
  setup()
  local lines = RankChanges.Lines(facts("Shoots.", { cost = 30, powerToken = "FOCUS" }), facts("Shoots.", { cost = 45, powerToken = "FOCUS" }))
  same(lines, { line("Cost", "30", "45", RED, "(+15)") })
end

local function test_cast_time_instant_to_seconds()
  setup()
  same(
    RankChanges.Lines(facts("Heals.", { castTime = 0 }), facts("Heals.", { castTime = 1500 })),
    { line("Cast time", "Instant", "1.5 sec", RED, "(+1.5)") }
  )
  same(
    RankChanges.Lines(facts("Heals.", { castTime = 1500 }), facts("Heals.", { castTime = 2000 })),
    { line("Cast time", "1.5 sec", "2 sec", RED, "(+0.5)") }
  )
end

local function test_cooldown_minutes_and_none()
  setup()
  same(
    RankChanges.Lines(facts("Shields.", { cooldown = 0 }), facts("Shields.", { cooldown = 120000 })),
    { line("Cooldown", "None", "2 min", RED, "(+2)") }
  )
  same(
    RankChanges.Lines(facts("Shields.", { cooldown = 10000 }), facts("Shields.", { cooldown = 8000 })),
    { line("Cooldown", "10 sec", "8 sec", GREEN, "(-2)") }
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
    line("Damage", "10", "20", GREEN, "(+10)"),
    line("Healing", "5", "8", GREEN, "(+3)"),
    line("Duration", "10 sec", "12 sec", GREEN, "(+2)"),
    line("Mana cost", "30", "45", RED, "(+15)"),
  })
end

-- RankDiff.Times goes through RankDiff.Values, so counting Values counts every diff.
local function test_dropped_lines_compute_no_diff()
  local ns = setup()
  local values = ns.RankDiff.Values
  local calls = 0
  ns.RankDiff.Values = function(...)
    calls = calls + 1
    return values(...)
  end
  RankChanges.Lines(
    facts("Deals 10 damage. Heals 5. Lasts 10 sec. Absorbs 3. Armor 7.", { cost = 30, castTime = 1500, cooldown = 6000 }),
    facts("Deals 20 damage. Heals 8. Lasts 12 sec. Absorbs 6. Armor 9.", { cost = 45, castTime = 2000, cooldown = 8000 })
  )
  Assert.equal(calls, 4)
end

local function test_higher_cost_is_red()
  setup()
  local lines = RankChanges.Lines(facts("Heals.", { cost = 25, powerToken = "MANA" }), facts("Heals.", { cost = 40, powerToken = "MANA" }))
  Assert.equal(lines[1], "Mana cost: 25 " .. ARROW .. " " .. W .. "40" .. R .. " " .. RED .. "(+15)" .. R)
end

local function test_damage_range_diff_is_green()
  setup()
  local lines = RankChanges.Lines(facts("Deals 12 to 17 damage."), facts("Deals 23 to 29 damage."))
  Assert.equal(lines[1], "Damage: 12-17 " .. ARROW .. " " .. W .. "23-29" .. R .. " " .. GREEN .. "(+11-12)" .. R)
end

local function test_line_without_diff_has_no_trailing_space()
  setup()
  local lines = RankChanges.Lines(facts("Deals 10 to 20 damage."), facts("Deals 5 to 25 damage."))
  Assert.equal(lines[1], "Damage: 10-20 " .. ARROW .. " " .. W .. "5-25" .. R)
end

local function test_cast_time_rounding_to_same_seconds_has_no_diff()
  setup()
  same(RankChanges.Lines(facts("Heals.", { castTime = 1020 }), facts("Heals.", { castTime = 1040 })), { line("Cast time", "1 sec", "1 sec") })
end

local function test_cooldown_diff_uses_new_value_unit()
  setup()
  same(
    RankChanges.Lines(facts("Shields.", { cooldown = 30000 }), facts("Shields.", { cooldown = 120000 })),
    { line("Cooldown", "30 sec", "2 min", RED, "(+1.5)") }
  )
end

local function test_cooldown_to_none_uses_old_value_unit()
  setup()
  same(
    RankChanges.Lines(facts("Shields.", { cooldown = 120000 }), facts("Shields.", { cooldown = 0 })),
    { line("Cooldown", "2 min", "None", GREEN, "(-2)") }
  )
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
  test_dropped_lines_compute_no_diff()
  test_higher_cost_is_red()
  test_damage_range_diff_is_green()
  test_line_without_diff_has_no_trailing_space()
  test_cast_time_rounding_to_same_seconds_has_no_diff()
  test_cooldown_diff_uses_new_value_unit()
  test_cooldown_to_none_uses_old_value_unit()
end
