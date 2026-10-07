local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")

-- Lua 5.1 (game, CI) has atan2; a 5.3+ test runner only has the two-argument atan.
-- WoW's degree-based atan2 / sin / cos globals are never used.
local atan2 = math.atan2 or math.atan
local cos, sin, rad, deg = math.cos, math.sin, math.rad, math.deg

local Text = Localization.Text

local BUTTON_NAME = "LevelUpInfoMinimapButton"
-- 31x31, strata MEDIUM, frame level 8, both locked: what LibDBIcon gives
-- every minimap button, so ours stacks like theirs under open windows.
local BUTTON_SIZE = 31
local STRATA = "MEDIUM"
local FRAME_LEVEL = 8
local DEFAULT_ANGLE = 225
local RING_OFFSET = 10
local FULL_CIRCLE = 360
local TEXTURE_X = 7
local BACKGROUND_SIZE = 20
local BACKGROUND_Y = -5
local ICON_SIZE = 17
local ICON_Y = -6
local BORDER_SIZE = 53
local BACKGROUND_TEXTURE = "Interface\\Minimap\\UI-Minimap-Background"
local ICON_TEXTURE = "Interface\\AddOns\\LevelUpInfo\\Media\\Icon"
local BORDER_TEXTURE = "Interface\\Minimap\\MiniMap-TrackingBorder"
local HIGHLIGHT_TEXTURE = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

-- Our own button on the minimap ring. No events, no timers; an OnUpdate
-- runs only while it is dragged, sliding it along the ring under the cursor.
local MinimapButton = {}

local db
local actions
local button

function MinimapButton.OffsetFor(angle, radius)
  local radians = rad(angle)
  return cos(radians) * radius, sin(radians) * radius
end

-- Degrees in [0, 360).
function MinimapButton.AngleFor(dx, dy)
  return deg(atan2(dy, dx)) % FULL_CIRCLE
end

local function place()
  local minimap = _G.Minimap
  local radius = minimap:GetWidth() / 2 + RING_OFFSET
  local x, y = MinimapButton.OffsetFor(db.minimapAngle or DEFAULT_ANGLE, radius)
  button:ClearAllPoints()
  button:SetPoint("CENTER", minimap, "CENTER", x, y)
end

-- Never set the action as the script: it would be handed the frame.
local function onClick(_self, mouseButton)
  if mouseButton == "RightButton" then
    actions.onOptions()
  else
    actions.onPreview()
  end
end

-- GetCursorPosition is in unscaled screen pixels and GetCenter in the
-- minimap's own scale, so the cursor is divided by the minimap's effective
-- scale. GetCenter can return nothing; that frame is skipped.
local function followCursor()
  local minimap = _G.Minimap
  local centerX, centerY = minimap:GetCenter()
  if not centerX then
    return
  end
  local scale = minimap:GetEffectiveScale()
  local cursorX, cursorY = _G.GetCursorPosition()
  db.minimapAngle = MinimapButton.AngleFor(cursorX / scale - centerX, cursorY / scale - centerY)
  place()
end

local function onDragStart(self)
  self:SetScript("OnUpdate", followCursor)
end

local function onDragStop(self)
  self:SetScript("OnUpdate", nil)
  followCursor()
end

local function onEnter(self)
  local tooltip = _G.GameTooltip
  tooltip:SetOwner(self, "ANCHOR_LEFT")
  tooltip:SetText(Text("Level Up Info"))
  tooltip:AddLine(Text("Left-click: preview"), 1, 1, 1)
  tooltip:AddLine(Text("Right-click: options"), 1, 1, 1)
  tooltip:Show()
end

local function onLeave()
  _G.GameTooltip:Hide()
end

local function addTexture(layer, path, size, x, y)
  local texture = button:CreateTexture(nil, layer)
  texture:SetTexture(path)
  texture:SetSize(size, size)
  texture:SetPoint("TOPLEFT", button, "TOPLEFT", x, y)
end

local function build()
  button = _G.CreateFrame("Button", BUTTON_NAME, _G.Minimap)
  button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  button:SetFrameStrata(STRATA)
  button:SetFixedFrameStrata(true)
  button:SetFrameLevel(FRAME_LEVEL)
  button:SetFixedFrameLevel(true)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  addTexture("BACKGROUND", BACKGROUND_TEXTURE, BACKGROUND_SIZE, TEXTURE_X, BACKGROUND_Y)
  addTexture("ARTWORK", ICON_TEXTURE, ICON_SIZE, TEXTURE_X, ICON_Y)
  addTexture("OVERLAY", BORDER_TEXTURE, BORDER_SIZE, 0, 0)
  button:SetHighlightTexture(HIGHLIGHT_TEXTURE)
  button:SetScript("OnClick", onClick)
  button:SetScript("OnDragStart", onDragStart)
  button:SetScript("OnDragStop", onDragStop)
  button:SetScript("OnEnter", onEnter)
  button:SetScript("OnLeave", onLeave)
  place()
end

-- Shows the button when the setting is on (building it the first time), hides it when off.
function MinimapButton.Apply()
  if not db.minimapButton then
    if button then
      button:Hide()
    end
    return
  end
  if not button then
    build()
  end
  button:Show()
end

-- actions = { onPreview = fn, onOptions = fn }. Creates nothing while the setting is off.
function MinimapButton.Install(savedDB, buttonActions)
  db = savedDB
  actions = buttonActions
  MinimapButton.Apply()
end

ns.MinimapButton = MinimapButton
return MinimapButton
