-- The refill after an eye click: a group shrunk to its cap.
local Assert = require("tests.helpers.assert")
local WindowHelper = require("tests.helpers.window")

local W
local ns
local Window
local db
local charDB

local rowNamed = WindowHelper.rowNamed
local toggle = WindowHelper.toggle
local click = WindowHelper.click
local shownBoxes = WindowHelper.shownBoxes

local CAP = 4 -- SkillFill GROUP_CAP
local MISSED_LEVEL = 5
local MISSED_BASE = 1000

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

return function()
  test_a_group_shrunk_to_its_cap_drops_its_box()
  test_a_group_shrunk_to_its_cap_drops_show_less()
  test_a_shrunk_group_comes_back_collapsed()
end
