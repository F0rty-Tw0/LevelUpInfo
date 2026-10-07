local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local SavedState = require("LevelUpInfo.Settings.SavedState")

local W
local Panel
local db
local calls
local canvas
local framesBefore
local log
local hiddenFrame

local CHECKBOX_KEYS = { "enabled", "waitForCombat", "reducedMotion", "minimapButton" }

-- Fresh fake client, module and saved variables per test; the panel is registered, not opened.
local function setup()
  W = Wow.Install()
  Panel = assert(loadfile("Settings/Panel.lua"))("LevelUpInfo", {})
  db = SavedState.Initialize(nil)
  db.trainers = { PRIEST = { covered = { Scourge = 5 }, levels = {} } }
  calls = { scale = 0, resetPosition = 0, minimapButton = 0 }
  log = {}
  hiddenFrame = nil
  W.def("HideUIPanel", function(frame)
    log[#log + 1] = "hide"
    hiddenFrame = frame
  end)
  framesBefore = #W.frames
  Panel.Register(db, {
    onScale = function()
      calls.scale = calls.scale + 1
    end,
    onResetPosition = function()
      calls.resetPosition = calls.resetPosition + 1
    end,
    onTest = function()
      log[#log + 1] = "test"
    end,
    onMinimapButton = function()
      calls.minimapButton = calls.minimapButton + 1
      calls.minimapButtonSeen = db.minimapButton
    end,
  })
  canvas = W.settings.category.frame
end

-- The options window shows the canvas when its category is picked and hides it
-- when another one is; OnShow runs only on a real hidden -> shown change.
local function open()
  canvas:Show()
end

local function close()
  canvas:Hide()
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

local function checkboxes()
  return withTemplate("UICheckButtonTemplate")
end

local function sliders()
  return withTemplate("MinimalSliderWithSteppersTemplate")
end

local function button(text)
  for _, frame in ipairs(withTemplate("UIPanelButtonTemplate")) do
    if frame:GetText() == text then
      return frame
    end
  end
end

local function click(box, checked)
  box:SetChecked(checked)
  W.fireScript(box, "OnClick")
end

local function test_register_creates_only_the_empty_canvas_in_the_addons_list()
  setup()
  Assert.equal(#W.frames - framesBefore, 1)
  Assert.equal(W.settings.category.name, "Level Up Info")
  Assert.equal(W.settings.category.registered, true)
end

local function test_first_show_builds_controls_in_defaults_order()
  setup()
  open()
  local kinds = {}
  for _, frame in ipairs(W.frames) do
    local template = W.state(frame).template
    if template == "UICheckButtonTemplate" then
      kinds[#kinds + 1] = "checkbox"
    elseif template == "MinimalSliderWithSteppersTemplate" then
      kinds[#kinds + 1] = "slider"
    end
  end
  Assert.equal(table.concat(kinds, ","), "checkbox,slider,checkbox,slider,checkbox,checkbox")
end

local function test_second_show_builds_nothing_new()
  setup()
  open()
  local count = #W.frames
  close()
  open()
  Assert.equal(#W.frames, count)
end

local function test_checkboxes_show_saved_values()
  setup()
  db.waitForCombat = false
  open()
  Assert.equal(checkboxes()[1]:GetChecked(), true)
  Assert.equal(checkboxes()[2]:GetChecked(), false)
  Assert.equal(checkboxes()[3]:GetChecked(), false)
end

local function test_sliders_start_at_saved_value_with_range_and_steps()
  setup()
  db.duration = 12
  open()
  local duration = W.state(sliders()[1]).init
  Assert.equal(duration.value, 12)
  Assert.equal(duration.min, 3)
  Assert.equal(duration.max, 30)
  Assert.equal(duration.steps, 27)
  local scale = W.state(sliders()[2]).init
  Assert.equal(scale.value, 1.0)
  Assert.equal(scale.min, 0.5)
  Assert.equal(scale.max, 1.5)
  Assert.equal(scale.steps, 20)
end

local function test_checkbox_click_writes_its_setting()
  setup()
  open()
  for index, key in ipairs(CHECKBOX_KEYS) do
    local wanted = not db[key]
    click(checkboxes()[index], wanted)
    Assert.equal(db[key], wanted, key)
  end
end

local function test_minimap_checkbox_applies_after_writing()
  setup()
  open()
  click(checkboxes()[4], false)
  Assert.equal(calls.minimapButton, 1)
  Assert.equal(calls.minimapButtonSeen, false)
end

local function test_other_checkboxes_do_not_apply_minimap_button()
  setup()
  open()
  for index = 1, 3 do
    click(checkboxes()[index], false)
  end
  Assert.equal(calls.minimapButton, 0)
end

local function test_slider_change_writes_the_stepped_value()
  setup()
  open()
  W.fireCallback(sliders()[1], "OnValueChanged", 17.4)
  Assert.equal(db.duration, 17)
  Assert.equal(calls.scale, 0)
end

local function test_scale_change_writes_stepped_value_and_applies_at_once()
  setup()
  open()
  W.fireCallback(sliders()[2], "OnValueChanged", 1.0500000000000003)
  Assert.equal(db.scale, 1.05)
  Assert.equal(calls.scale, 1)
end

local function test_reset_position_button_calls_the_action()
  setup()
  open()
  W.fireScript(button("Reset position"), "OnClick")
  Assert.equal(calls.resetPosition, 1)
end

local function test_clear_skill_data_empties_trainers_in_place()
  setup()
  local trainers = db.trainers
  open()
  W.fireScript(button("Clear skill data"), "OnClick")
  Assert.equal(db.trainers, trainers)
  Assert.equal(next(trainers), nil)
end

local function test_test_button_shown_after_first_open()
  setup()
  open()
  Assert.equal(button("Test") ~= nil, true)
end

local function test_test_button_closes_options_then_previews()
  setup()
  open()
  W.fireScript(button("Test"), "OnClick")
  Assert.equal(table.concat(log, ","), "hide,test")
  Assert.equal(hiddenFrame, _G.SettingsPanel)
end

local function test_test_button_in_combat_previews_without_closing_options()
  setup()
  W.inCombat = true
  open()
  W.fireScript(button("Test"), "OnClick")
  Assert.equal(table.concat(log, ","), "test")
end

local function test_test_button_without_settings_panel_still_previews()
  setup()
  _G.SettingsPanel = nil
  open()
  W.fireScript(button("Test"), "OnClick")
  Assert.equal(table.concat(log, ","), "test")
end

local function test_default_button_restores_every_default_and_applies_scale()
  setup()
  db.enabled, db.duration, db.scale, db.reducedMotion = false, 20, 1.25, true
  canvas.OnDefault()
  Assert.equal(db.enabled, true)
  Assert.equal(db.duration, 10)
  Assert.equal(db.waitForCombat, true)
  Assert.equal(db.scale, 1.0)
  Assert.equal(db.reducedMotion, false)
  Assert.equal(calls.scale, 1)
end

local function test_default_button_restores_and_applies_minimap_button()
  setup()
  db.minimapButton = false
  canvas.OnDefault()
  Assert.equal(db.minimapButton, true)
  Assert.equal(calls.minimapButton, 1)
  Assert.equal(calls.minimapButtonSeen, true)
end

local function test_default_button_before_first_show_builds_nothing()
  setup()
  db.enabled = false
  local count = #W.frames
  canvas.OnDefault()
  Assert.equal(db.enabled, true)
  Assert.equal(#W.frames, count)
end

local function test_default_button_refreshes_built_controls()
  setup()
  open()
  click(checkboxes()[1], false)
  W.fireCallback(sliders()[1], "OnValueChanged", 25)
  canvas.OnDefault()
  Assert.equal(checkboxes()[1]:GetChecked(), true)
  Assert.equal(W.state(sliders()[1]).init.value, 10)
  Assert.equal(W.state(sliders()[2]).init.value, 1.0)
end

local function test_show_refreshes_controls_from_saved_values()
  setup()
  open()
  close()
  db.reducedMotion = true
  db.duration = 5
  open()
  Assert.equal(checkboxes()[3]:GetChecked(), true)
  Assert.equal(W.state(sliders()[1]).init.value, 5)
end

local function test_open_goes_to_the_category()
  setup()
  Panel.Open()
  Assert.equal(W.settings.openedID, 77)
end

return function()
  test_register_creates_only_the_empty_canvas_in_the_addons_list()
  test_first_show_builds_controls_in_defaults_order()
  test_second_show_builds_nothing_new()
  test_checkboxes_show_saved_values()
  test_sliders_start_at_saved_value_with_range_and_steps()
  test_checkbox_click_writes_its_setting()
  test_minimap_checkbox_applies_after_writing()
  test_other_checkboxes_do_not_apply_minimap_button()
  test_slider_change_writes_the_stepped_value()
  test_scale_change_writes_stepped_value_and_applies_at_once()
  test_reset_position_button_calls_the_action()
  test_clear_skill_data_empties_trainers_in_place()
  test_test_button_shown_after_first_open()
  test_test_button_closes_options_then_previews()
  test_test_button_in_combat_previews_without_closing_options()
  test_test_button_without_settings_panel_still_previews()
  test_default_button_restores_every_default_and_applies_scale()
  test_default_button_restores_and_applies_minimap_button()
  test_default_button_before_first_show_builds_nothing()
  test_default_button_refreshes_built_controls()
  test_show_refreshes_controls_from_saved_values()
  test_open_goes_to_the_category()
end
