local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")

local Text = Localization.Text

-- Ordered as the options panel shows them.
local Defaults = {
  list = {
    { key = "enabled", kind = "checkbox", label = Text("Enabled"), default = true },
    { key = "duration", kind = "slider", label = Text("Duration"), default = 10, min = 3, max = 30, step = 1 },
    { key = "waitForCombat", kind = "checkbox", label = Text("Wait for combat to end"), default = true },
    { key = "scale", kind = "slider", label = Text("Scale"), default = 1.0, min = 0.5, max = 1.5, step = 0.05 },
    { key = "reducedMotion", kind = "checkbox", label = Text("Reduced motion"), default = false },
  },
  byKey = {},
}

for _, setting in ipairs(Defaults.list) do
  Defaults.byKey[setting.key] = setting
end

ns.SettingsDefaults = Defaults
return Defaults
