local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = {
  ADDON_NAME = "LevelUpInfo",
  VERSION = "v0.1.1",
}

ns.Constants = Constants
return Constants
