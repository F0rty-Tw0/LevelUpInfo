local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Trainer = require("tests.helpers.trainer")

local ADDON = "LevelUpInfo"

local W
local ns
local baseFrames

-- The from and to level of the record the window shows.
local function shownLevels()
  local record = ns.Window.Current()
  return record.fromLevel .. " to " .. record.toLevel
end

local function tocFiles()
  local files = {}
  for line in io.lines("LevelUpInfo.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" then
      files[#files + 1] = line
    end
  end
  return files
end

local function priestServices()
  return {
    { name = "Smite", type = "used", level = 1, cost = 10, spellID = 585, rank = "Rank 1" },
    { name = "Renew", type = "available", level = 8, cost = 100, spellID = 139, rank = "Rank 1" },
  }
end

-- Fresh fake client with every TOC file loaded in order, as at login (before ADDON_LOADED).
-- opts.trainer is passed to Trainer.Install; saved becomes the SavedVariables the client loads,
-- opts.char the per-character ones.
local function login(saved, opts)
  W = Wow.Install()
  -- Named frames from an earlier test's client.
  _G.LevelUpInfoFrame = nil
  _G.LevelUpInfoMinimapButton = nil
  W.level = 10
  W.money = 500
  W.spells[139] = { name = "Renew", iconID = 1 }
  W.spells[585] = { name = "Smite", iconID = 2 }
  if opts and opts.trainer then
    Trainer.Install(W, opts.trainer)
  end
  _G.LevelUpInfoDB = saved
  _G.LevelUpInfoCharDB = opts and opts.char
  baseFrames = #W.frames
  ns = {}
  for _, file in ipairs(tocFiles()) do
    assert(loadfile(file))(ADDON, ns)
  end
end

local function loaded(name)
  W.fireEvent(ns.Events.frame, "ADDON_LOADED", name or ADDON)
end

local function setup(saved, opts)
  login(saved, opts)
  loaded()
end

local function registeredEvents()
  local events = {}
  for event in pairs(W.state(ns.Events.frame).events) do
    events[#events + 1] = event
  end
  table.sort(events)
  return table.concat(events, ",")
end

-- PLAYER_LEVEL_UP: level, health, power, talents, pvpSlots, str, agi, sta, int, spirit.
local function ding()
  W.fireEvent(ns.Events.frame, "PLAYER_LEVEL_UP", 10, 15, 20, 1, 0, 0, 0, 1, 0, 0)
end

local function slashTest()
  _G.SlashCmdList.LEVELUPINFO("test")
end

local function openPanel()
  W.fireScript(W.settings.category.frame, "OnShow")
end

local function withTemplate(template)
  local found = {}
  for _, frame in ipairs(W.frames) do
    if W.state(frame).template == template then
      found[#found + 1] = frame
    end
  end
  return found
end

local function test_only_the_event_frame_exists_before_addon_loaded()
  login(nil)
  Assert.equal(#W.frames - baseFrames, 1)
  Assert.equal(W.state(ns.Events.frame).events.ADDON_LOADED, true)
  Assert.equal(W.settings.category, nil)
end

local function test_other_addons_loading_are_ignored()
  login({ duration = 20 })
  loaded("Blizzard_TrainerUI")
  Assert.equal(W.state(ns.Events.frame).events.ADDON_LOADED, true)
  Assert.equal(registeredEvents(), "ADDON_LOADED")
  Assert.equal(#W.frames - baseFrames, 1)
  Assert.equal(_G.LevelUpInfoDB.duration, 20)
end

local function test_addon_loaded_normalizes_db_and_unregisters_itself()
  setup({ duration = 99, bogus = true })
  Assert.equal(_G.LevelUpInfoDB.duration, 30)
  Assert.equal(_G.LevelUpInfoDB.bogus, nil)
  Assert.equal(_G.LevelUpInfoDB.enabled, true)
  Assert.equal(W.state(ns.Events.frame).events.ADDON_LOADED, nil)
end

local function test_saved_variables_hold_the_normalized_db_the_modules_use()
  setup({ enabled = true })
  openPanel()
  local enabledBox = withTemplate("UICheckButtonTemplate")[1]
  enabledBox:SetChecked(false)
  W.fireScript(enabledBox, "OnClick")
  Assert.equal(_G.LevelUpInfoDB.enabled, false)
  ding()
  Assert.equal(ns.Window.Frame(), nil)
end

local function test_idle_events_are_level_up_and_trainer_show_only()
  setup(nil)
  Assert.equal(registeredEvents(), "PLAYER_LEVEL_UP,TRAINER_SHOW")
end

-- The minimap button brings three textures (background, icon, border).
local MINIMAP_BUTTON_FRAMES = 4

local function test_login_creates_only_event_frame_settings_canvas_and_minimap_button()
  setup(nil)
  Assert.equal(#W.frames - baseFrames, 2 + MINIMAP_BUTTON_FRAMES)
  Assert.equal(W.frames[baseFrames + 1], ns.Events.frame)
  Assert.equal(W.frames[baseFrames + 2], W.settings.category.frame)
  Assert.equal(W.frames[baseFrames + 3], _G.LevelUpInfoMinimapButton)
  Assert.equal(_G.LevelUpInfoFrame, nil)
end

-- The button is optional: if building it fails, /lui and the options page still work.
local function test_failing_minimap_button_leaves_slash_and_options_registered()
  login(nil)
  rawset(_G, "Minimap", nil)
  Assert.equal(pcall(loaded), false)
  Assert.equal(type(_G.SlashCmdList["LEVELUPINFO"]), "function")
  Assert.equal(W.settings.category ~= nil, true)
end

local function test_login_with_minimap_button_off_creates_only_event_frame_and_settings_canvas()
  setup({ minimapButton = false })
  Assert.equal(#W.frames - baseFrames, 2)
  Assert.equal(W.frames[baseFrames + 1], ns.Events.frame)
  Assert.equal(W.frames[baseFrames + 2], W.settings.category.frame)
end

local function test_minimap_button_clicks_preview_and_open_options()
  setup(nil)
  W.fireScript(_G.LevelUpInfoMinimapButton, "OnClick", "LeftButton")
  Assert.equal(_G.LevelUpInfoFrame:IsShown(), true)
  Assert.equal(shownLevels(), "9 to 10")
  W.fireScript(_G.LevelUpInfoMinimapButton, "OnClick", "RightButton")
  Assert.equal(W.settings.openedID, 77)
end

local function test_minimap_checkbox_hides_the_button()
  setup(nil)
  openPanel()
  local box = withTemplate("UICheckButtonTemplate")[4]
  box:SetChecked(false)
  W.fireScript(box, "OnClick")
  Assert.equal(_G.LevelUpInfoMinimapButton:IsShown(), false)
end

local function test_disabled_still_scans_trainers()
  setup({ enabled = false }, { trainer = { services = priestServices() } })
  W.fireEvent(ns.Events.frame, "TRAINER_SHOW")
  Assert.equal(_G.LevelUpInfoDB.trainers.PRIEST.levels[8][139].cost, 100)
  ding()
  Assert.equal(ns.Window.Frame(), nil)
  Assert.equal(_G.LevelUpInfoFrame, nil)
end

local function test_slash_test_shows_the_window()
  setup(nil)
  slashTest()
  Assert.equal(_G.LevelUpInfoFrame:IsShown(), true)
  Assert.equal(shownLevels(), "9 to 10")
end

local function test_scale_slider_rescales_the_visible_window()
  setup(nil)
  slashTest()
  Assert.equal(_G.LevelUpInfoFrame:GetScale(), 1)
  openPanel()
  W.fireCallback(withTemplate("MinimalSliderWithSteppersTemplate")[2], "OnValueChanged", 1.25)
  Assert.equal(_G.LevelUpInfoFrame:GetScale(), 1.25)
end

local function test_reset_position_button_moves_the_visible_window()
  setup(nil)
  slashTest()
  W.fireScript(_G.LevelUpInfoFrame, "OnDragStart")
  W.dropAt = { point = "TOPLEFT", x = 30, y = -40 }
  W.fireScript(_G.LevelUpInfoFrame, "OnDragStop")
  Assert.equal(_G.LevelUpInfoDB.position.point, "TOPLEFT")
  openPanel()
  for _, button in ipairs(withTemplate("UIPanelButtonTemplate")) do
    if button:GetText() == "Reset position" then
      W.fireScript(button, "OnClick")
    end
  end
  Assert.equal(_G.LevelUpInfoDB.position, nil)
  local point, _, _, x, y = _G.LevelUpInfoFrame:GetPoint()
  Assert.equal(table.concat({ point, x, y }, ","), "CENTER,0,120")
end

local function test_options_test_button_shows_preview()
  setup(nil)
  openPanel()
  Assert.equal(ns.Window.Frame(), nil)
  for _, button in ipairs(withTemplate("UIPanelButtonTemplate")) do
    if button:GetText() == "Test" then
      W.fireScript(button, "OnClick")
    end
  end
  local frame = ns.Window.Frame()
  Assert.equal(frame ~= nil and frame:IsShown(), true)
  Assert.equal(frame, _G.LevelUpInfoFrame)
  Assert.equal(shownLevels(), "9 to 10")
end

local function test_escape_list_gets_only_our_window_and_tooltip_is_never_written()
  local saved = {
    trainers = {
      PRIEST = { covered = { Scourge = 10 }, levels = { [10] = { [139] = { cost = 100, rank = "Rank 1", races = { Scourge = true } } } } },
    },
  }
  setup(saved)
  _G.UISpecialFrames = { "GameMenuFrame" }
  local tooltipFields = W.snapshot(_G.GameTooltip)
  ding()
  for _, frame in ipairs(W.frames) do
    W.fireScript(frame, "OnEnter")
    W.fireScript(frame, "OnLeave")
  end
  W.fireScript(_G.LevelUpInfoFrame.CloseButton, "OnClick")
  Assert.equal(#W.tooltip > 0, true)
  Assert.equal(table.concat(_G.UISpecialFrames, ","), "GameMenuFrame,LevelUpInfoFrame")
  Assert.equal(W.changedKeys(_G.GameTooltip, tooltipFields), "")
end

-- Shown change lines of the shown skill row with this name.
local function changeLines(name)
  for _, frame in ipairs(W.frames) do
    if frame.changeLines and frame:IsShown() and frame.name:GetText() == name then
      local count = 0
      for _, line in ipairs(frame.changeLines) do
        count = count + (line:IsShown() and 1 or 0)
      end
      return count
    end
  end
end

local function test_load_result_refreshes_window()
  local rank = function(text)
    return { cost = 50, rank = text, races = { Scourge = true } }
  end
  setup({
    trainers = { PRIEST = { covered = { Scourge = 10 }, levels = { [4] = { [589] = rank("Rank 1") }, [10] = { [594] = rank("Rank 2") } } } },
  })
  W.spells[589] = { name = "Shadow Word: Pain", iconID = 3, description = "Deals 30 damage." }
  W.spells[594] = { name = "Shadow Word: Pain", iconID = 3, description = "" }
  W.known[589] = true
  ding()
  Assert.equal(changeLines("Shadow Word: Pain"), 0)
  W.spells[594].description = "Deals 66 damage."
  W.broadcast("SPELL_DATA_LOAD_RESULT", 594, true)
  Assert.equal(changeLines("Shadow Word: Pain"), 1)
end

local function test_saved_fold_flags_reach_the_db_and_garbage_gives_an_empty_table()
  setup({ foldedGroups = { weapon = true } })
  Assert.equal(_G.LevelUpInfoDB.foldedGroups.weapon, true)
  setup({ foldedGroups = "weapon" })
  Assert.equal(next(_G.LevelUpInfoDB.foldedGroups), nil)
end

-- The shown fold button (a button with a fold icon).
local function foldButton()
  for _, frame in ipairs(W.frames) do
    if frame.foldIcon and frame:IsShown() then
      return frame
    end
  end
end

local function test_window_clicks_flip_the_saved_fold_table_in_place()
  local missed = { cost = 50, rank = "Rank 1", races = { Scourge = true } }
  setup({
    foldedGroups = { missed = true },
    trainers = { PRIEST = { covered = { Scourge = 10 }, levels = { [5] = { [139] = missed } } } },
  })
  slashTest()
  Assert.equal(_G.LevelUpInfoDB.foldedGroups.missed, true)
  W.fireScript(foldButton(), "OnClick")
  Assert.equal(_G.LevelUpInfoDB.foldedGroups.missed, nil)
end

local function test_toc_declares_the_per_character_saved_variable()
  local found = false
  for line in io.lines("LevelUpInfo.toc") do
    found = found or line == "## SavedVariablesPerCharacter: LevelUpInfoCharDB"
  end
  Assert.equal(found, true)
end

local function test_addon_loaded_writes_the_normalized_char_db()
  setup(nil, { char = { junk = true, last = { fromLevel = 9, toLevel = 10, bogus = 1, gains = { health = 15 } } } })
  Assert.equal(_G.LevelUpInfoCharDB.junk, nil)
  Assert.equal(_G.LevelUpInfoCharDB.last.bogus, nil)
  Assert.equal(_G.LevelUpInfoCharDB.last.gains.health, 15)
  Assert.equal(_G.LevelUpInfoCharDB.last.gains.power, 0)
end

local function test_missing_char_db_becomes_an_empty_table()
  setup(nil)
  Assert.equal(type(_G.LevelUpInfoCharDB), "table")
  Assert.equal(next(_G.LevelUpInfoCharDB), nil)
end

local function test_ding_saves_the_record_in_the_global_char_db()
  setup(nil)
  ding()
  Assert.equal(_G.LevelUpInfoCharDB.last, ns.Window.Current())
end

local function slashLast()
  _G.SlashCmdList.LEVELUPINFO("last")
end

local function clickButton(text)
  for _, button in ipairs(withTemplate("UIPanelButtonTemplate")) do
    if button:GetText() == text then
      W.fireScript(button, "OnClick")
    end
  end
end

-- A saved last level-up as WoW loads it from disk; the helper's player is level 10.
local function lastRecord()
  return {
    fromLevel = 9,
    toLevel = 10,
    gains = { health = 15, power = 20, talents = 1, strength = 0, agility = 0, stamina = 1, intellect = 0, spirit = 0 },
    before = { health = 100, power = 50, stamina = 25 },
  }
end

local function test_saved_last_level_up_shows_with_its_gains_after_login()
  setup(nil, { char = { last = lastRecord() } })
  slashLast()
  Assert.equal(shownLevels(), "9 to 10")
  Assert.equal(ns.Window.Current().isTest, nil)
  Assert.equal(ns.Window.Current().gains.health, 15)
  Assert.equal(ns.Window.Current(), _G.LevelUpInfoCharDB.last)
end

local function test_options_button_shows_the_last_level_up()
  setup(nil, { char = { last = lastRecord() } })
  openPanel()
  clickButton("Show last level-up")
  Assert.equal(_G.LevelUpInfoFrame:IsShown(), true)
  Assert.equal(shownLevels(), "9 to 10")
end

local function test_saved_last_level_up_of_an_older_level_shows_skills_only()
  local older = lastRecord()
  older.fromLevel, older.toLevel = 8, 9
  setup(nil, { char = { last = older } })
  slashLast()
  Assert.equal(ns.Window.Current().isTest, true)
  Assert.equal(shownLevels(), "9 to 10")
  Assert.equal(_G.LevelUpInfoCharDB.last.toLevel, 9)
end

local function test_fresh_character_shows_skills_only()
  setup(nil)
  slashLast()
  Assert.equal(shownLevels(), "9 to 10")
  Assert.equal(ns.Window.Current().isTest, true)
end

local function test_slash_test_does_not_change_what_the_button_shows()
  setup(nil, { char = { last = lastRecord() } })
  local last = _G.LevelUpInfoCharDB.last
  slashTest()
  Assert.equal(_G.LevelUpInfoCharDB.last, last)
  openPanel()
  clickButton("Show last level-up")
  Assert.equal(ns.Window.Current(), last)
end

return function()
  test_saved_last_level_up_shows_with_its_gains_after_login()
  test_options_button_shows_the_last_level_up()
  test_saved_last_level_up_of_an_older_level_shows_skills_only()
  test_fresh_character_shows_skills_only()
  test_slash_test_does_not_change_what_the_button_shows()
  test_toc_declares_the_per_character_saved_variable()
  test_addon_loaded_writes_the_normalized_char_db()
  test_missing_char_db_becomes_an_empty_table()
  test_ding_saves_the_record_in_the_global_char_db()
  test_saved_fold_flags_reach_the_db_and_garbage_gives_an_empty_table()
  test_window_clicks_flip_the_saved_fold_table_in_place()
  test_only_the_event_frame_exists_before_addon_loaded()
  test_other_addons_loading_are_ignored()
  test_addon_loaded_normalizes_db_and_unregisters_itself()
  test_saved_variables_hold_the_normalized_db_the_modules_use()
  test_idle_events_are_level_up_and_trainer_show_only()
  test_login_creates_only_event_frame_settings_canvas_and_minimap_button()
  test_login_with_minimap_button_off_creates_only_event_frame_and_settings_canvas()
  test_failing_minimap_button_leaves_slash_and_options_registered()
  test_minimap_button_clicks_preview_and_open_options()
  test_minimap_checkbox_hides_the_button()
  test_disabled_still_scans_trainers()
  test_slash_test_shows_the_window()
  test_scale_slider_rescales_the_visible_window()
  test_reset_position_button_moves_the_visible_window()
  test_options_test_button_shows_preview()
  test_escape_list_gets_only_our_window_and_tooltip_is_never_written()
  test_load_result_refreshes_window()
end
