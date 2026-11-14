local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

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

return function()
  test_ding_saves_the_shown_record()
  test_merged_ding_updates_the_saved_record()
  test_ding_waiting_for_combat_is_saved_before_it_shows()
  test_ding_replacing_a_test_preview_saves_the_new_record()
  test_test_preview_saves_nothing()
  test_disabled_ding_saves_nothing()
  test_refill_after_combat_updates_the_saved_record_in_place()
end
