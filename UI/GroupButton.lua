local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")
local AutoHide = ns.AutoHide or require("LevelUpInfo.UI.AutoHide")

local Text = Localization.Text

local SIZE = 16
local RIGHT_OFFSET = -20 -- left of the fold icon: its 16 px plus a 4 px gap
local REST_ALPHA = 0.6
local HOVER_ALPHA = 1
local DISMISS = "Interface\\AddOns\\LevelUpInfo\\Media\\Dismiss.tga"
local RESTORE = "Interface\\AddOns\\LevelUpInfo\\Media\\Restore.tga"

-- The "Dismiss all" / "Restore all" button on a fold group's heading: a plain
-- Button (no template, no events), a child of the group's fold button, so its
-- click never reaches the fold button. Hovering it brightens it, shows a
-- tooltip and pauses the auto-hide, like a row's dismiss button.
local GroupButton = {}

GroupButton.SIZE = SIZE
GroupButton.REST_ALPHA = REST_ALPHA

local function paint(texture, isRestore)
  local color = isRestore and _G.GREEN_FONT_COLOR or _G.RED_FONT_COLOR
  texture:SetTexture(isRestore and RESTORE or DISMISS)
  texture:SetVertexColor(color:GetRGB())
end

function GroupButton.Create(foldButton, group, action, onGroupAction)
  local isRestore = action == "restore"
  local button = _G.CreateFrame("Button", nil, foldButton)
  button:SetSize(SIZE, SIZE)
  button:SetPoint("TOPRIGHT", foldButton, "TOPRIGHT", RIGHT_OFFSET, 0)
  button:SetAlpha(REST_ALPHA)
  local texture = button:CreateTexture()
  texture:SetAllPoints()
  paint(texture, isRestore)
  button:SetScript("OnClick", function()
    onGroupAction(group)
  end)
  button:SetScript("OnEnter", function()
    local tooltipText = isRestore and Text("Restore all") or Text("Dismiss all")
    _G.GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    _G.GameTooltip:SetText(tooltipText)
    _G.GameTooltip:Show()
    button:SetAlpha(HOVER_ALPHA)
    AutoHide.Pause()
  end)
  button:SetScript("OnLeave", function()
    _G.GameTooltip:Hide()
    button:SetAlpha(REST_ALPHA)
    AutoHide.Resume()
  end)

  return button
end

ns.GroupButton = GroupButton
return GroupButton
