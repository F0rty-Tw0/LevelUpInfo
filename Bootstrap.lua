local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Events = ns.Events or require("LevelUpInfo.Core.Events")
local SavedState = ns.SavedState or require("LevelUpInfo.Settings.SavedState")
local TrainerScan = ns.TrainerScan or require("LevelUpInfo.Data.TrainerScan")
local Window = ns.Window or require("LevelUpInfo.UI.Window")
local LevelUp = ns.LevelUp or require("LevelUpInfo.Core.LevelUp")
local Panel = ns.SettingsPanel or require("LevelUpInfo.Settings.Panel")
local SlashCommand = ns.SlashCommand or require("LevelUpInfo.Core.SlashCommand")

local Bootstrap = {}

-- Normalizes the saved variables and wires every module to the result.
function Bootstrap.Initialize(saved)
  local db = SavedState.Initialize(saved)
  _G.LevelUpInfoDB = db
  TrainerScan.Install(db)
  Window.Install(db)
  LevelUp.Install(db)
  Panel.Register(db, { onScale = Window.ApplyScale, onResetPosition = Window.ResetPosition })
  SlashCommand.Register(Panel.Open, LevelUp.ShowTest)
  return db
end

local ADDON_NAME = addonName or "LevelUpInfo"

Events.On("ADDON_LOADED", function(loadedName)
  if loadedName ~= ADDON_NAME then
    return
  end
  Events.Off("ADDON_LOADED")
  Bootstrap.Initialize(_G.LevelUpInfoDB)
end)

ns.Bootstrap = Bootstrap
return Bootstrap
