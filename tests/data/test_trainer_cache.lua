local Assert = require("tests.helpers.assert")
local TrainerCache = require("LevelUpInfo.Data.TrainerCache")

local function test_record_creates_class_and_level_tables()
  local t = {}
  TrainerCache.Record(t, "PRIEST", "Scourge", 10, 8092, 300, "Rank 1")
  local entry = t.PRIEST.levels[10][8092]
  Assert.equal(entry.races.Scourge, true)
  Assert.equal(entry.cost, 300)
  Assert.equal(entry.rank, "Rank 1")
  Assert.equal(next(t.PRIEST.covered), nil)
end

local function test_second_race_adds_its_tag_and_latest_price_wins()
  local t = {}
  TrainerCache.Record(t, "PRIEST", "Scourge", 10, 8092, 300, "Rank 1")
  TrainerCache.Record(t, "PRIEST", "Dwarf", 10, 8092, 285, "Rank 1")
  local entry = t.PRIEST.levels[10][8092]
  Assert.equal(entry.races.Scourge, true)
  Assert.equal(entry.races.Dwarf, true)
  Assert.equal(entry.cost, 285)
end

local function test_latest_rank_text_wins()
  local t = {}
  TrainerCache.Record(t, "PRIEST", "Scourge", 10, 8092, 300, "Rank 1")
  TrainerCache.Record(t, "PRIEST", "Scourge", 10, 8092, 300, "")
  Assert.equal(t.PRIEST.levels[10][8092].rank, "")
end

local function test_cover_only_grows()
  local t = {}
  TrainerCache.Cover(t, "PRIEST", "Scourge", 12)
  TrainerCache.Cover(t, "PRIEST", "Scourge", 8)
  Assert.equal(TrainerCache.Covered(t, "PRIEST", "Scourge"), 12)
  TrainerCache.Cover(t, "PRIEST", "Scourge", 14)
  Assert.equal(TrainerCache.Covered(t, "PRIEST", "Scourge"), 14)
end

local function test_cover_keeps_races_apart()
  local t = {}
  TrainerCache.Cover(t, "PRIEST", "Scourge", 12)
  TrainerCache.Cover(t, "PRIEST", "Dwarf", 20)
  Assert.equal(TrainerCache.Covered(t, "PRIEST", "Scourge"), 12)
  Assert.equal(TrainerCache.Covered(t, "PRIEST", "Dwarf"), 20)
end

local function test_covered_of_unknown_class_or_race_is_zero()
  local t = {}
  Assert.equal(TrainerCache.Covered(t, "MAGE", "Human"), 0)
  TrainerCache.Cover(t, "PRIEST", "Scourge", 12)
  Assert.equal(TrainerCache.Covered(t, "PRIEST", "Dwarf"), 0)
end

return function()
  test_record_creates_class_and_level_tables()
  test_second_race_adds_its_tag_and_latest_price_wins()
  test_latest_rank_text_wins()
  test_cover_only_grows()
  test_cover_keeps_races_apart()
  test_covered_of_unknown_class_or_race_is_zero()
end
