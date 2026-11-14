-- The refill after an eye click: a group shrunk to its cap and a failed refill.
local Assert = require("tests.helpers.assert")
local WindowHelper = require("tests.helpers.window")

local W
local ns
local Window
local db
local charDB

local rowNamed = WindowHelper.rowNamed
local allRows = WindowHelper.allRows
local toggle = WindowHelper.toggle
local click = WindowHelper.click
local shownBoxes = WindowHelper.shownBoxes

local CAP = 4 -- SkillFill GROUP_CAP
local MISSED_LEVEL = 5
local MISSED_BASE = 1000
local UNUSED_SPELL = 99999

-- Fresh fake client, modules, db and character table per test. The priest cache
-- starts empty and covers level 10 (no hint row).
local function setup()
  W = WindowHelper.install()
  W.money = 1000
  db = WindowHelper.db({ PRIEST = { covered = { Scourge = 10 }, levels = {} } })
  charDB = WindowHelper.charDB()
  ns = { OtherSources = { PRIEST = {} } }
  Window = WindowHelper.load(ns)
  Window.Install(db, charDB)
  ns.SpellFacts.Install(Window.Refresh)
end

local function addMissed(count)
  local levels = db.trainers.PRIEST.levels
  levels[MISSED_LEVEL] = {}
  for index = 1, count do
    W.spells[MISSED_BASE + index] = { name = "Missed " .. index, iconID = 1 }
    levels[MISSED_LEVEL][MISSED_BASE + index] = { cost = 100, rank = "Rank 1", races = { Scourge = true } }
  end
end

local function record()
  return { fromLevel = 9, toLevel = 10, gains = { health = 15 }, before = { health = 100 } }
end

local function clickEye(name)
  W.fireScript(rowNamed(name).eye, "OnClick")
end

-- Records the last reported error; returns a reader.
local function captureErrors()
  local reported
  W.def("geterrorhandler", function()
    return function(err)
      reported = err
    end
  end)
  W.def("debugstack", function()
    return ""
  end)
  return function()
    return reported
  end
end

-- One row over the cap, expanded; the eye takes it back to the cap.
local function showExpandedThenHideOne()
  setup()
  addMissed(CAP + 1)
  Window.Show(record())
  click(toggle("more not yet learned"))
  Assert.equal(shownBoxes(), 1)
  clickEye("Missed 1")
end

local function test_a_group_shrunk_to_its_cap_drops_its_box()
  showExpandedThenHideOne()
  Assert.equal(shownBoxes(), 0)
end

local function test_a_group_shrunk_to_its_cap_drops_show_less()
  showExpandedThenHideOne()
  Assert.equal(toggle("Show less"), nil)
  Assert.equal(toggle("more not yet learned"), nil)
end

local function test_a_shrunk_group_comes_back_collapsed()
  showExpandedThenHideOne()
  Window.ShowHidden()
  Assert.equal(shownBoxes(), 0)
  Assert.equal(toggle("+1 more not yet learned") ~= nil, true)
end

-- The next-level lookup throws inside the eye click's refill: the click
-- itself does not throw, the error is reported, every row is hidden and the
-- window is stale, so the next spell result does a full fill.
local function test_a_failed_next_level_lookup_fails_the_eye_refill()
  setup()
  addMissed(2)
  Window.Show(record())
  local reported = captureErrors()
  local find = ns.NextLevel.Find
  ns.NextLevel.Find = function()
    error("boom")
  end
  Assert.equal(pcall(clickEye, "Missed 1"), true)
  Assert.equal(string.find(tostring(reported()), "boom", 1, true) ~= nil, true)
  Assert.equal(#allRows(), 0)
  ns.NextLevel.Find = find
  Window.Refresh(UNUSED_SPELL)
  Assert.equal(#allRows(), 1)
end

return function()
  test_a_group_shrunk_to_its_cap_drops_its_box()
  test_a_group_shrunk_to_its_cap_drops_show_less()
  test_a_shrunk_group_comes_back_collapsed()
  test_a_failed_next_level_lookup_fails_the_eye_refill()
end
