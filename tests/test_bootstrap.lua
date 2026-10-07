local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Trainer = require("tests.helpers.trainer")

local ADDON = "LevelUpInfo"

local W
local ns
local baseFrames

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
-- opts.trainer is passed to Trainer.Install; saved becomes the SavedVariables the client loads.
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
  Assert.equal(W.frames[baseFrames + 2], _G.LevelUpInfoMinimapButton)
  Assert.equal(W.frames[#W.frames], W.settings.category.frame)
  Assert.equal(_G.LevelUpInfoFrame, nil)
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
  Assert.equal(W.state(_G.LevelUpInfoFrame).title, "Level 10")
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
  Assert.equal(W.state(_G.LevelUpInfoFrame).title, "Level 10")
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
  Assert.equal(W.state(frame).title, "Level 10")
end

local function test_escape_list_and_tooltip_are_never_written()
  local saved = {
    trainers = {
      PRIEST = { covered = { Scourge = 10 }, levels = { [10] = { [139] = { cost = 100, rank = "Rank 1", races = { Scourge = true } } } } },
    },
  }
  setup(saved)
  _G.UISpecialFrames = { "GameMenuFrame" }
  local specialFrames = W.snapshot(_G.UISpecialFrames)
  local tooltipFields = W.snapshot(_G.GameTooltip)
  ding()
  for _, frame in ipairs(W.frames) do
    W.fireScript(frame, "OnEnter")
    W.fireScript(frame, "OnLeave")
  end
  W.fireScript(_G.LevelUpInfoFrame.CloseButton, "OnClick")
  Assert.equal(#W.tooltip > 0, true)
  Assert.equal(W.changedKeys(_G.UISpecialFrames, specialFrames), "")
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

return function()
  test_only_the_event_frame_exists_before_addon_loaded()
  test_other_addons_loading_are_ignored()
  test_addon_loaded_normalizes_db_and_unregisters_itself()
  test_saved_variables_hold_the_normalized_db_the_modules_use()
  test_idle_events_are_level_up_and_trainer_show_only()
  test_login_creates_only_event_frame_settings_canvas_and_minimap_button()
  test_login_with_minimap_button_off_creates_only_event_frame_and_settings_canvas()
  test_minimap_button_clicks_preview_and_open_options()
  test_minimap_checkbox_hides_the_button()
  test_disabled_still_scans_trainers()
  test_slash_test_shows_the_window()
  test_scale_slider_rescales_the_visible_window()
  test_reset_position_button_moves_the_visible_window()
  test_options_test_button_shows_preview()
  test_escape_list_and_tooltip_are_never_written()
  test_load_result_refreshes_window()
end
