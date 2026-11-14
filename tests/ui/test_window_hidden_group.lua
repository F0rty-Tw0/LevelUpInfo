-- The Hidden group: the last skill group, folded until opened, holding every
-- entry flagged `hidden` whatever its own group.
local Assert = require("tests.helpers.assert")
local WindowHelper = require("tests.helpers.window")

local W
local ns
local Window
local db
local charDB

local rowNames = WindowHelper.rowNames
local rowNamed = WindowHelper.rowNamed
local allRows = WindowHelper.allRows
local toggle = WindowHelper.toggle
local click = WindowHelper.click
local headings = WindowHelper.headings
local foldButtons = WindowHelper.foldButtons
local totalOf = WindowHelper.totalOf
local dismissOf = WindowHelper.dismissOf

local MISSED_LEVEL = 5
local MISSED_BASE = 1000
local WEAPON_BASE = 2000
local QUEST_SPELL = 3001
local RANK_2_SPELL = 3002
local KNOWN_RANK_OFFSET = 100000
local CAP = 4 -- SkillFill GROUP_CAP
local DISMISS = "Interface\\AddOns\\LevelUpInfo\\Media\\Dismiss.tga"
local RESTORE = "Interface\\AddOns\\LevelUpInfo\\Media\\Restore.tga"
local SHADOW_PAIN = "Shadow Word: Pain"

-- Fresh fake client, modules and db per test. The priest cache starts empty and
-- covers level 10 (no hint row); ns.OtherSources is this test's fixture.
local function setup(otherSources)
  W = WindowHelper.install()
  W.money = 1000
  db = WindowHelper.db({ PRIEST = { covered = { Scourge = 10 }, levels = {} } })
  ns = { OtherSources = { PRIEST = otherSources or {} } }
  Window = WindowHelper.load(ns)
  charDB = WindowHelper.charDB()
  Window.Install(db, charDB)
  ns.SpellFacts.Install(Window.Refresh)
end

-- Marks every name in `list` hidden for this character.
local function hide(list)
  for _, name in ipairs(list) do
    charDB.hidden[name] = true
  end
end

-- A Rank 2 or higher also gives the player a known earlier rank (spellbook only).
local function trainerSpell(spellID, level, name, rank)
  W.spells[spellID] = W.spells[spellID] or { name = name, iconID = spellID }
  if (tonumber(rank:match("%d+")) or 0) >= 2 then
    W.spells[spellID + KNOWN_RANK_OFFSET] = { name = name, iconID = spellID }
    W.known[spellID + KNOWN_RANK_OFFSET] = true
  end
  db.trainers.PRIEST.levels[level] = db.trainers.PRIEST.levels[level] or {}
  db.trainers.PRIEST.levels[level][spellID] = { cost = 100, rank = rank, races = { Scourge = true } }
end

-- Trainer spells at or below the old level 9: "Missed 1" .. "Missed n".
local function addMissed(count)
  for index = 1, count do
    trainerSpell(MISSED_BASE + index, MISSED_LEVEL, "Missed " .. index, "Rank 1")
  end
end

local function weaponRow(spellID, name)
  W.spells[spellID] = { name = name, iconID = spellID }
  return { spellID = spellID, level = 1, kind = "weapon", faction = "Horde", npc = "N", place = "P", cost = 100 }
end

local function record()
  return { fromLevel = 9, toLevel = 10, gains = { health = 15 }, before = { health = 100 } }
end

-- Hidden skills of three kinds: a trainer skill, a missed one and a weapon.
local function setupMixed()
  local otherSources = {}
  setup(otherSources)
  trainerSpell(11, 10, "New Skill", "Rank 1")
  addMissed(2)
  otherSources[1] = weaponRow(WEAPON_BASE + 1, "Axe")
  hide({ "Missed 1", "Axe" })
end

local function test_hidden_group_is_the_last_heading_and_counts_its_rows()
  setupMixed()
  Window.Show(record())
  Assert.equal(headings(), "Stats|New skills|Not yet learned|Hidden (2)")
end

local function test_hidden_group_starts_with_its_rows_folded_away()
  setupMixed()
  Window.Show(record())
  Assert.equal(rowNames(), "New Skill|Missed 2")
end

local function test_hidden_group_has_a_fold_button()
  setupMixed()
  Window.Show(record())
  Assert.equal(#foldButtons(), 2)
end

local function test_hidden_group_starting_folded_saves_no_flag()
  setupMixed()
  Window.Show(record())
  Assert.equal(db.foldedGroups.hidden, nil)
end

local function test_opening_hidden_lists_its_rows_with_the_restore_button()
  setupMixed()
  Window.Show(record())
  click(foldButtons()[2])
  Assert.equal(headings(), "Stats|New skills|Not yet learned|Hidden")
  Assert.equal(rowNames(), "New Skill|Missed 2|Missed 1|Axe")
  Assert.equal(dismissOf("Missed 1"), RESTORE)
  Assert.equal(dismissOf("Axe"), RESTORE)
  Assert.equal(dismissOf("New Skill"), DISMISS)
  Assert.equal(db.foldedGroups.hidden, false)
end

local function test_shown_groups_skip_hidden_cost()
  setup()
  addMissed(4)
  hide({ "Missed 1", "Missed 2" })
  Window.Show(record())
  click(foldButtons()[2])
  Assert.equal(totalOf("Not yet learned"):GetText(), "200c")
end

-- Three hidden at trainerSpell's 100 each; Not yet learned keeps 200c, so a
-- wrong-line match fails. Hidden stays folded: its total shows anyway.
local function test_hidden_group_shows_the_total_of_its_skills()
  setup()
  addMissed(5)
  hide({ "Missed 1", "Missed 2", "Missed 3" })
  Window.Show(record())
  Assert.equal(totalOf("Hidden"):GetText(), "300c")
end

local function test_hidden_group_is_capped_with_a_more_hidden_toggle_and_a_box()
  setup()
  addMissed(CAP + 2)
  local names = {}
  for index = 1, CAP + 2 do
    names[index] = "Missed " .. index
  end
  hide(names)
  Window.Show(record())
  Assert.equal(headings(), "Stats|Hidden (" .. CAP + 2 .. ")")
  click(foldButtons()[1])
  Assert.equal(#allRows(), CAP)
  Assert.equal(toggle("more hidden").label:GetText(), "+2 more hidden")
  click(toggle("more hidden"))
  Assert.equal(#allRows(), CAP + 2)
  Assert.equal(toggle("Show less") ~= nil, true)
end

-- A hidden row is built like any other, minus its rank change lines and the
-- spell data they would request.
local RANK_1, RANK_2 = 589, 594
local function waitingRank()
  W.spells[RANK_1] = { name = SHADOW_PAIN, iconID = 1, description = "", costs = { { cost = 25, name = "MANA" } } }
  W.spells[RANK_2] = { name = SHADOW_PAIN, iconID = 1, description = "", costs = { { cost = 50, name = "MANA" } } }
  W.known[RANK_1] = true
  trainerSpell(RANK_1, 4, SHADOW_PAIN, "Rank 1")
  trainerSpell(RANK_2, 6, SHADOW_PAIN, "Rank 2")
end

-- The hidden rank row, in an opened Hidden group.
local function showHiddenRank()
  setup()
  waitingRank()
  hide({ SHADOW_PAIN })
  db.foldedGroups.hidden = false
  Window.Show(record())
end

local function test_hidden_rows_have_no_change_lines()
  showHiddenRank()
  local row = rowNamed(SHADOW_PAIN)
  Assert.equal(row ~= nil, true)
  Assert.equal(WindowHelper.shownLines(row), 0)
end

local function test_hidden_rows_request_no_spell_text()
  showHiddenRank()
  Assert.equal(W.calls.RequestLoadSpellData, nil)
end

-- A quest Rank 1 (Not yet learned) and a trainer Rank 2 (New ranks) share a
-- name, so hiding that name moves both.
local function test_a_name_repeated_across_groups_moves_to_hidden_together()
  local otherSources = {}
  setup(otherSources)
  W.spells[QUEST_SPELL] = { name = SHADOW_PAIN, iconID = 1 }
  otherSources[1] = { spellID = QUEST_SPELL, level = 1, kind = "quest", quest = "Q", npc = "N", place = "P" }
  trainerSpell(RANK_2_SPELL, 10, SHADOW_PAIN, "Rank 2")
  Window.Show(record())
  Assert.equal(headings(), "Stats|New ranks|Not yet learned")
  hide({ SHADOW_PAIN })
  Window.Show(record())
  Assert.equal(headings(), "Stats|Hidden (2)")
  click(foldButtons()[1])
  Assert.equal(rowNames(), SHADOW_PAIN .. "|" .. SHADOW_PAIN)
end

-- SkillFill hands the window's dismiss callback to every row it makes.
local function test_every_row_gets_the_dismiss_callback()
  W = WindowHelper.install()
  W.money = 1000
  ns = { OtherSources = {} }
  WindowHelper.load(ns)
  local clicked = {}
  local parent = _G.CreateFrame("Frame", nil, _G.UIParent)
  ns.SkillFill.Build(parent, function() end, {}, function() end, function(name)
    clicked[#clicked + 1] = name
  end)
  ns.Layout.Reset()
  ns.SkillFill.Fill({ { spellID = 1, name = "Missed 1", icon = 1, rank = "", cost = 1, group = "missed" } }, false, nil, nil, 0)
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "Button" and widget.name and widget:GetParent() == parent then
      W.fireScript(widget.dismiss, "OnClick")
    end
  end
  Assert.equal(table.concat(clicked, "|"), "Missed 1")
end

return function()
  test_hidden_group_is_the_last_heading_and_counts_its_rows()
  test_hidden_group_starts_with_its_rows_folded_away()
  test_hidden_group_has_a_fold_button()
  test_hidden_group_starting_folded_saves_no_flag()
  test_opening_hidden_lists_its_rows_with_the_restore_button()
  test_shown_groups_skip_hidden_cost()
  test_hidden_group_shows_the_total_of_its_skills()
  test_hidden_group_is_capped_with_a_more_hidden_toggle_and_a_box()
  test_hidden_rows_have_no_change_lines()
  test_hidden_rows_request_no_spell_text()
  test_a_name_repeated_across_groups_moves_to_hidden_together()
  test_every_row_gets_the_dismiss_callback()
end
