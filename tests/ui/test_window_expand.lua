local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local ns
local Window
local db

local LOAD_EVENT = "SPELL_DATA_LOAD_RESULT"
local MISSED_LEVEL = 5
local MISSED_BASE = 1000
local WEAPON_BASE = 2000
local ROW_HEIGHT = 47
local SOURCE_ROW_HEIGHT = 59
local ROW_GAP = 4
local BOX_HEIGHT = 235 + 4 * ROW_GAP
local CAP = 5
local RANK_1 = 589
local RANK_2 = 594

-- Fresh fake client, modules and db per test. The priest cache starts empty and
-- covers level 10 (no hint row); ns.OtherSources is this test's fixture.
local function setup(otherSources)
  W = Wow.Install()
  W.money = 1000
  db = {
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
    trainers = { PRIEST = { covered = { Scourge = 10 }, levels = {} } },
  }
  ns = { OtherSources = { PRIEST = otherSources or {} } }
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

local function trainerSpell(spellID, level, name, rank)
  W.spells[spellID] = W.spells[spellID] or { name = name, iconID = spellID }
  db.trainers.PRIEST.levels[level] = db.trainers.PRIEST.levels[level] or {}
  db.trainers.PRIEST.levels[level][spellID] = { cost = 100, rank = rank, races = { Scourge = true } }
end

-- Trainer spells at or below the old level 9: "Missed 1" .. "Missed n".
local function addMissed(count)
  for index = 1, count do
    trainerSpell(MISSED_BASE + index, MISSED_LEVEL, "Missed " .. index, "Rank 1")
  end
end

-- Fresh setup with Horde weapon rows "Weapon 1" .. "Weapon n".
local function setupWeapons(count)
  local otherSources = {}
  setup(otherSources)
  for index = 1, count do
    local id = WEAPON_BASE + index
    W.spells[id] = { name = "Weapon " .. index, iconID = id }
    otherSources[index] = { spellID = id, level = 1, kind = "weapon", faction = "Horde", npc = "N", place = "P", cost = 1 }
  end
end

local function record()
  return { fromLevel = 9, toLevel = 10, gains = { health = 15 }, before = { health = 100 } }
end

local function frame()
  return _G.LevelUpInfoFrame
end

local function content()
  for _, widget in ipairs(W.frames) do
    if widget:GetParent() == frame() and W.state(widget).frameType == "Frame" then
      return widget
    end
  end
end

-- Shown skill rows (Buttons with a name) whose parent is `parent`.
local function rowsIn(parent)
  local rows = {}
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "Button" and widget.name and widget:GetParent() == parent and widget:IsShown() then
      rows[#rows + 1] = widget
    end
  end
  return rows
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

-- The scroll box holding the row named `name`, and its child.
local function boxOf(name)
  local child = rowNamed(name):GetParent()
  return child:GetParent(), child
end

local function boxRows(name)
  local _, child = boxOf(name)
  return rowsIn(child)
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

local function test_more_line_is_a_hidden_toggle_until_needed()
  setup()
  addMissed(CAP)
  Window.Show(record())
  Assert.equal(toggle("more"), nil)
  addMissed(8)
  Window.Show(record())
  Assert.equal(toggle("more").label:GetText(), "+3 more not yet learned")
end

local function test_expand_moves_all_rows_into_box()
  setup()
  addMissed(8)
  Window.Show(record())
  local collapsed = frame():GetHeight()
  click(toggle("not yet learned"))
  local box, child = boxOf("Missed 1")
  Assert.equal(#rowsIn(child), 8)
  Assert.equal(#rowsIn(content()), 0)
  Assert.equal(box:GetParent(), content())
  Assert.equal(box:IsShown(), true)
  Assert.equal(box:GetHeight(), BOX_HEIGHT)
  Assert.equal(toggle("Show less") ~= nil, true)
  Assert.equal(frame():GetHeight(), collapsed)
end

local function test_expand_keeps_group_height_with_tall_rows()
  setupWeapons(7)
  Window.Show(record())
  local collapsed = frame():GetHeight()
  click(toggle("weapon skills"))
  local box = boxOf("Weapon 1")
  Assert.equal(box:GetHeight(), CAP * SOURCE_ROW_HEIGHT + (CAP - 1) * ROW_GAP)
  Assert.equal(frame():GetHeight(), collapsed)
end

local function test_collapse_returns_five_rows_to_content()
  setup()
  addMissed(8)
  Window.Show(record())
  click(toggle("not yet learned"))
  local box = boxOf("Missed 1")
  W.fireScript(box, "OnMouseWheel", -1)
  click(toggle("Show less"))
  Assert.equal(#rowsIn(content()), CAP)
  Assert.equal(box:IsShown(), false)
  Assert.equal(box:GetVerticalScroll(), 0)
  Assert.equal(toggle("more").label:GetText(), "+3 more not yet learned")
end

local function loadText(spellID, text)
  W.spells[spellID].description = text
  W.broadcast(LOAD_EVENT, spellID, true)
end

-- Six "Missed n" at level 5, then Shadow Word: Pain Rank 2 (level 6, the
-- 7th missed entry) whose known Rank 1 (level 4) gives it change lines.
local function setupRankPastCap()
  setup()
  addMissed(6)
  W.spells[RANK_1] = { name = "Shadow Word: Pain", iconID = 1, description = "", costs = { { cost = 25, name = "MANA" } } }
  W.spells[RANK_2] = { name = "Shadow Word: Pain", iconID = 1, description = "", costs = { { cost = 50, name = "MANA" } } }
  W.known[RANK_1] = true
  trainerSpell(RANK_1, 4, "Shadow Word: Pain", "Rank 1")
  trainerSpell(RANK_2, 6, "Shadow Word: Pain", "Rank 2")
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

local function test_expanded_rows_past_cap_get_change_lines()
  setupRankPastCap()
  Window.Show(record())
  Assert.equal(W.calls.RequestLoadSpellData, nil)
  Assert.equal(rowNamed("Shadow Word: Pain"), nil)
  click(toggle("not yet learned"))
  Assert.equal(W.calls.RequestLoadSpellData, 2)
  loadText(RANK_1, "Deals 30 Shadow damage over 18 sec.")
  loadText(RANK_2, "Deals 66 Shadow damage over 18 sec.")
  local row = rowNamed("Shadow Word: Pain")
  local _, child = boxOf("Missed 1")
  Assert.equal(row:GetParent(), child)
  Assert.equal(shownLines(row) > 0, true)
end

-- Shadow Word: Pain Rank 2 (level 3) sorts first among six missed entries;
-- its two change lines arrive after the expand and make it 59 px.
local function test_box_grows_when_a_visible_row_gets_lines()
  setup()
  addMissed(5)
  W.spells[RANK_1] = { name = "Shadow Word: Pain", iconID = 1, description = "", costs = { { cost = 25, name = "MANA" } } }
  W.spells[RANK_2] = { name = "Shadow Word: Pain", iconID = 1, description = "", costs = { { cost = 50, name = "MANA" } } }
  W.known[RANK_1] = true
  trainerSpell(RANK_1, 2, "Shadow Word: Pain", "Rank 1")
  trainerSpell(RANK_2, 3, "Shadow Word: Pain", "Rank 2")
  Window.Show(record())
  click(toggle("not yet learned"))
  local box = boxOf("Missed 1")
  Assert.equal(box:GetHeight(), BOX_HEIGHT)
  loadText(RANK_1, "Deals 30 Shadow damage over 18 sec.")
  loadText(RANK_2, "Deals 66 Shadow damage over 18 sec.")
  Assert.equal(box:GetHeight(), 4 * ROW_HEIGHT + SOURCE_ROW_HEIGHT + 4 * ROW_GAP)
end

local function test_second_expand_creates_no_frames()
  setup()
  addMissed(8)
  Window.Show(record())
  click(toggle("not yet learned"))
  click(toggle("Show less"))
  local frames = W.calls.CreateFrame
  click(toggle("not yet learned"))
  Assert.equal(#boxRows("Missed 1"), 8)
  Assert.equal(W.calls.CreateFrame, frames)
end

local function test_both_groups_expand_independently()
  setupWeapons(7)
  addMissed(8)
  Window.Show(record())
  local missed = toggle("not yet learned")
  local weapon = toggle("weapon skills")
  click(missed)
  click(weapon)
  local _, missedChild = boxOf("Missed 1")
  local weaponBox, weaponChild = boxOf("Weapon 1")
  Assert.equal(#rowsIn(missedChild), 8)
  Assert.equal(#rowsIn(weaponChild), 7)
  Assert.equal(missedChild:GetHeight(), 8 * ROW_HEIGHT + 7 * ROW_GAP)
  Assert.equal(weaponChild:GetHeight(), 7 * SOURCE_ROW_HEIGHT + 6 * ROW_GAP)
  click(missed)
  Assert.equal(#rowsIn(content()), CAP)
  Assert.equal(missed.label:GetText(), "+3 more not yet learned")
  Assert.equal(weapon.label:GetText(), "Show less")
  Assert.equal(weaponBox:IsShown(), true)
  Assert.equal(#rowsIn(weaponChild), 7)
end

local function test_new_show_collapses_and_reparents_rows()
  setupWeapons(7)
  addMissed(8)
  Window.Show(record())
  click(toggle("not yet learned"))
  click(toggle("weapon skills"))
  Window.Show(record())
  Assert.equal(#rowsIn(content()), 2 * CAP)
  Assert.equal(#allRows(), 2 * CAP)
  Assert.equal(shownBoxes(), 0)
  Assert.equal(toggle("not yet learned").label:GetText(), "+3 more not yet learned")
  Assert.equal(toggle("weapon skills").label:GetText(), "+2 more weapon skills")
end

local function test_expanded_state_survives_refresh()
  setup()
  addMissed(8)
  Window.Show(record())
  click(toggle("not yet learned"))
  local box = boxOf("Missed 1")
  W.fireScript(box, "OnMouseWheel", -1)
  Assert.equal(box:GetVerticalScroll(), ROW_HEIGHT)
  Window.Refresh()
  Assert.equal(#boxRows("Missed 1"), 8)
  Assert.equal(box:IsShown(), true)
  Assert.equal(box:GetVerticalScroll(), ROW_HEIGHT)
end

return function()
  test_more_line_is_a_hidden_toggle_until_needed()
  test_expand_moves_all_rows_into_box()
  test_expand_keeps_group_height_with_tall_rows()
  test_collapse_returns_five_rows_to_content()
  test_expanded_rows_past_cap_get_change_lines()
  test_box_grows_when_a_visible_row_gets_lines()
  test_second_expand_creates_no_frames()
  test_both_groups_expand_independently()
  test_new_show_collapses_and_reparents_rows()
  test_expanded_state_survives_refresh()
end
