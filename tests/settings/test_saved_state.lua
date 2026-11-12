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
  Assert.equal(db.minimapButton, true)
  Assert.equal(db.minimapAngle, nil)
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

local function test_minimap_angle_kept_and_wrapped()
  Assert.equal(SavedState.Initialize({ minimapAngle = 225 }).minimapAngle, 225)
  Assert.equal(SavedState.Initialize({ minimapAngle = 370 }).minimapAngle, 10)
  Assert.equal(SavedState.Initialize({ minimapAngle = -90 }).minimapAngle, 270)
end

local function test_bad_minimap_angle_is_dropped()
  Assert.equal(SavedState.Initialize({ minimapAngle = 0 / 0 }).minimapAngle, nil)
  Assert.equal(SavedState.Initialize({ minimapAngle = math.huge }).minimapAngle, nil)
  Assert.equal(SavedState.Initialize({ minimapAngle = -math.huge }).minimapAngle, nil)
  Assert.equal(SavedState.Initialize({ minimapAngle = "90" }).minimapAngle, nil)
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

local function test_folded_groups_default_to_empty()
  Assert.equal(next(SavedState.Initialize(nil).foldedGroups), nil)
  Assert.equal(next(SavedState.Initialize({ foldedGroups = "weapon" }).foldedGroups), nil)
end

local function test_folded_groups_keep_only_true_string_keys()
  local folded = SavedState.Initialize({
    foldedGroups = { weapon = true, missed = 1, skill = false, [3] = true },
  }).foldedGroups
  Assert.equal(folded.weapon, true)
  Assert.equal(folded.missed, nil)
  Assert.equal(folded.skill, nil)
  Assert.equal(folded[3], nil)
end

local GAIN_KEYS = { "health", "power", "talents", "strength", "agility", "stamina", "intellect", "spirit" }

local function lastWith(fields)
  local last = { fromLevel = 9, toLevel = 10, gains = { health = 15 }, before = { health = 100 } }
  for key, value in pairs(fields) do
    last[key] = value
  end
  return { last = last }
end

local function test_valid_last_level_up_is_kept()
  local saved = {
    last = {
      fromLevel = 9,
      toLevel = 11,
      gains = { health = 31, power = 41, talents = 1, strength = 0, agility = 0, stamina = 3, intellect = 0, spirit = 0 },
      before = { health = 100, power = 50, stamina = 25 },
    },
  }
  local last = SavedState.InitializeCharacter(saved).last
  Assert.equal(last.fromLevel .. "," .. last.toLevel, "9,11")
  Assert.equal(table.concat({ last.gains.health, last.gains.power, last.gains.talents, last.gains.stamina }, ","), "31,41,1,3")
  Assert.equal(table.concat({ last.before.health, last.before.power, last.before.stamina }, ","), "100,50,25")
end

local function test_bad_levels_drop_the_last_level_up()
  -- 0/0 is NaN; 9 >= 9 and 10 >= 9 break fromLevel < toLevel
  for _, fields in ipairs({
    { fromLevel = 0 },
    { fromLevel = 1.5 },
    { fromLevel = "9" },
    { fromLevel = 10 },
    { fromLevel = 11 },
    { toLevel = 0 / 0 },
    { toLevel = 10.5 },
    { toLevel = "10" },
    { toLevel = math.huge },
    { fromLevel = false },
  }) do
    Assert.equal(next(SavedState.InitializeCharacter(lastWith(fields))), nil)
  end
end

local function test_non_table_input_gives_an_empty_table()
  for _, saved in ipairs({ "x", 5, true }) do
    Assert.equal(next(SavedState.InitializeCharacter(saved)), nil)
  end
  Assert.equal(next(SavedState.InitializeCharacter(nil)), nil)
  Assert.equal(next(SavedState.InitializeCharacter({ last = "x" })), nil)
  Assert.equal(next(SavedState.InitializeCharacter({ last = 5 })), nil)
  Assert.equal(next(SavedState.InitializeCharacter({})), nil)
end

local function test_bad_gains_become_zero()
  local gains = SavedState.InitializeCharacter(lastWith({ gains = { health = "15", power = 0 / 0, stamina = 2 } })).last.gains
  Assert.equal(gains.health, 0)
  Assert.equal(gains.power, 0)
  Assert.equal(gains.talents, 0)
  Assert.equal(gains.stamina, 2)
  local whole = SavedState.InitializeCharacter(lastWith({ gains = "x" })).last.gains
  for _, key in ipairs(GAIN_KEYS) do
    Assert.equal(whole[key], 0)
  end
end

local function test_before_keeps_only_number_values_of_known_keys()
  local before = SavedState.InitializeCharacter(lastWith({
    before = { health = 100, power = "50", stamina = 0 / 0, talents = 3, spirit = 7, extra = 9 },
  })).last.before
  Assert.equal(before.health, 100)
  Assert.equal(before.power, nil)
  Assert.equal(before.stamina, nil)
  Assert.equal(before.talents, nil)
  Assert.equal(before.spirit, 7)
  Assert.equal(before.extra, nil)
  Assert.equal(next(SavedState.InitializeCharacter(lastWith({ before = "x" })).last.before), nil)
end

local function test_unknown_keys_are_dropped_at_every_level_of_the_last_level_up()
  local saved = lastWith({ isTest = true, extra = 1 })
  saved.extra = 2
  saved.last.gains.pvp = 3
  saved.last.before.extra = 4
  local charDB = SavedState.InitializeCharacter(saved)
  Assert.equal(charDB.extra, nil)
  Assert.equal(charDB.last.isTest, nil)
  Assert.equal(charDB.last.extra, nil)
  Assert.equal(charDB.last.gains.pvp, nil)
  Assert.equal(charDB.last.before.extra, nil)
  Assert.equal(charDB.last.gains.health, 15)
end

local function test_normalized_last_level_up_shares_no_table_with_the_input()
  local saved = lastWith({})
  local last = SavedState.InitializeCharacter(saved).last
  Assert.equal(last == saved.last, false)
  Assert.equal(last.gains == saved.last.gains, false)
  Assert.equal(last.before == saved.last.before, false)
end

return function()
  test_fresh_install_gets_every_default()
  test_number_settings_round_to_step_and_clamp()
  test_scale_step_carries_no_float_noise()
  test_bad_numbers_fall_back_to_default()
  test_non_boolean_flags_fall_back_to_default()
  test_saved_booleans_are_kept()
  test_position_kept_only_when_valid()
  test_minimap_angle_kept_and_wrapped()
  test_bad_minimap_angle_is_dropped()
  test_valid_trainer_entry_survives()
  test_malformed_trainer_entries_are_dropped()
  test_entry_without_any_valid_race_is_dropped()
  test_unknown_keys_are_dropped_at_every_level()
  test_folded_groups_default_to_empty()
  test_folded_groups_keep_only_true_string_keys()
  test_valid_last_level_up_is_kept()
  test_bad_levels_drop_the_last_level_up()
  test_non_table_input_gives_an_empty_table()
  test_bad_gains_become_zero()
  test_before_keeps_only_number_values_of_known_keys()
  test_unknown_keys_are_dropped_at_every_level_of_the_last_level_up()
  test_normalized_last_level_up_shares_no_table_with_the_input()
end
