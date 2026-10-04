local Assert = require("tests.helpers.assert")
local SavedState = require("LevelUpInfo.Settings.SavedState")

local function priestWith(levels, covered)
  return { trainers = { PRIEST = { covered = covered or {}, levels = levels } } }
end

local function validEntry()
  return { cost = 300, rank = "Rank 1", races = { Scourge = true } }
end

local function test_fresh_install_gets_every_default()
  local db = SavedState.Initialize(nil)
  Assert.equal(db.enabled, true)
  Assert.equal(db.duration, 10)
  Assert.equal(db.waitForCombat, true)
  Assert.equal(db.scale, 1.0)
  Assert.equal(db.reducedMotion, false)
  Assert.equal(db.position, nil)
  Assert.equal(next(db.trainers), nil)
end

local function test_number_settings_round_to_step_and_clamp()
  Assert.equal(SavedState.Initialize({ duration = 7.6 }).duration, 8)
  Assert.equal(SavedState.Initialize({ duration = 99 }).duration, 30)
  Assert.equal(SavedState.Initialize({ scale = 1.03 }).scale, 1.05)
  Assert.equal(SavedState.Initialize({ scale = 0.1 }).scale, 0.5)
end

local function test_scale_step_carries_no_float_noise()
  Assert.equal(SavedState.Initialize({ scale = 1.2 }).scale, 1.2)
end

local function test_bad_numbers_fall_back_to_default()
  Assert.equal(SavedState.Initialize({ duration = "5" }).duration, 10)
  Assert.equal(SavedState.Initialize({ duration = 0 / 0 }).duration, 10)
end

local function test_non_boolean_flags_fall_back_to_default()
  Assert.equal(SavedState.Initialize({ enabled = "no" }).enabled, true)
  Assert.equal(SavedState.Initialize({ reducedMotion = 1 }).reducedMotion, false)
end

local function test_saved_booleans_are_kept()
  local db = SavedState.Initialize({ enabled = false, reducedMotion = true })
  Assert.equal(db.enabled, false)
  Assert.equal(db.reducedMotion, true)
end

local function test_position_kept_only_when_valid()
  local position = SavedState.Initialize({ position = { point = "TOP", x = 1, y = 2 } }).position
  Assert.equal(position.point, "TOP")
  Assert.equal(position.x, 1)
  Assert.equal(position.y, 2)
  Assert.equal(SavedState.Initialize({ position = { point = 5, x = 1, y = 2 } }).position, nil)
  Assert.equal(SavedState.Initialize({ position = { point = "MIDDLE", x = 1, y = 2 } }).position, nil)
  Assert.equal(SavedState.Initialize({ position = { point = "TOP", x = "1", y = 2 } }).position, nil)
end

local function test_valid_trainer_entry_survives()
  local saved = priestWith({ [10] = { [8092] = validEntry() } }, { Scourge = 12 })
  local t = SavedState.Initialize(saved).trainers.PRIEST
  Assert.equal(t.covered.Scourge, 12)
  Assert.equal(t.levels[10][8092].cost, 300)
  Assert.equal(t.levels[10][8092].rank, "Rank 1")
  Assert.equal(t.levels[10][8092].races.Scourge, true)
end

local function test_malformed_trainer_entries_are_dropped()
  local function levelsAfter(levels)
    return SavedState.Initialize(priestWith(levels)).trainers.PRIEST.levels
  end
  local function entryWith(field, value)
    local entry = validEntry()
    entry[field] = value
    return { [10] = { [8092] = entry } }
  end
  Assert.equal(levelsAfter({ [0] = { [8092] = validEntry() } })[0], nil)
  Assert.equal(levelsAfter({ [2.5] = { [8092] = validEntry() } })[2.5], nil)
  Assert.equal(levelsAfter({ [10] = { x = validEntry() } })[10], nil)
  Assert.equal(levelsAfter(entryWith("cost", "300"))[10], nil)
  Assert.equal(levelsAfter(entryWith("rank", 5))[10], nil)
  Assert.equal(levelsAfter(entryWith("races", "Scourge"))[10], nil)
  Assert.equal(SavedState.Initialize(priestWith({}, { Scourge = -1 })).trainers.PRIEST.covered.Scourge, nil)
  Assert.equal(SavedState.Initialize({ trainers = { [7] = { covered = {}, levels = {} } } }).trainers[7], nil)
end

local function test_entry_without_any_valid_race_is_dropped()
  local entry = validEntry()
  entry.races = { Scourge = "yes", [3] = true }
  local levels = SavedState.Initialize(priestWith({ [10] = { [8092] = entry } })).trainers.PRIEST.levels
  Assert.equal(levels[10], nil)
end

local function test_unknown_keys_are_dropped_at_every_level()
  local entry = validEntry()
  entry.icon = 123
  local saved = priestWith({ [10] = { [8092] = entry } })
  saved.oldSetting = true
  saved.trainers.PRIEST.extra = {}
  local db = SavedState.Initialize(saved)
  Assert.equal(db.oldSetting, nil)
  Assert.equal(db.trainers.PRIEST.extra, nil)
  Assert.equal(db.trainers.PRIEST.levels[10][8092].icon, nil)
  Assert.equal(db.trainers.PRIEST.levels[10][8092].cost, 300)
end

return function()
  test_fresh_install_gets_every_default()
  test_number_settings_round_to_step_and_clamp()
  test_scale_step_carries_no_float_noise()
  test_bad_numbers_fall_back_to_default()
  test_non_boolean_flags_fall_back_to_default()
  test_saved_booleans_are_kept()
  test_position_kept_only_when_valid()
  test_valid_trainer_entry_survives()
  test_malformed_trainer_entries_are_dropped()
  test_entry_without_any_valid_race_is_dropped()
  test_unknown_keys_are_dropped_at_every_level()
end
