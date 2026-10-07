local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Events = ns.Events or require("LevelUpInfo.Core.Events")
local TrainerCache = ns.TrainerCache or require("LevelUpInfo.Data.TrainerCache")

local ipairs = ipairs
local select = select
local tostring = tostring
local type = type
local xpcall = xpcall

local TrainerScan = {}

local FILTER_TYPES = { "available", "unavailable", "used" }
local KEPT_TYPES = { available = true, unavailable = true, used = true }

local db
-- Set while a scan runs; also makes TRAINER_UPDATE ignore the scan's own toggles.
local scanning = false

local function errorHandler(err)
  return tostring(err) .. "\n" .. _G.debugstack()
end

-- Classic only: a plain hidden tooltip (no template, no events), built on the
-- first Classic scan. Forever has no SetTrainerService on it.
local tooltip

-- Forever has C_TooltipInfo.GetTrainerService; Classic Era and TBC do not.
local function isForever()
  return _G.C_TooltipInfo ~= nil and _G.C_TooltipInfo.GetTrainerService ~= nil
end

-- Returns serviceType, subText (rank) in either client's order.
local function serviceInfo(i, forever)
  if forever then
    local _, serviceType, _, _, subText = _G.GetTrainerServiceInfo(i)
    return serviceType, subText
  end
  local _, subText, serviceType = _G.GetTrainerServiceInfo(i)
  return serviceType, subText
end

local function tooltipSpellID(i)
  if not tooltip then
    tooltip = _G.CreateFrame("GameTooltip")
  end
  tooltip:SetOwner(_G.WorldFrame, "ANCHOR_NONE")
  tooltip:SetTrainerService(i)
  local spellID = select(2, tooltip:GetSpell())
  tooltip:Hide()
  return type(spellID) == "number" and spellID or nil
end

local function rowSpellID(i, forever)
  if not forever then
    return tooltipSpellID(i)
  end
  local data = _G.C_TooltipInfo.GetTrainerService(i)
  if data and data.type == _G.Enum.TooltipDataType.Spell and type(data.id) == "number" then
    return data.id
  end
end

-- Classic only: hunter trainers list pet-learn rows next to the player's spells.
local function isPetLearn(i)
  local isLearnSpell = _G.IsTrainerServiceLearnSpell
  return isLearnSpell ~= nil and select(2, isLearnSpell(i)) == true
end

-- Records every kept row; returns the highest kept level, or nil.
local function recordRows(class, race)
  local seen
  local forever = isForever()
  for i = 1, _G.GetNumTrainerServices() do
    local serviceType, subText = serviceInfo(i, forever)
    if KEPT_TYPES[serviceType] then
      local level = _G.GetTrainerServiceLevelReq(i)
      local cost, isProfession = _G.GetTrainerServiceCost(i)
      local spellID = type(level) == "number" and level > 0 and not isProfession and not isPetLearn(i) and rowSpellID(i, forever)
      if spellID then
        TrainerCache.Record(db.trainers, class, race, level, spellID, cost, subText or "")
        if not seen or level > seen then
          seen = level
        end
      end
    end
  end
  return seen
end

local function allFiltersOn()
  for _, serviceType in ipairs(FILTER_TYPES) do
    if not _G.GetTrainerServiceTypeFilter(serviceType) then
      return false
    end
  end
  return true
end

function TrainerScan.Scan()
  if scanning then
    return
  end
  scanning = true
  local flipped = {}
  local class, race, allOn, seen
  local ok, err = xpcall(function()
    class = select(2, _G.UnitClass("player"))
    race = select(2, _G.UnitRace("player"))
    for _, serviceType in ipairs(FILTER_TYPES) do
      if not _G.GetTrainerServiceTypeFilter(serviceType) then
        _G.SetTrainerServiceTypeFilter(serviceType, true)
        flipped[#flipped + 1] = serviceType
      end
    end
    allOn = allFiltersOn()
    seen = recordRows(class, race)
  end, errorHandler)
  for _, serviceType in ipairs(flipped) do
    _G.SetTrainerServiceTypeFilter(serviceType, false)
  end
  scanning = false
  if not ok then
    _G.geterrorhandler()(err)
  elseif allOn and seen then
    TrainerCache.Cover(db.trainers, class, race, seen)
  end
end

local function onClosed()
  Events.Off("TRAINER_UPDATE")
  Events.Off("TRAINER_CLOSED")
end

-- Classic has an empty C_Trainer; there only IsTradeskillTrainer can tell.
local function isClassTrainer()
  local trainer = _G.C_Trainer
  if trainer and trainer.GetTrainerType and trainer.GetTrainerType() ~= _G.Enum.TrainerType.General then
    return false
  end
  return not _G.IsTradeskillTrainer()
end

local function onShow()
  if not isClassTrainer() then
    return
  end
  Events.On("TRAINER_UPDATE", TrainerScan.Scan)
  Events.On("TRAINER_CLOSED", onClosed)
  TrainerScan.Scan()
end

function TrainerScan.Install(savedDB)
  db = savedDB
  Events.On("TRAINER_SHOW", onShow)
end

ns.TrainerScan = TrainerScan
return TrainerScan
