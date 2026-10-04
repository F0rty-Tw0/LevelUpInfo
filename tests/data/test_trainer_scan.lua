local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Trainer = require("tests.helpers.trainer")

local FILES = { "Core/Events.lua", "Data/TrainerCache.lua", "Data/TrainerScan.lua" }

local function priestServices()
  return {
    { name = "Smite", type = "used", level = 1, cost = 10, spellID = 585, rank = "Rank 1" },
    { name = "Renew", type = "available", level = 8, cost = 100, spellID = 139, rank = "Rank 1" },
    { name = "Mind Blast", type = "unavailable", level = 10, cost = 300, spellID = 8092, rank = "Rank 1" },
  }
end

local function filtersOff()
  return { available = false, unavailable = false, used = false }
end

-- Fresh fake client, trainer and addon modules per test; returns the event frame too.
local function setup(opts)
  opts = opts or {}
  opts.services = opts.services or priestServices()
  opts.filters = opts.filters or filtersOff()
  local W = Wow.Install()
  Trainer.Install(W, opts)
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

local function covered(db)
  return db.trainers.PRIEST and db.trainers.PRIEST.covered.Scourge
end

local function filterState()
  local parts = {}
  for _, serviceType in ipairs({ "available", "unavailable", "used" }) do
    parts[#parts + 1] = tostring(_G.GetTrainerServiceTypeFilter(serviceType))
  end
  return table.concat(parts, ",")
end

local function test_scan_records_all_three_types_with_filters_off()
  local W, db, frame = setup()
  showTrainer(W, frame)
  local entry = levels(db)[8][139]
  Assert.equal(levels(db)[1][585] ~= nil, true)
  Assert.equal(levels(db)[10][8092] ~= nil, true)
  Assert.equal(entry.cost, 100)
  Assert.equal(entry.rank, "Rank 1")
  Assert.equal(entry.races.Scourge, true)
  Assert.equal(covered(db), 10)
end

local function test_player_filters_end_as_they_were()
  local W, _, frame = setup()
  showTrainer(W, frame)
  Assert.equal(filterState(), "false,false,false")
end

local function test_filters_already_on_are_never_touched()
  local W, db, frame = setup({ filters = { available = true, unavailable = true, used = true } })
  showTrainer(W, frame)
  Assert.equal(W.calls.SetTrainerServiceTypeFilter, nil)
  Assert.equal(covered(db), 10)
end

local function test_scan_toggles_never_reenter_the_scan()
  local W, _, frame = setup()
  showTrainer(W, frame)
  Assert.equal(W.calls.SetTrainerServiceTypeFilter, 6)
  Assert.equal(W.calls.GetNumTrainerServices, 1)
end

local function test_header_profession_and_zero_level_rows_are_skipped()
  local W, db, frame = setup({
    services = {
      { name = "Holy", type = "header", level = 5, spellID = 1 },
      { name = "First Aid", type = "available", level = 5, isProfession = true, spellID = 2 },
      { name = "Odd", type = "available", level = 0, spellID = 3 },
      { name = "Renew", type = "available", level = 8, cost = 100, spellID = 139, rank = "" },
    },
  })
  showTrainer(W, frame)
  Assert.equal(levels(db)[5], nil)
  Assert.equal(levels(db)[0], nil)
  Assert.equal(levels(db)[8][139].rank, "")
end

local function test_no_spell_tooltip_data_skips_the_row()
  local W, db, frame = setup({
    services = {
      { name = "Mystery", type = "available", level = 6, cost = 50 },
      { name = "Renew", type = "available", level = 8, cost = 100, spellID = 139 },
    },
  })
  showTrainer(W, frame)
  Assert.equal(levels(db)[6], nil)
  Assert.equal(levels(db)[8][139] ~= nil, true)
end

local function test_non_class_trainer_is_ignored()
  for _, opts in ipairs({ { trainerType = 2 }, { tradeskill = true } }) do
    local W, db, frame = setup(opts)
    showTrainer(W, frame)
    Assert.equal(next(db.trainers), nil)
    Assert.equal(frame:IsEventRegistered("TRAINER_UPDATE"), false)
    Assert.equal(W.calls.SetTrainerServiceTypeFilter, nil)
  end
end

local function test_refused_filter_change_records_rows_but_not_coverage()
  local W, db, frame = setup()
  Trainer.refuse("used")
  showTrainer(W, frame)
  Assert.equal(levels(db)[8][139] ~= nil, true)
  Assert.equal(levels(db)[1], nil)
  Assert.equal(covered(db), nil)
  Assert.equal(filterState(), "false,false,false")
end

local function test_scan_with_no_kept_rows_leaves_coverage_alone()
  local W, db, frame = setup({ services = { { name = "Holy", type = "header" } } })
  showTrainer(W, frame)
  Assert.equal(next(db.trainers), nil)
  Assert.equal(#W.errors, 0)
end

local function test_scan_creates_no_frames()
  local W, _, frame = setup()
  local before = #W.frames
  showTrainer(W, frame)
  W.fireEvent(frame, "TRAINER_UPDATE")
  Assert.equal(#W.frames, before)
end

local function test_failed_scan_restores_filters_reports_error_and_skips_coverage()
  local W, db, frame = setup()
  Trainer.failOn(2)
  showTrainer(W, frame)
  Assert.equal(filterState(), "false,false,false")
  Assert.equal(#W.errors, 1)
  Assert.contains(W.errors[1], "trainer row 2 failed")
  Assert.contains(W.errors[1], "stack")
  Assert.equal(covered(db), nil)
  Assert.equal(levels(db)[1][585] ~= nil, true)
end

local function test_next_update_after_a_failed_scan_scans_again()
  local W, db, frame = setup()
  Trainer.failOn(2)
  showTrainer(W, frame)
  Trainer.failOn(nil)
  W.fireEvent(frame, "TRAINER_UPDATE")
  Assert.equal(levels(db)[8][139] ~= nil, true)
  Assert.equal(covered(db), 10)
end

local function test_blizzard_update_after_buying_rescans()
  local services = priestServices()
  local W, db, frame = setup({ services = services })
  showTrainer(W, frame)
  services[#services + 1] = { name = "Fade", type = "unavailable", level = 12, cost = 400, spellID = 586, rank = "Rank 1" }
  W.fireEvent(frame, "TRAINER_UPDATE")
  Assert.equal(levels(db)[12][586] ~= nil, true)
  Assert.equal(covered(db), 12)
end

local function test_trainer_closed_unregisters_update_and_closed()
  local W, _, frame = setup()
  showTrainer(W, frame)
  Assert.equal(frame:IsEventRegistered("TRAINER_UPDATE"), true)
  W.fireEvent(frame, "TRAINER_CLOSED")
  Assert.equal(frame:IsEventRegistered("TRAINER_UPDATE"), false)
  Assert.equal(frame:IsEventRegistered("TRAINER_CLOSED"), false)
  Assert.equal(frame:IsEventRegistered("TRAINER_SHOW"), true)
end

local function test_scan_writes_no_trainer_frame_fields()
  local W, _, frame = setup()
  local trainerFrame = { selectedService = 2, scrollOffset = 0 }
  rawset(_G, "ClassTrainerFrame", trainerFrame)
  local before = W.snapshot(trainerFrame)
  showTrainer(W, frame)
  Assert.equal(W.changedKeys(trainerFrame, before), "")
end

return function()
  test_scan_records_all_three_types_with_filters_off()
  test_player_filters_end_as_they_were()
  test_filters_already_on_are_never_touched()
  test_scan_toggles_never_reenter_the_scan()
  test_header_profession_and_zero_level_rows_are_skipped()
  test_no_spell_tooltip_data_skips_the_row()
  test_non_class_trainer_is_ignored()
  test_refused_filter_change_records_rows_but_not_coverage()
  test_scan_with_no_kept_rows_leaves_coverage_alone()
  test_scan_creates_no_frames()
  test_failed_scan_restores_filters_reports_error_and_skips_coverage()
  test_next_update_after_a_failed_scan_scans_again()
  test_blizzard_update_after_buying_rescans()
  test_trainer_closed_unregisters_update_and_closed()
  test_scan_writes_no_trainer_frame_fields()
end
