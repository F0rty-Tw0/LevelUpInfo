-- The per-character table: the last level-up record and the hidden skill names.
local Assert = require("tests.helpers.assert")
local SavedState = require("LevelUpInfo.Settings.SavedState")

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
    Assert.equal(SavedState.InitializeCharacter(lastWith(fields)).last, nil)
  end
end

local function test_non_table_input_gives_no_last_level_up_and_no_hidden_names()
  for _, saved in ipairs({ "x", 5, true, { last = "x" }, { last = 5 }, {} }) do
    local charDB = SavedState.InitializeCharacter(saved)
    Assert.equal(charDB.last, nil)
    Assert.equal(next(charDB.hidden), nil)
  end
  local fromNil = SavedState.InitializeCharacter(nil)
  Assert.equal(fromNil.last, nil)
  Assert.equal(next(fromNil.hidden), nil)
end

local function test_hidden_keeps_non_empty_string_keys_with_true()
  local hidden = SavedState.InitializeCharacter({
    hidden = { ["Mind Flay"] = true, Renew = false, Smite = 1, Fade = "yes", [3] = true, [""] = true },
  }).hidden
  Assert.equal(hidden["Mind Flay"], true)
  Assert.equal(hidden.Renew, nil)
  Assert.equal(hidden.Smite, nil)
  Assert.equal(hidden.Fade, nil)
  Assert.equal(hidden[3], nil)
  Assert.equal(hidden[""], nil)
end

local function test_missing_or_bad_hidden_gives_an_empty_table()
  for _, saved in ipairs({ {}, { hidden = "x" }, { hidden = 5 }, { hidden = true } }) do
    local hidden = SavedState.InitializeCharacter(saved).hidden
    Assert.equal(type(hidden), "table")
    Assert.equal(next(hidden), nil)
  end
end

-- A save from before this feature: only `last`.
local function test_old_save_with_only_last_gets_an_empty_hidden_list_and_keeps_last()
  local charDB = SavedState.InitializeCharacter(lastWith({}))
  Assert.equal(charDB.last.toLevel, 10)
  Assert.equal(charDB.last.gains.health, 15)
  Assert.equal(next(charDB.hidden), nil)
end

local function test_hidden_and_last_are_kept_together_and_share_no_table_with_the_input()
  local saved = lastWith({})
  saved.hidden = { ["Mind Flay"] = true }
  local charDB = SavedState.InitializeCharacter(saved)
  Assert.equal(charDB.hidden["Mind Flay"], true)
  Assert.equal(charDB.last.toLevel, 10)
  Assert.equal(charDB.hidden == saved.hidden, false)
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
  test_valid_last_level_up_is_kept()
  test_bad_levels_drop_the_last_level_up()
  test_non_table_input_gives_no_last_level_up_and_no_hidden_names()
  test_hidden_keeps_non_empty_string_keys_with_true()
  test_missing_or_bad_hidden_gives_an_empty_table()
  test_old_save_with_only_last_gets_an_empty_hidden_list_and_keeps_last()
  test_hidden_and_last_are_kept_together_and_share_no_table_with_the_input()
  test_bad_gains_become_zero()
  test_before_keeps_only_number_values_of_known_keys()
  test_unknown_keys_are_dropped_at_every_level_of_the_last_level_up()
  test_normalized_last_level_up_shares_no_table_with_the_input()
end
