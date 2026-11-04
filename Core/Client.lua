local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Which client's game rules (spells, weapon masters, class rules) apply.
-- API differences are still detected per feature where they are used;
-- WOW_PROJECT_ID is never read.
local Client = {}

local FIRST_TBC_EXPANSION_LEVEL = 1

-- "forever", "tbc" or "era", read live on every call.
function Client.Get()
  -- Forever has C_TooltipInfo.GetTrainerService; Classic Era and TBC do not.
  local tooltipInfo = _G.C_TooltipInfo
  if tooltipInfo ~= nil and tooltipInfo.GetTrainerService ~= nil then
    return "forever"
  end
  local getLevel = _G.GetClassicExpansionLevel
  local level = getLevel and getLevel()
  if type(level) == "number" and level >= FIRST_TBC_EXPANSION_LEVEL then
    return "tbc"
  end
  return "era"
end

ns.Client = Client
return Client
