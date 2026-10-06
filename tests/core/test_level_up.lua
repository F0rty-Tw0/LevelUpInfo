local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local Window
local Events
local LevelUp
local db

-- Fresh fake client, modules and db per test; the player is level 10.
local function setup()
  W = Wow.Install()
  W.level = 10
  db = {
    enabled = true,
    waitForCombat = true,
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
    trainers = {},
  }
  local ns = { OtherSources = {} }
  for _, file in ipairs({
    "Core/Localization.lua",
    "Core/Events.lua",
    "Data/TrainerCache.lua",
    "Data/SkillList.lua",
    "UI/AutoHide.lua",
    "UI/SkillRow.lua",
    "UI/Window.lua",
  }) do
    assert(loadfile(file))("LevelUpInfo", ns)
  end
  Events = ns.Events
  Window = ns.Window
  Window.Install(db)
  LevelUp = assert(loadfile("Core/LevelUp.lua"))("LevelUpInfo", ns)
  LevelUp.Install(db)
end

-- PLAYER_LEVEL_UP: level, health, power, talents, pvpSlots, str, agi, sta, int, spirit.
local function ding(level, health, power, talents, stamina)
  W.fireEvent(Events.frame, "PLAYER_LEVEL_UP", level, health or 0, power or 0, talents or 0, 0, 0, 0, stamina or 0, 0, 0)
end

local function regenRegistered()
  return Events.frame:IsEventRegistered("PLAYER_REGEN_ENABLED")
end

local function test_install_registers_only_the_level_up_event()
  setup()
  Assert.equal(Events.frame:IsEventRegistered("PLAYER_LEVEL_UP"), true)
  Assert.equal(regenRegistered(), false)
end

local function test_ding_out_of_combat_shows_payload_gains()
  setup()
  W.fireEvent(Events.frame, "PLAYER_LEVEL_UP", 10, 15, 20, 1, 0, 0, 0, 1, 0, 0)
  local record = Window.Current()
  Assert.equal(Window.Frame():IsShown(), true)
  Assert.equal(record.fromLevel, 9)
  Assert.equal(record.toLevel, 10)
  Assert.equal(record.isTest, nil)
  local gains = record.gains
  Assert.equal(
    table.concat({ gains.health, gains.power, gains.talents, gains.strength, gains.agility, gains.stamina, gains.intellect, gains.spirit }, ","),
    "15,20,1,0,0,1,0,0"
  )
end

local function test_ding_in_combat_waits_for_regen_when_enabled()
  setup()
  W.inCombat = true
  ding(10, 15)
  Assert.equal(Window.Current(), nil)
  Assert.equal(Window.Frame(), nil)
  Assert.equal(regenRegistered(), true)
  W.inCombat = false
  W.fireEvent(Events.frame, "PLAYER_REGEN_ENABLED")
  Assert.equal(Window.Current().toLevel, 10)
  Assert.equal(Window.Frame():IsShown(), true)
  Assert.equal(regenRegistered(), false)
end

local function test_ding_in_combat_shows_now_when_wait_is_off()
  setup()
  db.waitForCombat = false
  W.inCombat = true
  ding(10, 15)
  Assert.equal(Window.Current().toLevel, 10)
  Assert.equal(regenRegistered(), false)
end

local function test_two_dings_in_combat_merge_into_one_window()
  setup()
  W.inCombat = true
  ding(10, 15, 20, 1, 1)
  Assert.equal(regenRegistered(), true)
  ding(11, 16, 21, 0, 2)
  Assert.equal(regenRegistered(), true)
  Assert.equal(Window.Current(), nil)
  W.inCombat = false
  W.fireEvent(Events.frame, "PLAYER_REGEN_ENABLED")
  local record = Window.Current()
  Assert.equal(record.fromLevel, 9)
  Assert.equal(record.toLevel, 11)
  Assert.equal(table.concat({ record.gains.health, record.gains.power, record.gains.talents, record.gains.stamina }, ","), "31,41,1,3")
  Assert.equal(regenRegistered(), false)
  Assert.equal(W.state(Window.Frame()).title, "Level 11")
end

local function test_ding_while_live_window_visible_merges_and_refills_even_in_combat()
  setup()
  ding(10, 15)
  local record = Window.Current()
  W.inCombat = true
  ding(11, 16)
  Assert.equal(Window.Current(), record)
  Assert.equal(record.fromLevel, 9)
  Assert.equal(record.toLevel, 11)
  Assert.equal(record.gains.health, 31)
  Assert.equal(W.state(Window.Frame()).title, "Level 11")
  Assert.equal(regenRegistered(), false)
end

local function test_ding_replaces_a_test_preview()
  setup()
  W.level = 12
  LevelUp.ShowTest()
  local preview = Window.Current()
  ding(12, 15)
  local record = Window.Current()
  Assert.equal(record == preview, false)
  Assert.equal(record.isTest, nil)
  Assert.equal(record.fromLevel, 11)
  Assert.equal(record.toLevel, 12)
  Assert.equal(record.gains.health, 15)
end

local function test_hiding_ends_the_live_record()
  setup()
  ding(10, 15)
  Window.Frame():Hide()
  ding(12, 15)
  Assert.equal(Window.Current().fromLevel, 11)
  Assert.equal(Window.Current().gains.health, 15)
end

local function test_disabled_ignores_dings()
  setup()
  db.enabled = false
  W.inCombat = true
  ding(10, 15)
  Assert.equal(regenRegistered(), false)
  W.inCombat = false
  ding(10, 15)
  Assert.equal(Window.Current(), nil)
  Assert.equal(Window.Frame(), nil)
end

local function test_test_preview_ignores_enabled_and_combat()
  setup()
  db.enabled = false
  W.inCombat = true
  W.level = 20
  LevelUp.ShowTest()
  local record = Window.Current()
  Assert.equal(record.isTest, true)
  Assert.equal(record.fromLevel, 19)
  Assert.equal(record.toLevel, 20)
  Assert.equal(table.concat({ record.gains.health, record.gains.power, record.gains.stamina, record.gains.talents }, ","), "15,20,1,0")
  Assert.equal(W.state(Window.Frame()).title, "Level 20")
  Assert.equal(regenRegistered(), false)
end

local function test_ding_snapshots_before_values()
  setup()
  W.healthMax, W.manaMax, W.stats[3] = 100, 50, 25
  ding(10, 15, 20, 0, 1)
  local before = Window.Current().before
  Assert.equal(table.concat({ before.health, before.power, before.stamina }, ","), "100,50,25")
end

local function test_merged_ding_keeps_first_before()
  setup()
  W.healthMax = 100
  W.inCombat = true
  ding(10, 15)
  W.healthMax = 115
  ding(11, 16)
  W.inCombat = false
  W.fireEvent(Events.frame, "PLAYER_REGEN_ENABLED")
  Assert.equal(Window.Current().before.health, 100)
end

local function test_test_preview_before_is_live_minus_sample()
  setup()
  W.healthMax, W.manaMax, W.stats[3] = 115, 70, 26
  LevelUp.ShowTest()
  local before = Window.Current().before
  Assert.equal(table.concat({ before.health, before.power, before.stamina }, ","), "100,50,25")
end

local function test_test_preview_shows_no_mana_line_for_a_class_without_mana()
  setup()
  W.manaMax = 0
  LevelUp.ShowTest()
  local texts = {}
  for _, widget in ipairs(W.frames) do
    local stub = W.state(widget)
    if stub.frameType == "FontString" and stub.template == "GameFontHighlight" and stub.shown then
      texts[#texts + 1] = widget:GetText()
    end
  end
  local arrow = string.format("|TInterface\\Buttons\\Arrow-Up-Up:14:14:0:0:32:32:0:32:0:32:%d:%d:%d|t", 26, 255, 26)
  Assert.equal(table.concat(texts, "|"), "|cff49d36bHealth|r 85 " .. arrow .. " 100|" .. "|cffd9b38cStamina|r 9 " .. arrow .. " 10")
end

return function()
  test_install_registers_only_the_level_up_event()
  test_ding_out_of_combat_shows_payload_gains()
  test_ding_in_combat_waits_for_regen_when_enabled()
  test_ding_in_combat_shows_now_when_wait_is_off()
  test_two_dings_in_combat_merge_into_one_window()
  test_ding_while_live_window_visible_merges_and_refills_even_in_combat()
  test_ding_replaces_a_test_preview()
  test_hiding_ends_the_live_record()
  test_disabled_ignores_dings()
  test_test_preview_ignores_enabled_and_combat()
  test_ding_snapshots_before_values()
  test_merged_ding_keeps_first_before()
  test_test_preview_before_is_live_minus_sample()
  test_test_preview_shows_no_mana_line_for_a_class_without_mana()
end
