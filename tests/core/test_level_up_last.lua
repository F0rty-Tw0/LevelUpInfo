local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local ARROW = require("LevelUpInfo.Core.Format").ARROW

local W
local Window
local Events
local LevelUp
local db
local charDB

-- The header line beside the portrait: the window's only own font string.
local function headerText()
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "FontString" and widget:GetParent() == Window.Frame() then
      return widget:GetText()
    end
  end
end

-- Fresh fake client, modules, db and character db per test; the player is level 10.
local function setup()
  W = Wow.Install()
  W.level = 10
  db = {
    enabled = true,
    waitForCombat = true,
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
    foldedGroups = {},
    trainers = {},
  }
  charDB = {}
  local ns = { OtherSources = {} }
  for _, file in ipairs({
    "Core/Localization.lua",
    "Core/Format.lua",
    "Core/Events.lua",
    "Data/TrainerCache.lua",
    "Data/SkillList.lua",
    "Data/RankChanges.lua",
    "Data/SpellFacts.lua",
    "UI/AutoHide.lua",
    "UI/ScrollBox.lua",
    "UI/SkillRow.lua",
    "UI/SkillGroup.lua",
    "UI/Layout.lua",
    "UI/GainLines.lua",
    "UI/Window.lua",
  }) do
    assert(loadfile(file))("LevelUpInfo", ns)
  end
  Events = ns.Events
  Window = ns.Window
  Window.Install(db)
  LevelUp = assert(loadfile("Core/LevelUp.lua"))("LevelUpInfo", ns)
  LevelUp.Install(db, charDB)
end

-- PLAYER_LEVEL_UP: level, health, power, talents, pvpSlots, str, agi, sta, int, spirit.
local function ding(level, health, power, talents, stamina)
  W.fireEvent(Events.frame, "PLAYER_LEVEL_UP", level, health or 0, power or 0, talents or 0, 0, 0, 0, stamina or 0, 0, 0)
end

local function regenRegistered()
  return Events.frame:IsEventRegistered("PLAYER_REGEN_ENABLED")
end

-- Gain lines live on the content frame; the header line on the window frame is skipped.
local function shownGainTexts()
  local texts = {}
  for _, widget in ipairs(W.frames) do
    local stub = W.state(widget)
    local gainLine = stub.template == "GameFontHighlight" and widget:GetParent() ~= Window.Frame()
    if stub.frameType == "FontString" and gainLine and stub.shown then
      texts[#texts + 1] = widget:GetText()
    end
  end
  return table.concat(texts, "|")
end

local function endCombat()
  W.inCombat = false
  W.fireEvent(Events.frame, "PLAYER_REGEN_ENABLED")
end

local function test_ding_saves_the_shown_record()
  setup()
  ding(10, 15)
  Assert.equal(charDB.last, Window.Current())
end

local function test_merged_ding_updates_the_saved_record()
  setup()
  ding(10, 15)
  local record = charDB.last
  ding(11, 16)
  Assert.equal(charDB.last, record)
  Assert.equal(charDB.last.toLevel, 11)
  Assert.equal(charDB.last.gains.health, 31)
end

local function test_ding_waiting_for_combat_is_saved_before_it_shows()
  setup()
  W.inCombat = true
  ding(10, 15)
  Assert.equal(Window.Current(), nil)
  Assert.equal(charDB.last.gains.health, 15)
  local record = charDB.last
  ding(11, 16)
  Assert.equal(charDB.last, record)
  Assert.equal(charDB.last.toLevel, 11)
  endCombat()
  Assert.equal(Window.Current(), charDB.last)
end

local function test_ding_replacing_a_test_preview_saves_the_new_record()
  setup()
  LevelUp.ShowTest()
  ding(10, 15)
  Assert.equal(charDB.last, Window.Current())
  Assert.equal(charDB.last.isTest, nil)
end

local function test_test_preview_saves_nothing()
  setup()
  LevelUp.ShowTest()
  Assert.equal(charDB.last, nil)
  local saved = { fromLevel = 8, toLevel = 9, gains = { health = 15 }, before = {} }
  charDB.last = saved
  LevelUp.ShowTest()
  Assert.equal(charDB.last, saved)
end

local function test_disabled_ding_saves_nothing()
  setup()
  db.enabled = false
  ding(10, 15)
  Assert.equal(charDB.last, nil)
end

local function test_refill_after_combat_updates_the_saved_record_in_place()
  setup()
  db.waitForCombat = false
  W.inCombat = true
  W.stats[3] = W.secret
  ding(10, 0, 0, 0, 1)
  W.stats[3] = 26
  endCombat()
  Assert.equal(charDB.last.before.stamina, 25)
end

-- A saved record as it comes back from disk.
local function recordAt(fromLevel, toLevel)
  return {
    fromLevel = fromLevel,
    toLevel = toLevel,
    gains = { health = 15, power = 0, talents = 0, strength = 0, agility = 0, stamina = 0, intellect = 0, spirit = 0 },
    before = { health = 100 },
  }
end

local function test_show_last_with_a_matching_record_shows_its_gains()
  setup()
  charDB.last = recordAt(9, 10)
  LevelUp.ShowLast()
  Assert.equal(Window.Current(), charDB.last)
  Assert.equal(Window.Frame():IsShown(), true)
  Assert.equal(headerText(), "Congratulations! You reached level 10.")
  Assert.contains(shownGainTexts(), "Health")
  Assert.contains(shownGainTexts(), "(+15)")
end

local function test_show_last_after_the_window_was_closed_shows_the_same_record()
  setup()
  ding(10, 15)
  Window.Frame():Hide()
  LevelUp.ShowLast()
  Assert.equal(Window.Frame():IsShown(), true)
  Assert.equal(Window.Current(), charDB.last)
end

-- The record the window shows is a one-level skills-only record for level 10.
local function assertSkillsOnly()
  local record = Window.Current()
  Assert.equal(record.isTest, true)
  Assert.equal(record.fromLevel .. "," .. record.toLevel, "9,10")
  Assert.equal(shownGainTexts(), "")
  Assert.equal(headerText(), "Congratulations! You reached level 10.")
end

local function test_show_last_with_an_older_record_shows_a_skills_only_record()
  setup()
  charDB.last = recordAt(8, 9)
  LevelUp.ShowLast()
  assertSkillsOnly()
  Assert.equal(charDB.last.toLevel, 9)
end

local function test_show_last_with_no_record_shows_a_skills_only_record()
  setup()
  LevelUp.ShowLast()
  assertSkillsOnly()
  Assert.equal(charDB.last, nil)
end

local function test_real_ding_replaces_the_skills_only_record_and_saves_it()
  setup()
  LevelUp.ShowLast()
  ding(10, 15)
  Assert.equal(Window.Current().isTest, nil)
  Assert.equal(charDB.last, Window.Current())
  Assert.equal(charDB.last.fromLevel, 9)
end

local function test_real_ding_merges_into_the_re_shown_last_record()
  setup()
  ding(10, 15)
  Window.Frame():Hide()
  LevelUp.ShowLast()
  ding(11, 16)
  Assert.equal(Window.Current(), charDB.last)
  Assert.equal(charDB.last.toLevel, 11)
  Assert.equal(charDB.last.gains.health, 31)
  Assert.equal(charDB.last.fromLevel, 9)
end

local function test_show_last_ignores_enabled_and_combat()
  setup()
  db.enabled = false
  W.inCombat = true
  charDB.last = recordAt(9, 10)
  LevelUp.ShowLast()
  Assert.equal(Window.Current(), charDB.last)
  Assert.equal(Window.Frame():IsShown(), true)
  charDB.last = nil
  LevelUp.ShowLast()
  assertSkillsOnly()
end

local function test_show_last_does_not_re_read_a_missing_before_out_of_combat()
  setup()
  charDB.last = recordAt(9, 10)
  charDB.last.before = {}
  charDB.last.gains.health = 15
  LevelUp.ShowLast()
  Assert.contains(shownGainTexts(), "(+15)")
  Assert.notContains(shownGainTexts(), ARROW)
  Assert.equal(charDB.last.before.health, nil)
  Assert.equal(regenRegistered(), false)
end

local function test_show_last_in_combat_waits_for_a_missing_before_and_saves_the_fill()
  setup()
  charDB.last = recordAt(9, 10)
  charDB.last.before = {}
  charDB.last.gains.health = 15
  W.inCombat = true
  W.healthMax = 115
  LevelUp.ShowLast()
  Assert.equal(regenRegistered(), true)
  Assert.equal(W.healthMax, 115)
  endCombat()
  Assert.equal(charDB.last.before.health, 100)
  Assert.equal(regenRegistered(), false)
end

local function test_show_last_on_the_pending_record_shows_it_once()
  setup()
  W.inCombat = true
  ding(10, 15)
  Assert.equal(regenRegistered(), true)
  LevelUp.ShowLast()
  Assert.equal(Window.Current(), charDB.last)
  Assert.equal(regenRegistered(), false)
  Window.Frame():Hide()
  endCombat()
  Assert.equal(Window.Frame():IsShown(), false)
  Assert.equal(Window.Current(), nil)
  Assert.equal(charDB.last.toLevel, 10)
end

local function test_show_last_on_the_pending_record_with_a_secret_stat_keeps_the_stat_wait()
  setup()
  W.inCombat = true
  W.stats[3] = W.secret
  ding(10, 0, 0, 0, 1)
  LevelUp.ShowLast()
  Assert.equal(regenRegistered(), true)
  W.stats[3] = 26
  endCombat()
  Assert.equal(Window.Current(), charDB.last)
  Assert.equal(charDB.last.before.stamina, 25)
  Assert.equal(regenRegistered(), false)
end

local function test_show_last_on_the_pending_record_while_a_preview_awaits_stats()
  setup()
  W.inCombat = true
  W.stats[3] = W.secret
  LevelUp.ShowTest()
  ding(10, 15)
  LevelUp.ShowLast()
  Assert.equal(Window.Current(), charDB.last)
  Assert.equal(regenRegistered(), true)
  W.stats[3] = 26
  endCombat()
  Assert.equal(Window.Current(), charDB.last)
  Assert.equal(regenRegistered(), false)
  Assert.equal(Window.Frame():IsShown(), true)
end

local function test_show_last_at_level_1_builds_a_skills_only_record()
  setup()
  W.level = 1
  LevelUp.ShowLast()
  Assert.equal(Window.Current().fromLevel, 0)
  Assert.equal(Window.Current().toLevel, 1)
end

return function()
  test_ding_saves_the_shown_record()
  test_merged_ding_updates_the_saved_record()
  test_ding_waiting_for_combat_is_saved_before_it_shows()
  test_ding_replacing_a_test_preview_saves_the_new_record()
  test_test_preview_saves_nothing()
  test_disabled_ding_saves_nothing()
  test_refill_after_combat_updates_the_saved_record_in_place()
  test_show_last_with_a_matching_record_shows_its_gains()
  test_show_last_after_the_window_was_closed_shows_the_same_record()
  test_show_last_with_an_older_record_shows_a_skills_only_record()
  test_show_last_with_no_record_shows_a_skills_only_record()
  test_real_ding_replaces_the_skills_only_record_and_saves_it()
  test_real_ding_merges_into_the_re_shown_last_record()
  test_show_last_ignores_enabled_and_combat()
  test_show_last_does_not_re_read_a_missing_before_out_of_combat()
  test_show_last_in_combat_waits_for_a_missing_before_and_saves_the_fill()
  test_show_last_on_the_pending_record_shows_it_once()
  test_show_last_on_the_pending_record_with_a_secret_stat_keeps_the_stat_wait()
  test_show_last_on_the_pending_record_while_a_preview_awaits_stats()
  test_show_last_at_level_1_builds_a_skills_only_record()
end
