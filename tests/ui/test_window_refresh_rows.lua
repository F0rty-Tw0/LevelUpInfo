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
local FADE = 586
local MISSED_BASE = 1000
local OLD_TEXT = "Deals 30 Shadow damage over 18 sec."
local NEW_TEXT = "Deals 66 Shadow damage over 18 sec."
local RENEW_TEXT = "Heals 100 over 15 sec."
local HINT_TEXT = "Visit your class trainer to see all new skills."
local ROW_HEIGHT = 47

local function mana(cost)
  return { { cost = cost, name = "MANA" } }
end

local function cacheSpell(level, spellID, rank)
  db.trainers.PRIEST.levels[level] = db.trainers.PRIEST.levels[level] or {}
  db.trainers.PRIEST.levels[level][spellID] = { cost = 50, rank = rank, races = { Scourge = true } }
end

-- Fresh fake client, modules and db per test. Priest cache: Shadow Word: Pain
-- Rank 1 (level 4, known) and Rank 2 (level 10, text not loaded yet).
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

-- Renew Rank 1 (known) and Rank 2 (text not loaded yet) at `level`.
local function addRenew(level)
  W.spells[RENEW_1] = { name = "Renew", iconID = 2, description = "Heals 45 over 15 sec.", costs = mana(30) }
  W.spells[RENEW_2] = { name = "Renew", iconID = 2, description = "", costs = mana(60) }
  W.known[RENEW_1] = true
  cacheSpell(3, RENEW_1, "Rank 1")
  cacheSpell(level, RENEW_2, "Rank 2")
end

-- `count` "Missed n" spells at `level`, numbered from `first`.
local function addMissed(level, first, count)
  for index = first, first + count - 1 do
    W.spells[MISSED_BASE + index] = { name = "Missed " .. index, iconID = 1 }
    cacheSpell(level, MISSED_BASE + index, "Rank 1")
  end
end

local function record(fromLevel, toLevel)
  return { fromLevel = fromLevel or 9, toLevel = toLevel or 10, gains = { health = 15 }, before = { health = 100 } }
end

local function rowNamed(name)
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "Button" and widget.name and widget:IsShown() then
      if widget.name:GetText() == name then
        return widget
      end
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

local function click(button)
  W.fireScript(button, "OnClick")
end

local function loadText(spellID, text)
  W.spells[spellID].description = text
  W.broadcast(LOAD_EVENT, spellID, true)
end

-- Counts SpellFacts.Changes calls from now on; returns a reader.
local function countChanges()
  local count = 0
  local changes = ns.SpellFacts.Changes
  ns.SpellFacts.Changes = function(...)
    count = count + 1
    return changes(...)
  end
  return function()
    return count
  end
end

local function test_successful_fill_after_error_makes_next_result_targeted()
  setup()
  addRenew(10)
  Window.Show(record())
  W.def("geterrorhandler", function()
    return function() end
  end)
  W.def("debugstack", function()
    return ""
  end)
  W.def("GetMoney", function()
    error("boom")
  end)
  Window.Refresh()
  W.def("GetMoney", function()
    return W.money
  end)
  Window.Refresh()
  local moneyCalls = W.calls.GetMoney
  local changeCalls = countChanges()
  loadText(RANK_2, NEW_TEXT)
  Assert.equal(W.calls.GetMoney, moneyCalls)
  Assert.equal(changeCalls(), 1)
  Assert.equal(shownLines(rowNamed("Shadow Word: Pain")), 2)
end

-- Not yet learned: Missed 1-5 (level 5), Renew Rank 2 (level 6), Missed 6-8
-- (level 7). Expanded, Renew is row 7; collapsed, the hint row is row 7.
local function test_result_skips_hint_row_at_index_of_earlier_rank_row()
  setup()
  db.trainers.PRIEST.covered.Scourge = 9
  W.spells[RANK_2].description = NEW_TEXT
  addMissed(5, 1, 5)
  addRenew(6)
  addMissed(7, 6, 3)
  Window.Show(record())
  click(toggle("not yet learned"))
  Assert.equal(rowNamed("Renew") ~= nil, true)
  click(toggle("Show less"))
  Assert.equal(rowNamed("Renew"), nil)
  loadText(RENEW_2, RENEW_TEXT)
  local hint = rowNamed(HINT_TEXT)
  Assert.equal(hint ~= nil, true)
  Assert.equal(shownLines(hint), 0)
  Assert.equal(hint:GetHeight(), ROW_HEIGHT)
end

-- Level 10 shows the Shadow Word: Pain rank row as row 1; level 12 shows a
-- new skill without a previous rank as row 1.
local function test_result_skips_new_skill_row_at_index_of_earlier_rank_row()
  setup()
  Window.Show(record())
  W.spells[FADE] = { name = "Fade", iconID = 3, description = "Fades you." }
  W.known[RANK_2] = true
  cacheSpell(12, FADE, "Rank 1")
  db.trainers.PRIEST.covered.Scourge = 12
  Window.Show(record(11, 12))
  loadText(RANK_2, NEW_TEXT)
  local fade = rowNamed("Fade")
  Assert.equal(fade ~= nil, true)
  Assert.equal(shownLines(fade), 0)
  Assert.equal(fade:GetHeight(), ROW_HEIGHT)
end

return function()
  test_successful_fill_after_error_makes_next_result_targeted()
  test_result_skips_hint_row_at_index_of_earlier_rank_row()
  test_result_skips_new_skill_row_at_index_of_earlier_rank_row()
end
