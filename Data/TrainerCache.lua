local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TrainerCache = {}

local function classData(trainers, class)
  local data = trainers[class]
  if not data then
    data = { covered = {}, levels = {} }
    trainers[class] = data
  end
  return data
end

function TrainerCache.Record(trainers, class, race, level, spellID, cost, rank)
  local levels = classData(trainers, class).levels
  local entries = levels[level]
  if not entries then
    entries = {}
    levels[level] = entries
  end
  local entry = entries[spellID]
  if not entry then
    entry = { races = {} }
    entries[spellID] = entry
  end
  entry.cost = cost
  entry.rank = rank
  entry.races[race] = true
end

function TrainerCache.Covered(trainers, class, race)
  local data = trainers[class]
  return data and data.covered[race] or 0
end

function TrainerCache.Cover(trainers, class, race, seen)
  if seen > TrainerCache.Covered(trainers, class, race) then
    classData(trainers, class).covered[race] = seen
  end
end

ns.TrainerCache = TrainerCache
return TrainerCache
