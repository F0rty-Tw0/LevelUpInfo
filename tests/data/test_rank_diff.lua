local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

-- GREEN_FONT_COLOR (0.1, 1, 0.1) and RED_FONT_COLOR (1, 0.1, 0.1) as hex.
local GREEN = "|cff1aff1a"
local RED = "|cffff1a1a"
local R = "|r"

local RankDiff

local function setup()
  Wow.Install()
  local ns = {}
  assert(loadfile("Core/Localization.lua"))("LevelUpInfo", ns)
  assert(loadfile("Core/Format.lua"))("LevelUpInfo", ns)
  RankDiff = assert(loadfile("Data/RankDiff.lua"))("LevelUpInfo", ns)
end

local function test_higher_single_number_when_higher_is_better_is_green_plus()
  setup()
  Assert.equal(RankDiff.Values("44", "88", false), GREEN .. "(+44)" .. R)
end

local function test_higher_cost_when_lower_is_better_is_red_plus()
  setup()
  Assert.equal(RankDiff.Values("25", "40", true), RED .. "(+15)" .. R)
end

local function test_lower_cost_when_lower_is_better_is_green_minus()
  setup()
  Assert.equal(RankDiff.Values("40", "25", true), GREEN .. "(-15)" .. R)
end

local function test_range_shows_low_then_high_end_change()
  setup()
  Assert.equal(RankDiff.Values("12-17", "23-29", false), GREEN .. "(+11-12)" .. R)
end

local function test_range_end_changes_are_not_sorted()
  setup()
  Assert.equal(RankDiff.Values("10-20", "25-30", false), GREEN .. "(+15-10)" .. R)
end

local function test_range_going_down_is_red_minus()
  setup()
  Assert.equal(RankDiff.Values("23-29", "12-17", false), RED .. "(-11-12)" .. R)
end

local function test_range_with_equal_end_changes_shows_one_number()
  setup()
  Assert.equal(RankDiff.Values("10-20", "15-25", false), GREEN .. "(+5)" .. R)
end

local function test_range_with_one_end_unchanged_counts_as_same_direction()
  setup()
  Assert.equal(RankDiff.Values("10-20", "10-25", false), GREEN .. "(+0-5)" .. R)
end

local function test_range_ends_moving_opposite_ways_give_no_diff()
  setup()
  Assert.equal(RankDiff.Values("10-20", "5-25", false), nil)
end

local function test_range_against_single_number_gives_no_diff()
  setup()
  Assert.equal(RankDiff.Values("10-20", "25", false), nil)
  Assert.equal(RankDiff.Values("25", "10-20", false), nil)
end

local function test_percent_shows_once_at_the_end()
  setup()
  Assert.equal(RankDiff.Values("10%", "15%", false), GREEN .. "(+5%)" .. R)
  Assert.equal(RankDiff.Values("10-20%", "15-25%", false), GREEN .. "(+5%)" .. R)
end

local function test_thousands_values_change_under_1000_has_no_comma()
  setup()
  Assert.equal(RankDiff.Values("1,000", "1,200", false), GREEN .. "(+200)" .. R)
end

local function test_change_over_999_gets_comma_when_a_value_used_one()
  setup()
  Assert.equal(RankDiff.Values("900", "2,100", false), GREEN .. "(+1,200)" .. R)
end

local function test_change_over_999_has_no_comma_when_no_value_used_one()
  setup()
  Assert.equal(RankDiff.Values("900", "2100", false), GREEN .. "(+1200)" .. R)
end

local function test_decimals_follow_the_values_and_drop_trailing_zeros()
  setup()
  Assert.equal(RankDiff.Values("1.5", "2", false), GREEN .. "(+0.5)" .. R)
  Assert.equal(RankDiff.Values("1.5", "3.5", false), GREEN .. "(+2)" .. R)
  Assert.equal(RankDiff.Values("1.50", "2.00", false), GREEN .. "(+0.5)" .. R)
end

local function test_cast_time_diff_is_seconds_without_float_noise()
  setup()
  Assert.equal(RankDiff.Times(1700, 2200, 1000), RED .. "(+0.5)" .. R)
end

local function test_instant_counts_as_zero()
  setup()
  Assert.equal(RankDiff.Times(0, 1500, 1000), RED .. "(+1.5)" .. R)
end

local function test_shorter_cooldown_is_green_minus()
  setup()
  Assert.equal(RankDiff.Times(10000, 8000, 1000), GREEN .. "(-2)" .. R)
end

local function test_none_cooldown_counts_as_zero_in_minutes()
  setup()
  Assert.equal(RankDiff.Times(0, 120000, 60000), RED .. "(+2)" .. R)
end

local function test_time_change_rounding_to_zero_gives_no_diff()
  setup()
  Assert.equal(RankDiff.Times(1020, 1040, 1000), nil)
end

return function()
  test_higher_single_number_when_higher_is_better_is_green_plus()
  test_higher_cost_when_lower_is_better_is_red_plus()
  test_lower_cost_when_lower_is_better_is_green_minus()
  test_range_shows_low_then_high_end_change()
  test_range_end_changes_are_not_sorted()
  test_range_going_down_is_red_minus()
  test_range_with_equal_end_changes_shows_one_number()
  test_range_with_one_end_unchanged_counts_as_same_direction()
  test_range_ends_moving_opposite_ways_give_no_diff()
  test_range_against_single_number_gives_no_diff()
  test_percent_shows_once_at_the_end()
  test_thousands_values_change_under_1000_has_no_comma()
  test_change_over_999_gets_comma_when_a_value_used_one()
  test_change_over_999_has_no_comma_when_no_value_used_one()
  test_decimals_follow_the_values_and_drop_trailing_zeros()
  test_cast_time_diff_is_seconds_without_float_noise()
  test_instant_counts_as_zero()
  test_shorter_cooldown_is_green_minus()
  test_none_cooldown_counts_as_zero_in_minutes()
  test_time_change_rounding_to_zero_gives_no_diff()
end
