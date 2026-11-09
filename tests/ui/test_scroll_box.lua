local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local KNOB = "Interface\\Buttons\\UI-ScrollBar-Knob"

-- Fresh fake client and module per test; AutoHide.Pause/Resume are counted.
local function setup()
  local W = Wow.Install()
  local ns = {}
  for _, path in ipairs({ "Core/Localization.lua", "Core/Events.lua", "UI/AutoHide.lua" }) do
    assert(loadfile(path))("LevelUpInfo", ns)
  end
  local t = { W = W, spy = { pause = 0, resume = 0 }, scrolled = {} }
  ns.AutoHide.Pause = function()
    t.spy.pause = t.spy.pause + 1
  end
  ns.AutoHide.Resume = function()
    t.spy.resume = t.spy.resume + 1
  end
  t.ScrollBox = assert(loadfile("UI/ScrollBox.lua"))("LevelUpInfo", ns)
  t.box = _G.CreateFrame("ScrollFrame", nil, _G.UIParent)
  t.box:SetSize(298, 100)
  return t
end

local function attached()
  local t = setup()
  t.bar = t.ScrollBox.Attach(t.box, 100, function(value)
    t.scrolled[#t.scrolled + 1] = value
  end)
  return t
end

local function test_attach_makes_one_hidden_bar_beside_the_box()
  local t = setup()
  local before = t.W.calls.CreateFrame
  local bar = t.ScrollBox.Attach(t.box, 100, function() end)
  Assert.equal(t.W.calls.CreateFrame - before, 1)
  Assert.equal(t.W.state(bar).frameType, "Slider")
  Assert.equal(bar:GetParent(), t.box)
  Assert.equal(bar:GetWidth(), 8)
  Assert.equal(bar:GetHeight(), 100)
  Assert.equal(bar:IsShown(), false)
  local point, relativeTo, relativePoint, x, y = bar:GetPoint(1)
  Assert.equal(point, "TOPLEFT")
  Assert.equal(relativeTo, t.box)
  Assert.equal(relativePoint, "TOPRIGHT")
  Assert.equal(x, 4)
  Assert.equal(y, 0)
  Assert.equal(t.W.state(bar:GetThumbTexture()).texture, KNOB)
end

local function test_wheel_moves_the_bar_47_per_notch()
  local t = attached()
  t.ScrollBox.SetRange(t.bar, 100, 400, 0)
  t.W.fireScript(t.box, "OnMouseWheel", -1)
  Assert.equal(t.bar:GetValue(), 47)
end

local function test_bar_change_scrolls_the_box_and_reports()
  local t = attached()
  t.ScrollBox.SetRange(t.bar, 100, 400, 0)
  t.bar:SetValue(30)
  Assert.equal(t.box:GetVerticalScroll(), 30)
  Assert.equal(t.scrolled[#t.scrolled], 30)
end

local function test_set_range_shows_bar_on_overflow()
  local t = attached()
  Assert.equal(t.ScrollBox.SetRange(t.bar, 100, 400, 0), 0)
  Assert.equal(t.bar:IsShown(), true)
  Assert.equal(select(2, t.bar:GetMinMaxValues()), 300)
end

local function test_set_range_hides_bar_when_content_fits()
  local t = attached()
  Assert.equal(t.ScrollBox.SetRange(t.bar, 100, 80, 0), 0)
  Assert.equal(t.bar:IsShown(), false)
  Assert.equal(select(2, t.bar:GetMinMaxValues()), 0)
end

local function test_set_range_clamps_kept_scroll()
  local t = attached()
  Assert.equal(t.ScrollBox.SetRange(t.bar, 100, 400, 250), 250)
  Assert.equal(t.ScrollBox.SetRange(t.bar, 100, 200, 250), 100)
  Assert.equal(t.bar:GetValue(), 100)
end

local function test_bar_hover_pauses_and_resumes()
  local t = attached()
  t.W.fireScript(t.bar, "OnEnter")
  Assert.equal(t.spy.pause, 1)
  t.W.fireScript(t.bar, "OnLeave")
  Assert.equal(t.spy.resume, 1)
end

return function()
  test_attach_makes_one_hidden_bar_beside_the_box()
  test_wheel_moves_the_bar_47_per_notch()
  test_bar_change_scrolls_the_box_and_reports()
  test_set_range_shows_bar_on_overflow()
  test_set_range_hides_bar_when_content_fits()
  test_set_range_clamps_kept_scroll()
  test_bar_hover_pauses_and_resumes()
end
