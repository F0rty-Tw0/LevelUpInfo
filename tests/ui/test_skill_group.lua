local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local SPECS = { { group = "missed", cap = 5 }, { group = "weapon", cap = 5 }, { group = "skill" } }
local KNOB = "Interface\\Buttons\\UI-ScrollBar-Knob"

-- Fresh fake client and module per test; AutoHide.Pause/Resume are counted.
local function setup()
  local W = Wow.Install()
  local ns = {}
  for _, path in ipairs({ "Core/Localization.lua", "Core/Events.lua", "UI/AutoHide.lua" }) do
    assert(loadfile(path))("LevelUpInfo", ns)
  end
  local t = { W = W, spy = { pause = 0, resume = 0 }, toggled = {} }
  ns.AutoHide.Pause = function()
    t.spy.pause = t.spy.pause + 1
  end
  ns.AutoHide.Resume = function()
    t.spy.resume = t.spy.resume + 1
  end
  t.SkillGroup = assert(loadfile("UI/SkillGroup.lua"))("LevelUpInfo", ns)
  t.content = _G.CreateFrame("Frame", nil, _G.UIParent)
  return t
end

local function build(t)
  t.SkillGroup.Build(t.content, SPECS, function(group)
    t.toggled[#t.toggled + 1] = group
  end)
end

local function built()
  local t = setup()
  build(t)
  return t
end

local function barOf(t, box)
  for _, widget in ipairs(t.W.frames) do
    if t.W.state(widget).frameType == "Slider" and widget:GetParent() == box then
      return widget
    end
  end
end

local function countType(t, frameType)
  local count = 0
  for _, widget in ipairs(t.W.frames) do
    if t.W.state(widget).frameType == frameType then
      count = count + 1
    end
  end
  return count
end

local function wheel(t, box, delta, times)
  for _ = 1, times do
    t.W.fireScript(box, "OnMouseWheel", delta)
  end
end

local function click(t, group)
  t.W.fireScript(t.SkillGroup.Toggle(group, "x"), "OnClick")
end

local function test_collapse_before_build_is_safe()
  local t = setup()
  t.SkillGroup.Collapse()
  t.SkillGroup.HideAll()
  Assert.equal(t.SkillGroup.IsExpanded("missed"), false)
end

local function test_build_creates_hidden_toggles_for_capped_groups_only()
  local t = setup()
  local before = t.W.calls.CreateFrame
  build(t)
  Assert.equal(t.W.calls.CreateFrame, before + 2)
  for _, group in ipairs({ "missed", "weapon" }) do
    local toggle = t.SkillGroup.Toggle(group, "x")
    Assert.equal(t.W.state(toggle).frameType, "Button")
    Assert.equal(toggle:GetParent(), t.content)
    Assert.equal(toggle:IsShown(), false)
  end
  Assert.equal(countType(t, "ScrollFrame"), 0)
  Assert.equal(countType(t, "Slider"), 0)
end

local function test_toggle_sets_label_text()
  local t = built()
  local toggle = t.SkillGroup.Toggle("missed", "+3 more not yet learned")
  Assert.equal(toggle.label:GetText(), "+3 more not yet learned")
  Assert.equal(toggle:GetNumPoints(), 0)
  Assert.equal(toggle:IsShown(), false)
end

local function test_click_flips_expanded_and_calls_on_toggle()
  local t = built()
  click(t, "missed")
  Assert.equal(t.SkillGroup.IsExpanded("missed"), true)
  Assert.equal(t.SkillGroup.IsExpanded("weapon"), false)
  Assert.equal(t.toggled[1], "missed")
  click(t, "missed")
  Assert.equal(t.SkillGroup.IsExpanded("missed"), false)
  Assert.equal(#t.toggled, 2)
end

local function test_box_created_once()
  local t = built()
  local before = t.W.calls.CreateFrame
  local box, child = t.SkillGroup.Box("missed")
  Assert.equal(t.W.calls.CreateFrame, before + 3)
  local box2, child2 = t.SkillGroup.Box("missed")
  Assert.equal(t.W.calls.CreateFrame, before + 3)
  Assert.equal(box2, box)
  Assert.equal(child2, child)
  Assert.equal(box:GetParent(), t.content)
  Assert.equal(box:GetScrollChild(), child)
  local width, height = box:GetSize()
  Assert.equal(width, 298)
  Assert.equal(height, 235)
  Assert.equal(box:IsMouseWheelEnabled(), true)
  Assert.equal(box:IsMouseEnabled(), true)
  local point, relativeTo, relativePoint, x, y = barOf(t, box):GetPoint(1)
  Assert.equal(point, "TOPLEFT")
  Assert.equal(relativeTo, box)
  Assert.equal(relativePoint, "TOPRIGHT")
  Assert.equal(x, 4)
  Assert.equal(y, 0)
end

local function test_bar_has_knob_thumb_and_faint_track()
  local t = built()
  local box = t.SkillGroup.Box("missed")
  local bar = barOf(t, box)
  local thumb = bar:GetThumbTexture()
  Assert.equal(t.W.state(thumb).texture, KNOB)
  Assert.equal(t.W.state(thumb).width, 8)
  Assert.equal(t.W.state(thumb).height, 24)
  Assert.equal(t.W.state(bar).orientation, "VERTICAL")
  Assert.equal(bar:IsMouseEnabled(), true)
  local track
  for _, widget in ipairs(t.W.frames) do
    if widget:GetParent() == bar and t.W.state(widget).colorTexture then
      track = widget
    end
  end
  Assert.equal(t.W.state(track).allPoints, true)
  Assert.equal(t.W.state(track).colorTexture[4], 0.1)
end

local function test_wheel_moves_47_and_clamps()
  local t = built()
  local box = t.SkillGroup.Box("missed")
  t.SkillGroup.SetContentHeight("missed", 400)
  wheel(t, box, -1, 1)
  Assert.equal(box:GetVerticalScroll(), 47)
  wheel(t, box, -1, 3)
  Assert.equal(box:GetVerticalScroll(), 165)
  wheel(t, box, 1, 5)
  Assert.equal(box:GetVerticalScroll(), 0)
end

local function test_bar_hidden_when_content_fits()
  local t = built()
  local box, child = t.SkillGroup.Box("missed")
  local bar = barOf(t, box)
  t.SkillGroup.SetContentHeight("missed", 235)
  Assert.equal(child:GetHeight(), 235)
  Assert.equal(bar:IsShown(), false)
  Assert.equal(select(2, bar:GetMinMaxValues()), 0)
  t.SkillGroup.SetContentHeight("missed", 300)
  Assert.equal(bar:IsShown(), true)
  Assert.equal(select(2, bar:GetMinMaxValues()), 65)
end

local function test_scroll_clamped_when_content_shrinks()
  local t = built()
  local box = t.SkillGroup.Box("missed")
  t.SkillGroup.SetContentHeight("missed", 400)
  wheel(t, box, -1, 3)
  Assert.equal(box:GetVerticalScroll(), 141)
  t.SkillGroup.SetContentHeight("missed", 300)
  Assert.equal(box:GetVerticalScroll(), 65)
  t.SkillGroup.SetContentHeight("missed", 500)
  Assert.equal(box:GetVerticalScroll(), 65)
end

local function test_collapse_resets_flags_and_scroll()
  local t = built()
  click(t, "missed")
  click(t, "weapon")
  local box = t.SkillGroup.Box("missed")
  t.SkillGroup.SetContentHeight("missed", 400)
  wheel(t, box, -1, 1)
  t.SkillGroup.Collapse()
  Assert.equal(t.SkillGroup.IsExpanded("missed"), false)
  Assert.equal(t.SkillGroup.IsExpanded("weapon"), false)
  Assert.equal(box:GetVerticalScroll(), 0)
  Assert.equal(barOf(t, box):GetValue(), 0)
end

local function test_collapsing_click_resets_scroll()
  local t = built()
  click(t, "missed")
  local box = t.SkillGroup.Box("missed")
  t.SkillGroup.SetContentHeight("missed", 400)
  wheel(t, box, -1, 1)
  click(t, "missed")
  Assert.equal(box:GetVerticalScroll(), 0)
  t.SkillGroup.SetContentHeight("missed", 400)
  Assert.equal(box:GetVerticalScroll(), 0)
end

local function test_toggle_hover_swaps_font_and_pauses()
  local t = built()
  local toggle = t.SkillGroup.Toggle("missed", "x")
  t.W.fireScript(toggle, "OnEnter")
  Assert.equal(toggle.label:GetFontObject(), "GameFontHighlightSmall")
  Assert.equal(t.spy.pause, 1)
  t.W.fireScript(toggle, "OnLeave")
  Assert.equal(toggle.label:GetFontObject(), "GameFontDisableSmall")
  Assert.equal(t.spy.resume, 1)
end

local function test_box_and_bar_hover_pause()
  local t = built()
  local box = t.SkillGroup.Box("missed")
  for _, widget in ipairs({ box, barOf(t, box) }) do
    local pauses, resumes = t.spy.pause, t.spy.resume
    t.W.fireScript(widget, "OnEnter")
    Assert.equal(t.spy.pause, pauses + 1)
    t.W.fireScript(widget, "OnLeave")
    Assert.equal(t.spy.resume, resumes + 1)
  end
end

local function test_hide_all_hides_toggles_and_boxes()
  local t = built()
  t.SkillGroup.HideBox("weapon")
  local missed = t.SkillGroup.Toggle("missed", "x")
  local weapon = t.SkillGroup.Toggle("weapon", "x")
  missed:Show()
  weapon:Show()
  local box = t.SkillGroup.Box("missed")
  box:Show()
  t.SkillGroup.HideAll()
  Assert.equal(missed:IsShown(), false)
  Assert.equal(weapon:IsShown(), false)
  Assert.equal(box:IsShown(), false)
end

local function test_hide_toggle_and_box_hide_one_group()
  local t = built()
  local missed = t.SkillGroup.Toggle("missed", "x")
  local weapon = t.SkillGroup.Toggle("weapon", "x")
  missed:Show()
  weapon:Show()
  local box = t.SkillGroup.Box("missed")
  t.SkillGroup.HideToggle("missed")
  Assert.equal(missed:IsShown(), false)
  Assert.equal(weapon:IsShown(), true)
  t.SkillGroup.HideBox("missed")
  Assert.equal(box:IsShown(), false)
end

return function()
  test_collapse_before_build_is_safe()
  test_build_creates_hidden_toggles_for_capped_groups_only()
  test_toggle_sets_label_text()
  test_click_flips_expanded_and_calls_on_toggle()
  test_box_created_once()
  test_bar_has_knob_thumb_and_faint_track()
  test_wheel_moves_47_and_clamps()
  test_bar_hidden_when_content_fits()
  test_scroll_clamped_when_content_shrinks()
  test_collapse_resets_flags_and_scroll()
  test_collapsing_click_resets_scroll()
  test_toggle_hover_swaps_font_and_pauses()
  test_box_and_bar_hover_pause()
  test_hide_all_hides_toggles_and_boxes()
  test_hide_toggle_and_box_hide_one_group()
end
