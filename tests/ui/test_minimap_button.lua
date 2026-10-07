local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local MinimapButton
local db
local calls
local framesBefore

local TOLERANCE = 1e-9

-- Fresh fake client and module per test; Install is left to the test.
local function setup(minimapButton)
  W = Wow.Install()
  _G.LevelUpInfoMinimapButton = nil
  MinimapButton = assert(loadfile("UI/MinimapButton.lua"))("LevelUpInfo", {})
  db = { minimapButton = minimapButton }
  calls = { preview = 0, options = 0, previewArgs = nil }
  framesBefore = #W.frames
  MinimapButton.Install(db, {
    onPreview = function(...)
      calls.preview = calls.preview + 1
      calls.previewArgs = select("#", ...)
    end,
    onOptions = function()
      calls.options = calls.options + 1
    end,
  })
end

local function near(actual, expected, message)
  Assert.equal(math.abs(actual - expected) < TOLERANCE, true, message or (tostring(actual) .. " ~= " .. tostring(expected)))
end

local function test_offset_and_angle_round_trip()
  W = Wow.Install()
  MinimapButton = assert(loadfile("UI/MinimapButton.lua"))("LevelUpInfo", {})
  for _, angle in ipairs({ 0, 90, 225, 359 }) do
    local x, y = MinimapButton.OffsetFor(angle, 80)
    near(MinimapButton.AngleFor(x, y), angle, "angle " .. angle)
  end
end

local function test_angle_is_never_negative()
  W = Wow.Install()
  MinimapButton = assert(loadfile("UI/MinimapButton.lua"))("LevelUpInfo", {})
  for _, offset in ipairs({ { 1, -1 }, { 0, -1 }, { -1, -1 }, { -1, -1e-12 }, { 1, -1e-12 }, { 0, 0 } }) do
    local angle = MinimapButton.AngleFor(offset[1], offset[2])
    Assert.equal(angle >= 0 and angle < 360, true, tostring(angle))
  end
  near(MinimapButton.AngleFor(0, -1), 270)
end

local function test_install_when_off_creates_no_frame()
  setup(false)
  Assert.equal(#W.frames, framesBefore)
  Assert.equal(_G.LevelUpInfoMinimapButton, nil)
end

local function test_apply_after_turning_on_creates_the_button()
  setup(false)
  db.minimapButton = true
  MinimapButton.Apply()
  local button = _G.LevelUpInfoMinimapButton
  Assert.equal(button ~= nil and button:IsShown(), true)
  Assert.equal(button:GetParent(), _G.Minimap)
end

local function test_second_apply_creates_no_second_frame()
  setup(false)
  db.minimapButton = true
  MinimapButton.Apply()
  local count = #W.frames
  MinimapButton.Apply()
  Assert.equal(#W.frames, count)
end

local function test_apply_after_turning_off_hides_the_button()
  setup(true)
  db.minimapButton = false
  MinimapButton.Apply()
  Assert.equal(_G.LevelUpInfoMinimapButton:IsShown(), false)
end

local function test_apply_off_then_on_shows_the_button_again()
  setup(true)
  db.minimapButton = false
  MinimapButton.Apply()
  db.minimapButton = true
  MinimapButton.Apply()
  Assert.equal(_G.LevelUpInfoMinimapButton:IsShown(), true)
end

local function test_button_takes_both_clicks_and_left_drag()
  setup(true)
  local state = W.state(_G.LevelUpInfoMinimapButton)
  Assert.equal(table.concat(state.clickButtons, ","), "LeftButtonUp,RightButtonUp")
  Assert.equal(table.concat(state.dragButtons, ","), "LeftButton")
  Assert.equal(state.movable, true)
end

local function tooltipLog()
  local lines = {}
  for _, call in ipairs(W.tooltip) do
    local parts = { call[1] }
    for i = 2, #call do
      parts[#parts + 1] = call[i] == _G.LevelUpInfoMinimapButton and "button" or tostring(call[i])
    end
    lines[#lines + 1] = table.concat(parts, " ")
  end
  return table.concat(lines, "|")
end

local function test_tooltip_names_both_clicks_and_hides_on_leave()
  setup(true)
  W.fireScript(_G.LevelUpInfoMinimapButton, "OnEnter")
  W.fireScript(_G.LevelUpInfoMinimapButton, "OnLeave")
  Assert.equal(
    tooltipLog(),
    "SetOwner button ANCHOR_LEFT|SetText Level Up Info|AddLine Left-click: preview 1 1 1|" .. "AddLine Right-click: options 1 1 1|Show|Hide"
  )
end

local function test_right_click_opens_options()
  setup(true)
  W.fireScript(_G.LevelUpInfoMinimapButton, "OnClick", "RightButton")
  Assert.equal(calls.options, 1)
  Assert.equal(calls.preview, 0)
end

local function test_left_click_shows_preview_without_arguments()
  setup(true)
  W.fireScript(_G.LevelUpInfoMinimapButton, "OnClick", "LeftButton")
  Assert.equal(calls.preview, 1)
  Assert.equal(calls.previewArgs, 0)
  Assert.equal(calls.options, 0)
end

local function test_drag_stop_saves_angle_and_anchors_once_on_minimap()
  setup(true)
  local button = _G.LevelUpInfoMinimapButton
  W.fireScript(button, "OnDragStart")
  W.dropAt = { point = "CENTER", x = 450, y = 450 }
  W.state(button).center = { 450, 450 }
  W.fireScript(button, "OnDragStop")
  near(db.minimapAngle, 135)
  Assert.equal(W.state(button).userPlaced, false)
  Assert.equal(button:GetNumPoints(), 1)
  local point, relativeTo, relativePoint, x, y = button:GetPoint()
  Assert.equal(point .. "," .. relativePoint, "CENTER,CENTER")
  Assert.equal(relativeTo, _G.Minimap)
  local wantX, wantY = MinimapButton.OffsetFor(135, 80)
  near(x, wantX)
  near(y, wantY)
end

return function()
  test_offset_and_angle_round_trip()
  test_angle_is_never_negative()
  test_install_when_off_creates_no_frame()
  test_apply_after_turning_on_creates_the_button()
  test_second_apply_creates_no_second_frame()
  test_apply_after_turning_off_hides_the_button()
  test_apply_off_then_on_shows_the_button_again()
  test_button_takes_both_clicks_and_left_drag()
  test_tooltip_names_both_clicks_and_hides_on_leave()
  test_right_click_opens_options()
  test_left_click_shows_preview_without_arguments()
  test_drag_stop_saves_angle_and_anchors_once_on_minimap()
end
