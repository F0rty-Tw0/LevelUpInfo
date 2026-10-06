local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local ns
local Window
local db

local LOAD_EVENT = "SPELL_DATA_LOAD_RESULT"
local RANK_1 = 589
local RANK_2 = 594
local OLD_TEXT = "Deals 30 Shadow damage over 18 sec."
local NEW_TEXT = "Deals 66 Shadow damage over 18 sec."

local function mana(cost)
  return { { cost = cost, name = "MANA" } }
end

local function cacheSpell(level, spellID, rank)
  db.trainers.PRIEST.levels[level] = db.trainers.PRIEST.levels[level] or {}
  db.trainers.PRIEST.levels[level][spellID] = { cost = 50, rank = rank, races = { Scourge = true } }
end

-- Fresh fake client, modules and db per test. Priest cache: Shadow Word: Pain
-- Rank 1 (level 4, known) and Rank 2 (level 10); the facts differ in damage and cost.
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
  W.spells[RANK_2] = { name = "Shadow Word: Pain", iconID = 1, description = NEW_TEXT, costs = mana(50) }
  W.known[RANK_1] = true
  cacheSpell(4, RANK_1, "Rank 1")
  cacheSpell(10, RANK_2, "Rank 2")
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
  }) do
    assert(loadfile(file))("LevelUpInfo", ns)
  end
  Window = assert(loadfile("UI/Window.lua"))("LevelUpInfo", ns)
  Window.Install(db)
  ns.SpellFacts.Install(Window.Refresh)
end

local function record(fromLevel, toLevel)
  return { fromLevel = fromLevel or 9, toLevel = toLevel or 10, gains = { health = 15 }, before = { health = 100 } }
end

local function frame()
  return _G.LevelUpInfoFrame
end

local function shownRows()
  local rows = {}
  for _, widget in ipairs(W.frames) do
    local stub = W.state(widget)
    if stub.frameType == "Button" and widget.changeLines and widget:IsShown() then
      rows[#rows + 1] = widget
    end
  end
  return rows
end

local function rowNamed(name)
  for _, row in ipairs(shownRows()) do
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

local function rankLines()
  return shownLines(rowNamed("Shadow Word: Pain"))
end

local function loadText(spellID, text)
  W.spells[spellID].description = text
  W.broadcast(LOAD_EVENT, spellID, true)
end

local function test_rank_row_shows_lines_and_frame_grows()
  setup()
  W.spells[RANK_2].description = OLD_TEXT
  W.spells[RANK_2].costs = mana(25)
  Window.Show(record())
  Assert.equal(rankLines(), 0)
  local baseline = frame():GetHeight()
  setup()
  Window.Show(record())
  Assert.equal(rankLines(), 2)
  Assert.equal(frame():GetHeight(), baseline + 12)
end

local function test_unloaded_then_result_fills_lines()
  setup()
  W.spells[RANK_1].description = ""
  W.spells[RANK_2].description = ""
  Window.Show(record())
  Assert.equal(rankLines(), 0)
  local frames = W.calls.CreateFrame
  local timers = W.liveTimers
  loadText(RANK_1, OLD_TEXT)
  Assert.equal(rankLines(), 0)
  loadText(RANK_2, NEW_TEXT)
  Assert.equal(rankLines(), 2)
  Assert.equal(W.calls.CreateFrame, frames)
  Assert.equal(W.liveTimers, timers)
end

local function test_result_after_new_show_refills_new_record()
  setup()
  W.spells[RANK_2].description = ""
  Window.Show(record())
  W.spells[139] = { name = "Renew", iconID = 2, description = "Heals 45 over 15 sec." }
  W.spells[6074] = { name = "Renew", iconID = 2, description = "" }
  W.known[139] = true
  W.known[RANK_2] = true
  cacheSpell(8, 139, "Rank 1")
  cacheSpell(12, 6074, "Rank 2")
  db.trainers.PRIEST.covered.Scourge = 12
  Window.Show(record(11, 12))
  Assert.equal(shownLines(rowNamed("Renew")), 0)
  loadText(6074, "Heals 100 over 15 sec.")
  Assert.equal(W.state(frame()).title, "Level 12")
  Assert.equal(shownLines(rowNamed("Renew")), 1)
end

local function test_old_record_result_refills_new_record()
  setup()
  W.spells[RANK_2].description = ""
  Window.Show(record())
  W.spells[139] = { name = "Renew", iconID = 2, description = "Heals 45 over 15 sec." }
  W.spells[6074] = { name = "Renew", iconID = 2, description = "Heals 100 over 15 sec." }
  W.known[139] = true
  W.known[RANK_2] = true
  cacheSpell(8, 139, "Rank 1")
  cacheSpell(12, 6074, "Rank 2")
  db.trainers.PRIEST.covered.Scourge = 12
  Window.Show(record(11, 12))
  loadText(RANK_2, NEW_TEXT)
  Assert.equal(W.state(frame()).title, "Level 12")
  Assert.equal(#shownRows(), 1)
  Assert.equal(shownLines(rowNamed("Renew")), 1)
end

local function test_refresh_reuses_skill_list()
  setup()
  W.spells[RANK_2].description = ""
  Window.Show(record())
  local builds = 0
  local build = ns.SkillList.Build
  ns.SkillList.Build = function(...)
    builds = builds + 1
    return build(...)
  end
  loadText(RANK_2, NEW_TEXT)
  Assert.equal(rankLines(), 2)
  Assert.equal(builds, 0)
end

local function test_refresh_while_hidden_does_nothing()
  setup()
  Window.Refresh()
  Assert.equal(Window.Frame(), nil)
  Window.Show(record())
  frame():Hide()
  local frames = W.calls.CreateFrame
  local title = W.state(frame()).title
  Window.Refresh()
  Assert.equal(W.calls.CreateFrame, frames)
  Assert.equal(W.state(frame()).title, title)
end

local function test_refresh_during_fill_ignored()
  setup()
  db.trainers.PRIEST.covered.Scourge = 9
  Window.Show(record())
  Assert.equal(#shownRows(), 2)
  W.spells[RANK_2].description = ""
  W.onRequestLoad = function(spellID)
    loadText(spellID, NEW_TEXT)
  end
  local frames = W.calls.CreateFrame
  Window.Show(record())
  Assert.equal(W.calls.RequestLoadSpellData, 1)
  Assert.equal(W.calls.CreateFrame, frames)
  Assert.equal(#shownRows(), 2)
  Assert.equal(rankLines(), 2)
end

local function test_fill_error_reports_and_refresh_still_works()
  setup()
  Window.Show(record())
  local reported
  W.def("geterrorhandler", function()
    return function(err)
      reported = err
    end
  end)
  W.def("debugstack", function()
    return ""
  end)
  W.def("GetMoney", function()
    error("boom")
  end)
  Window.Refresh()
  Assert.equal(string.find(tostring(reported), "boom", 1, true) ~= nil, true)
  W.def("GetMoney", function()
    return W.money
  end)
  local moneyCalls = W.calls.GetMoney
  Window.Refresh()
  Assert.equal(W.calls.GetMoney, moneyCalls + 1)
end

local function test_fill_error_hides_previous_rows()
  setup()
  Window.Show(record())
  Assert.equal(#shownRows(), 1)
  W.def("geterrorhandler", function()
    return function() end
  end)
  W.def("debugstack", function()
    return ""
  end)
  W.def("GetMoney", function()
    error("boom")
  end)
  Window.Show(record(11, 12))
  Assert.equal(#shownRows(), 0)
end

local function test_capped_rank_row_requests_nothing()
  setup()
  db.trainers.PRIEST.levels = {}
  for index = 1, 6 do
    local name = "Spell " .. index
    W.spells[100 + index] = { name = name, iconID = 1, description = "" }
    W.spells[200 + index] = { name = name, iconID = 1, description = "" }
    W.known[100 + index] = true
    cacheSpell(2, 100 + index, "Rank 1")
    cacheSpell(5, 200 + index, "Rank 2")
  end
  Window.Show(record())
  Assert.equal(#shownRows(), 5)
  Assert.equal(W.calls.RequestLoadSpellData, 10)
end

local function test_hide_unregisters_event()
  setup()
  W.spells[RANK_2].description = ""
  Window.Show(record())
  Assert.equal(ns.Events.frame:IsEventRegistered(LOAD_EVENT), true)
  frame():Hide()
  Assert.equal(ns.Events.frame:IsEventRegistered(LOAD_EVENT), false)
end

return function()
  test_rank_row_shows_lines_and_frame_grows()
  test_unloaded_then_result_fills_lines()
  test_result_after_new_show_refills_new_record()
  test_old_record_result_refills_new_record()
  test_refresh_reuses_skill_list()
  test_refresh_while_hidden_does_nothing()
  test_refresh_during_fill_ignored()
  test_fill_error_reports_and_refresh_still_works()
  test_fill_error_hides_previous_rows()
  test_capped_rank_row_requests_nothing()
  test_hide_unregisters_event()
end
