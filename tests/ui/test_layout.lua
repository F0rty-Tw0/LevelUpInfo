local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local Layout

-- Fresh fake client and module per test.
local function setup()
  W = Wow.Install()
  Layout = assert(loadfile("UI/Layout.lua"))("LevelUpInfo", {})
end

local function frame(height)
  local widget = _G.CreateFrame("Frame", nil, _G.UIParent)
  if height then
    widget:SetHeight(height)
  end
  return widget
end

local function assertPlaced(region, container, x, y)
  local points = W.state(region).points
  Assert.equal(#points, 1)
  local point = points[1]
  Assert.equal(point[1], "TOPLEFT")
  Assert.equal(point[2], container)
  Assert.equal(point[3], "TOPLEFT")
  Assert.equal(point[4], x)
  Assert.equal(point[5], y)
end

local function test_items_stack_per_container()
  setup()
  local content, child = frame(), frame()
  local a, b, c, d = frame(), frame(47), frame(), frame()
  Layout.Reset()
  Layout.Add(a, content, 4, 16)
  Layout.AddGap(content, 6)
  Layout.Add(b, content, 0, nil)
  Layout.Add(c, child, 0, 47)
  Layout.Add(d, child, 0, 59)
  local height, cursors = Layout.Run(content)
  assertPlaced(a, content, 4, 0)
  assertPlaced(b, content, 0, -22)
  assertPlaced(c, child, 0, 0)
  assertPlaced(d, child, 0, -47)
  Assert.equal(height, 69)
  Assert.equal(cursors[child], 106)
end

local function test_run_shows_placed_regions()
  setup()
  local content, region = frame(), frame()
  region:Hide()
  Layout.Reset()
  Layout.Add(region, content, 0, 16)
  Layout.Run(content)
  Assert.equal(region:IsShown(), true)
end

local function test_reused_item_as_gap_places_no_region()
  setup()
  local content, a = frame(), frame()
  Layout.Reset()
  Layout.Add(a, content, 4, 16)
  Layout.Run(content)
  a:Hide()
  Layout.Reset()
  Layout.AddGap(content, 6)
  local height = Layout.Run(content)
  Assert.equal(a:IsShown(), false)
  assertPlaced(a, content, 4, 0)
  Assert.equal(height, 6)
end

local function test_fewer_adds_ignore_items_past_count()
  setup()
  local content, a, b, c = frame(), frame(), frame(), frame()
  Layout.Reset()
  Layout.Add(a, content, 0, 16)
  Layout.Add(b, content, 0, 16)
  Layout.Add(c, content, 0, 16)
  Layout.Run(content)
  b:Hide()
  c:Hide()
  Layout.Reset()
  Layout.Add(a, content, 4, 24)
  local height = Layout.Run(content)
  assertPlaced(a, content, 4, 0)
  assertPlaced(b, content, 0, -16)
  assertPlaced(c, content, 0, -32)
  Assert.equal(b:IsShown(), false)
  Assert.equal(c:IsShown(), false)
  Assert.equal(height, 24)
end

return function()
  test_items_stack_per_container()
  test_run_shows_placed_regions()
  test_reused_item_as_gap_places_no_region()
  test_fewer_adds_ignore_items_past_count()
end
