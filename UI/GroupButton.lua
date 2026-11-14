local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")
local AutoHide = ns.AutoHide or require("LevelUpInfo.UI.AutoHide")

local Text = Localization.Text

local SIZE = 16
local RIGHT_OFFSET = -20 -- left of the fold icon: its 16 px plus a 4 px gap
-- Hover only (user decision, 2026-11-15): invisible until its heading is
-- hovered, dim over the heading, bright over the button itself.
local HIDDEN_ALPHA = 0
local REST_ALPHA = 0.6
local HOVER_ALPHA = 1
local EYE_CROSSED = "Interface\\AddOns\\LevelUpInfo\\Media\\EyeCrossed.tga"
local EYE_OPEN = "Interface\\AddOns\\LevelUpInfo\\Media\\EyeOpen.tga"

-- The "Hide all" (crossed eye) / "Show all" (open eye) button on a fold group's
-- heading: a plain Button (no template, no events), a child of the group's fold
-- button, so its click never reaches the fold button. Hovering it brightens it,
-- shows a tooltip and pauses the auto-hide, like a row's hide button.
local GroupButton = {}

GroupButton.SIZE = SIZE
GroupButton.REST_ALPHA = REST_ALPHA
GroupButton.HIDDEN_ALPHA = HIDDEN_ALPHA

-- The alpha once the mouse left the button or the heading: dim while the mouse
-- is still inside the heading line, else invisible.
function GroupButton.RestAlpha(foldButton)
  return foldButton:IsMouseOver() and REST_ALPHA or HIDDEN_ALPHA
end

function GroupButton.Create(foldButton, group, action, onGroupAction)
  local isRestore = action == "restore"
  local button = _G.CreateFrame("Button", nil, foldButton)
  button:SetSize(SIZE, SIZE)
  button:SetPoint("TOPRIGHT", foldButton, "TOPRIGHT", RIGHT_OFFSET, 0)
  button:SetAlpha(HIDDEN_ALPHA)
  local texture = button:CreateTexture()
  texture:SetAllPoints()
  texture:SetTexture(isRestore and EYE_OPEN or EYE_CROSSED)
  button:SetScript("OnClick", function()
    onGroupAction(group)
  end)
  button:SetScript("OnEnter", function()
    local tooltipText = isRestore and Text("Show all") or Text("Hide all")
    _G.GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    _G.GameTooltip:SetText(tooltipText)
    _G.GameTooltip:Show()
    button:SetAlpha(HOVER_ALPHA)
    AutoHide.Pause()
  end)
  button:SetScript("OnLeave", function()
    _G.GameTooltip:Hide()
    button:SetAlpha(GroupButton.RestAlpha(foldButton))
    AutoHide.Resume()
  end)

  return button
end

ns.GroupButton = GroupButton
return GroupButton
