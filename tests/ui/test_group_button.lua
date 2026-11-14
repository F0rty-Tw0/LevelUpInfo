-- The Hide all / Show all button (an eye) on a fold group's heading.
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local EYE_CROSSED = "Interface\\AddOns\\LevelUpInfo\\Media\\EyeCrossed.tga"
local EYE_OPEN = "Interface\\AddOns\\LevelUpInfo\\Media\\EyeOpen.tga"
local SPECS = {
  { group = "missed", cap = 4, fold = true, groupAction = "dismiss" },
  { group = "weapon", cap = 4, fold = true, groupAction = "dismiss" },
  { group = "hidden", cap = 4, fold = true, startFolded = true, groupAction = "restore" },
  { group = "skill", cap = 4 },
  { group = "rank", cap = 4 },
}

-- Fresh fake client and module per test, built with the specs above;
-- AutoHide.Pause/Resume are counted and group clicks are logged.
local function setup()
  local W = Wow.Install()
  local ns = {}
  for _, path in ipairs({ "Core/Localization.lua", "Core/Events.lua", "UI/AutoHide.lua", "UI/ScrollBox.lua", "UI/GroupButton.lua" }) do
    assert(loadfile(path))("LevelUpInfo", ns)
  end
  local t = { W = W, spy = { pause = 0, resume = 0 }, clicks = {} }
  ns.AutoHide.Pause = function()
    t.spy.pause = t.spy.pause + 1
  end
  ns.AutoHide.Resume = function()
    t.spy.resume = t.spy.resume + 1
  end
  t.SkillGroup = assert(loadfile("UI/SkillGroup.lua"))("LevelUpInfo", ns)
  t.content = _G.CreateFrame("Frame", nil, _G.UIParent)
  t.SkillGroup.Build(t.content, SPECS, function() end, {}, function() end, function(group)
    t.clicks[#t.clicks + 1] = group
  end)

  return t
end

local function textureOf(t, group)
  local button = t.SkillGroup.GroupButton(group)
  for _, widget in ipairs(t.W.frames) do
    if widget:GetParent() == button and t.W.state(widget).texture then
      return t.W.state(widget)
    end
  end
end

local function test_hide_groups_get_a_crossed_eye_button()
  local t = setup()
  for _, group in ipairs({ "missed", "weapon" }) do
    local button = t.SkillGroup.GroupButton(group)
    Assert.equal(t.W.state(button).frameType, "Button")
    Assert.equal(t.W.state(button).template, nil)
    Assert.equal(button:GetParent(), t.SkillGroup.FoldButton(group))
    local width, height = button:GetSize()
    Assert.equal(width, 16)
    Assert.equal(height, 16)
    local point, relativeTo, relativePoint, x, y = button:GetPoint()
    Assert.equal(point, "TOPRIGHT")
    Assert.equal(relativeTo, button:GetParent())
    Assert.equal(relativePoint, "TOPRIGHT")
    Assert.equal(x, -20)
    Assert.equal(y, 0)
    Assert.equal(button:GetAlpha(), 0) -- hover only: invisible until the heading is hovered
    Assert.equal(textureOf(t, group).allPoints, true)
    Assert.equal(textureOf(t, group).texture, EYE_CROSSED)
    Assert.equal(textureOf(t, group).vertexColor, nil)
  end
end

local function test_hidden_group_gets_an_open_eye_button()
  local t = setup()
  Assert.equal(textureOf(t, "hidden").texture, EYE_OPEN)
  Assert.equal(textureOf(t, "hidden").vertexColor, nil)
end

local function test_groups_without_group_action_have_no_button()
  local t = setup()
  Assert.equal(t.SkillGroup.GroupButton("skill"), nil)
  Assert.equal(t.SkillGroup.GroupButton("rank"), nil)
  Assert.equal(t.SkillGroup.GroupButton("nope"), nil)
end

local function test_group_button_click_calls_on_group_action_with_its_group()
  local t = setup()
  t.W.fireScript(t.SkillGroup.GroupButton("weapon"), "OnClick")
  t.W.fireScript(t.SkillGroup.GroupButton("hidden"), "OnClick")
  Assert.equal(table.concat(t.clicks, "|"), "weapon|hidden")
end

local function test_group_button_hover_shows_its_tooltip()
  for group, text in pairs({ missed = "Hide all", weapon = "Hide all", hidden = "Show all" }) do
    local t = setup()
    local button = t.SkillGroup.GroupButton(group)
    t.W.fireScript(button, "OnEnter")
    Assert.equal(#t.W.tooltip, 3)
    Assert.equal(t.W.tooltip[1][1], "SetOwner")
    Assert.equal(t.W.tooltip[1][2], button)
    Assert.equal(t.W.tooltip[1][3], "ANCHOR_RIGHT")
    Assert.equal(t.W.tooltip[2][1], "SetText")
    Assert.equal(t.W.tooltip[2][2], text)
    Assert.equal(t.W.tooltip[3][1], "Show")
    Assert.equal(button:GetAlpha(), 1)
    Assert.equal(t.spy.pause, 1)
  end
end

local function test_group_button_leave_hides_the_tooltip_and_resumes()
  local t = setup()
  local button = t.SkillGroup.GroupButton("missed")
  t.W.fireScript(button, "OnEnter")
  t.W.fireScript(button, "OnLeave")
  Assert.equal(t.W.tooltip[#t.W.tooltip][1], "Hide")
  Assert.equal(button:GetAlpha(), 0)
  Assert.equal(t.spy.resume, 1)
end

-- Hiding the clicked group empties it and hides its fold button mid-hover; WoW
-- may send no OnLeave, so placing the heading again must hide the button.
local function test_placing_the_fold_button_hides_the_group_button_again()
  local t = setup()
  local button = t.SkillGroup.GroupButton("missed")
  t.W.fireScript(button, "OnEnter")
  Assert.equal(button:GetAlpha(), 1)
  t.SkillGroup.FoldButton("missed")
  Assert.equal(button:GetAlpha(), 0)
end

local function test_heading_hover_shows_the_group_button_dim()
  local t = setup()
  t.W.fireScript(t.SkillGroup.FoldButton("missed"), "OnEnter")
  Assert.equal(t.SkillGroup.GroupButton("missed"):GetAlpha(), 0.6)
end

local function test_leaving_the_heading_hides_the_group_button()
  local t = setup()
  local fold = t.SkillGroup.FoldButton("missed")
  t.W.fireScript(fold, "OnEnter")
  t.W.fireScript(fold, "OnLeave")
  Assert.equal(t.SkillGroup.GroupButton("missed"):GetAlpha(), 0)
end

-- Moving onto the group button leaves the heading, but the mouse is still inside it.
local function test_moving_onto_the_group_button_keeps_it_shown()
  local t = setup()
  local fold = t.SkillGroup.FoldButton("missed")
  t.W.fireScript(fold, "OnEnter")
  t.W.mouseOver[fold] = true
  t.W.fireScript(fold, "OnLeave")
  Assert.equal(t.SkillGroup.GroupButton("missed"):GetAlpha(), 0.6)
end

local function test_leaving_the_group_button_back_onto_the_heading_dims_it()
  local t = setup()
  local fold = t.SkillGroup.FoldButton("missed")
  local button = t.SkillGroup.GroupButton("missed")
  t.W.fireScript(button, "OnEnter")
  t.W.mouseOver[fold] = true
  t.W.fireScript(button, "OnLeave")
  Assert.equal(button:GetAlpha(), 0.6)
end

return function()
  test_hide_groups_get_a_crossed_eye_button()
  test_hidden_group_gets_an_open_eye_button()
  test_groups_without_group_action_have_no_button()
  test_group_button_click_calls_on_group_action_with_its_group()
  test_group_button_hover_shows_its_tooltip()
  test_group_button_leave_hides_the_tooltip_and_resumes()
  test_placing_the_fold_button_hides_the_group_button_again()
  test_heading_hover_shows_the_group_button_dim()
  test_leaving_the_heading_hides_the_group_button()
  test_moving_onto_the_group_button_keeps_it_shown()
  test_leaving_the_group_button_back_onto_the_heading_dims_it()
end
