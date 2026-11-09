local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AutoHide = ns.AutoHide or require("LevelUpInfo.UI.AutoHide")

local max = math.max
local min = math.min

local BAR_WIDTH = 8
local BAR_GAP = 4
local THUMB_HEIGHT = 24
local WHEEL_STEP = 47
local TRACK_ALPHA = 0.1
local THUMB_FILE = "Interface\\Buttons\\UI-ScrollBar-Knob"

-- The scrollbar and wheel wiring shared by the group boxes and the window's
-- view. Each caller owns its ScrollFrame, child, mouse settings and scroll
-- value; this only builds the bar beside the box and sets its range.
local ScrollBox = {}

-- Looked up at call time: tests replace AutoHide.Pause/Resume after load.
local function pause()
  AutoHide.Pause()
end

local function resume()
  AutoHide.Resume()
end

-- A plain Slider (no template) at the box's right edge + 4, `height` tall and
-- hidden. Moving it scrolls the box and reports the value; the wheel over
-- the box moves it 47 per notch.
function ScrollBox.Attach(box, height, onScroll)
  local bar = _G.CreateFrame("Slider", nil, box)
  bar:SetOrientation("VERTICAL")
  bar:SetSize(BAR_WIDTH, height)
  bar:SetPoint("TOPLEFT", box, "TOPRIGHT", BAR_GAP, 0)
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetColorTexture(1, 1, 1, TRACK_ALPHA)
  local thumb = bar:CreateTexture(nil, "ARTWORK")
  thumb:SetSize(BAR_WIDTH, THUMB_HEIGHT)
  thumb:SetTexture(THUMB_FILE)
  bar:SetThumbTexture(thumb)
  bar:SetValueStep(1)
  bar:SetObeyStepOnDrag(true)
  bar:EnableMouse(true)
  bar:SetScript("OnValueChanged", function(_, value)
    box:SetVerticalScroll(value)
    onScroll(value)
  end)
  bar:SetScript("OnEnter", pause)
  bar:SetScript("OnLeave", resume)
  bar:Hide()
  box:SetScript("OnMouseWheel", function(_, delta)
    bar:SetValue(bar:GetValue() - delta * WHEEL_STEP)
  end)
  return bar
end

-- The bar scrolls over what does not fit and shows only then; the kept
-- scroll is clamped to the new range and returned.
function ScrollBox.SetRange(bar, viewHeight, contentHeight, scroll)
  local range = max(0, contentHeight - viewHeight)
  local value = min(scroll, range)
  bar:SetMinMaxValues(0, range)
  bar:SetShown(range > 0)
  bar:SetValue(value)
  return value
end

ns.ScrollBox = ScrollBox
return ScrollBox
