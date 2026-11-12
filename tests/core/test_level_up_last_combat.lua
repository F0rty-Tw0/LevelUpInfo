local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local Window
local Events
local LevelUp
local db
local charDB

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

local function endCombat()
  W.inCombat = false
  W.fireEvent(Events.frame, "PLAYER_REGEN_ENABLED")
end

local function test_show_last_on_the_pending_record_with_a_secret_stat_is_not_shown_again_after_combat()
  setup()
  W.inCombat = true
  W.stats[3] = W.secret
  ding(10, 0, 0, 0, 1)
  LevelUp.ShowLast()
  Assert.equal(regenRegistered(), true)
  Window.Frame():Hide()
  W.stats[3] = 26
  endCombat()
  Assert.equal(Window.Frame():IsShown(), false)
end

local function test_show_last_on_the_pending_record_while_a_preview_awaits_stats_is_not_shown_again_after_combat()
  setup()
  W.inCombat = true
  W.stats[3] = W.secret
  LevelUp.ShowTest()
  ding(10, 15)
  LevelUp.ShowLast()
  Assert.equal(regenRegistered(), true)
  Window.Frame():Hide()
  W.stats[3] = 26
  endCombat()
  Assert.equal(Window.Frame():IsShown(), false)
end

return function()
  test_show_last_on_the_pending_record_with_a_secret_stat_is_not_shown_again_after_combat()
  test_show_last_on_the_pending_record_while_a_preview_awaits_stats_is_not_shown_again_after_combat()
end
