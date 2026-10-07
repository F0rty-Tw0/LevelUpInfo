local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Trainer = require("tests.helpers.trainer")

local FILES = { "Core/Events.lua", "Data/TrainerCache.lua", "Data/TrainerScan.lua" }

-- Classic lists a header per school, between the spells.
local function classicServices()
  return {
    { name = "Holy", type = "header" },
    { name = "Smite", type = "available", level = 6, cost = 100, spellID = 591, rank = "Rank 2" },
    { name = "Shadow", type = "header" },
    { name = "Shadow Word: Pain", type = "unavailable", level = 10, cost = 200, spellID = 594, rank = "Rank 2" },
    { name = "Mystery", type = "available", level = 6, cost = 50 },
  }
end

-- Fresh fake Classic client, trainer and addon modules per test; returns the event frame too.
local function setup(opts)
  opts = opts or {}
  opts.services = opts.services or classicServices()
  local W = Wow.Install()
  Trainer.InstallClassic(W, opts)
  local ns = {}
  for _, file in ipairs(FILES) do
    assert(loadfile(file))("LevelUpInfo", ns)
  end
  local db = { trainers = {} }
  ns.TrainerScan.Install(db)
  return W, db, ns.Events.frame
end

local function showTrainer(W, frame)
  W.fireEvent(frame, "TRAINER_SHOW")
end

local function levels(db)
  return db.trainers.PRIEST and db.trainers.PRIEST.levels or {}
end

local function tooltipCount(W)
  local count = 0
  for _, frame in ipairs(W.frames) do
    if W.state(frame).frameType == "GameTooltip" then
      count = count + 1
    end
  end
  return count
end

local function test_classic_scan_records_spell_level_cost_and_rank()
  local W, db, frame = setup()
  showTrainer(W, frame)
  local entry = levels(db)[6][591]
  Assert.equal(entry.cost, 100)
  Assert.equal(entry.rank, "Rank 2")
  Assert.equal(levels(db)[10][594].rank, "Rank 2")
end

local function test_classic_scan_never_sets_a_header_row()
  local W, _, frame = setup()
  showTrainer(W, frame)
  Assert.equal(table.concat(Trainer.tooltipRows, ","), "2,4,5")
  Assert.equal(#W.errors, 0)
end

local function test_classic_tooltip_is_created_once_across_two_scans()
  local W, _, frame = setup()
  showTrainer(W, frame)
  showTrainer(W, frame)
  Assert.equal(tooltipCount(W), 1)
end

local function test_classic_row_without_spell_id_is_not_recorded()
  local W, db, frame = setup()
  showTrainer(W, frame)
  local count = 0
  for _ in pairs(levels(db)[6]) do
    count = count + 1
  end
  Assert.equal(count, 1)
end

local function test_classic_class_trainer_scans_without_trainer_type()
  local W, db, frame = setup({ tradeskill = false })
  showTrainer(W, frame)
  Assert.equal(levels(db)[6] ~= nil, true)
end

local function test_classic_tradeskill_trainer_is_ignored()
  local W, db, frame = setup({ tradeskill = true })
  showTrainer(W, frame)
  Assert.equal(next(levels(db)), nil)
  Assert.equal(tooltipCount(W), 0)
end

return function()
  test_classic_scan_records_spell_level_cost_and_rank()
  test_classic_scan_never_sets_a_header_row()
  test_classic_tooltip_is_created_once_across_two_scans()
  test_classic_row_without_spell_id_is_not_recorded()
  test_classic_class_trainer_scans_without_trainer_type()
  test_classic_tradeskill_trainer_is_ignored()
end
