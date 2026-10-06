local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local ns
local Window
local db

local LOAD_EVENT = "SPELL_DATA_LOAD_RESULT"
local RANK_1 = 589
local RANK_2 = 594
local RENEW_1 = 139
local RENEW_2 = 6074
local UNUSED_SPELL = 9999
local MISSED_LEVEL = 5
local MISSED_BASE = 1000
local MISSED_COUNT = 8
local OLD_TEXT = "Deals 30 Shadow damage over 18 sec."
local NEW_TEXT = "Deals 66 Shadow damage over 18 sec."
local RENEW_TEXT = "Heals 100 over 15 sec."
local LINE_HEIGHT = 12
local ROW_HEIGHT = 47
local WHEEL_STEP = 47

local function mana(cost)
  return { { cost = cost, name = "MANA" } }
end

local function cacheSpell(level, spellID, rank)
  db.trainers.PRIEST.levels[level] = db.trainers.PRIEST.levels[level] or {}
  db.trainers.PRIEST.levels[level][spellID] = { cost = 50, rank = rank, races = { Scourge = true } }
end

-- Fresh fake client, modules and db per test. Priest cache: Shadow Word: Pain
-- Rank 1 (level 4, known) and Rank 2 (level 10, text not loaded yet), plus
-- eight "Missed n" at level 5, so Not yet learned can expand.
local function setup()
  W = Wow.Install()
  W.money = 1000
  db = {
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
    trainers = { PRIEST = { covered = { Scourge = 10 }, levels = {} } },
  }
  W.spells[RANK_1] = { name = "Shadow Word: Pain", iconID = 1, description = OLD_TEXT, costs = mana(25) }
  W.spells[RANK_2] = { name = "Shadow Word: Pain", iconID = 1, description = "", costs = mana(50) }
  W.known[RANK_1] = true
  cacheSpell(4, RANK_1, "Rank 1")
  cacheSpell(10, RANK_2, "Rank 2")
  for index = 1, MISSED_COUNT do
    W.spells[MISSED_BASE + index] = { name = "Missed " .. index, iconID = 1 }
    cacheSpell(MISSED_LEVEL, MISSED_BASE + index, "Rank 1")
  end
  ns = { OtherSources = {} }
  for _, file in ipairs({
    "Core/Localization.lua",
    "Core/Events.lua",
    "Data/TrainerCache.lua",
    "Data/SkillList.lua",
    "Data/RankChanges.lua",
    "Data/SpellFacts.lua",
    "UI/AutoHide.lua",
    "UI/SkillRow.lua",
    "UI/SkillGroup.lua",
    "UI/Layout.lua",
    "UI/GainLines.lua",
  }) do
    assert(loadfile(file))("LevelUpInfo", ns)
  end
  Window = assert(loadfile("UI/Window.lua"))("LevelUpInfo", ns)
  Window.Install(db)
  ns.SpellFacts.Install(Window.Refresh)
end

-- Renew Rank 1 (known) and Rank 2 (text not loaded yet) at `level`: 10 makes
-- a second New ranks row, 6 the 9th Not yet learned row (past the cap).
local function addRenew(level)
  W.spells[RENEW_1] = { name = "Renew", iconID = 2, description = "Heals 45 over 15 sec.", costs = mana(30) }
  W.spells[RENEW_2] = { name = "Renew", iconID = 2, description = "", costs = mana(60) }
  W.known[RENEW_1] = true
  cacheSpell(3, RENEW_1, "Rank 1")
  cacheSpell(level, RENEW_2, "Rank 2")
end

local function record()
  return { fromLevel = 9, toLevel = 10, gains = { health = 15 }, before = { health = 100 } }
end

local function frame()
  return _G.LevelUpInfoFrame
end

local function allRows()
  local rows = {}
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "Button" and widget.name and widget:IsShown() then
      rows[#rows + 1] = widget
    end
  end
  return rows
end

local function rowNamed(name)
  for _, row in ipairs(allRows()) do
    if row.name:GetText() == name then
      return row
    end
  end
end

local function shownLines(row)
  local count = 0
  for _, line in ipairs(row.changeLines) do
    if line:IsShown() then
      count = count + 1
    end
  end
  return count
end

-- The shown toggle (a Button without a name) whose label contains `text`.
local function toggle(text)
  for _, widget in ipairs(W.frames) do
    local label = widget.label
    if W.state(widget).frameType == "Button" and not widget.name and label and widget:IsShown() then
      if string.find(label:GetText() or "", text, 1, true) then
        return widget
      end
    end
  end
end

local function shownBoxes()
  local count = 0
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "ScrollFrame" and widget:IsShown() then
      count = count + 1
    end
  end
  return count
end

local function click(button)
  W.fireScript(button, "OnClick")
end

local function loadText(spellID, text)
  W.spells[spellID].description = text
  W.broadcast(LOAD_EVENT, spellID, true)
end

local function pointY(region)
  return select(5, region:GetPoint())
end

-- Counts frame:SetSize calls from now on; returns a reader.
local function countSetSize()
  local count = 0
  local setSize = frame().SetSize
  frame().SetSize = function(...)
    count = count + 1
    return setSize(...)
  end
  return function()
    return count
  end
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

local function test_result_recomputes_only_matching_rows()
  setup()
  addRenew(10)
  Window.Show(record())
  local changes = 0
  local readChanges = ns.SpellFacts.Changes
  ns.SpellFacts.Changes = function(...)
    changes = changes + 1
    return readChanges(...)
  end
  local builds = 0
  local build = ns.SkillList.Build
  ns.SkillList.Build = function(...)
    builds = builds + 1
    return build(...)
  end
  loadText(RANK_2, NEW_TEXT)
  Assert.equal(changes, 1)
  Assert.equal(builds, 0)
  Assert.equal(shownLines(rowNamed("Shadow Word: Pain")), 2)
end

local function test_rows_below_grown_row_move_down()
  setup()
  Window.Show(record())
  local before = pointY(rowNamed("Missed 1"))
  Assert.equal(rowNamed("Shadow Word: Pain"):GetHeight(), ROW_HEIGHT)
  loadText(RANK_2, NEW_TEXT)
  Assert.equal(rowNamed("Shadow Word: Pain"):GetHeight(), ROW_HEIGHT + LINE_HEIGHT)
  Assert.equal(pointY(rowNamed("Missed 1")), before - LINE_HEIGHT)
end

local function test_unmatched_result_runs_no_layout()
  setup()
  Window.Show(record())
  local reported = captureErrors()
  local setSizeCalls = countSetSize()
  Window.Refresh(UNUSED_SPELL)
  Assert.equal(setSizeCalls(), 0)
  Assert.equal(reported(), nil)
end

local function test_refresh_nil_does_full_fill()
  setup()
  Window.Show(record())
  local moneyCalls = W.calls.GetMoney
  Window.Refresh()
  Assert.equal(W.calls.GetMoney, moneyCalls + 1)
end

local function test_collapsed_away_result_is_ignored()
  setup()
  addRenew(6)
  Window.Show(record())
  click(toggle("not yet learned"))
  Assert.equal(rowNamed("Renew") ~= nil, true)
  click(toggle("Show less"))
  Assert.equal(rowNamed("Renew"), nil)
  local reported = captureErrors()
  local setSizeCalls = countSetSize()
  loadText(RENEW_2, RENEW_TEXT)
  Assert.equal(setSizeCalls(), 0)
  Assert.equal(reported(), nil)
end

local function test_targeted_refresh_keeps_scroll()
  setup()
  addRenew(6)
  Window.Show(record())
  click(toggle("not yet learned"))
  local box = rowNamed("Missed 1"):GetParent():GetParent()
  W.fireScript(box, "OnMouseWheel", -1)
  Assert.equal(box:GetVerticalScroll(), WHEEL_STEP)
  loadText(RENEW_2, RENEW_TEXT)
  Assert.equal(shownLines(rowNamed("Renew")), 2)
  Assert.equal(box:GetVerticalScroll(), WHEEL_STEP)
end

local function test_error_sets_stale_and_next_result_does_full_fill()
  setup()
  addRenew(6)
  Window.Show(record())
  click(toggle("not yet learned"))
  local reported = captureErrors()
  W.def("GetMoney", function()
    error("boom")
  end)
  Window.Refresh()
  Assert.equal(string.find(tostring(reported()), "boom", 1, true) ~= nil, true)
  local moneyCalls = W.calls.GetMoney
  loadText(RENEW_2, RENEW_TEXT)
  Assert.equal(W.calls.GetMoney, moneyCalls + 1)
  Assert.equal(toggle("Show less"), nil)
  Assert.equal(toggle("more"), nil)
  Assert.equal(shownBoxes(), 0)
  Assert.equal(#allRows(), 0)
  W.def("GetMoney", function()
    return W.money
  end)
  Window.Refresh()
  Assert.equal(shownBoxes(), 1)
  Assert.equal(toggle("Show less") ~= nil, true)
end

return function()
  test_result_recomputes_only_matching_rows()
  test_rows_below_grown_row_move_down()
  test_unmatched_result_runs_no_layout()
  test_refresh_nil_does_full_fill()
  test_collapsed_away_result_is_ignored()
  test_targeted_refresh_keeps_scroll()
  test_error_sets_stale_and_next_result_does_full_fill()
end
