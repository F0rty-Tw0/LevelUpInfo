-- Hiding and restoring skills through the window: the dismiss click and Show hidden skills.
local Assert = require("tests.helpers.assert")
local WindowHelper = require("tests.helpers.window")

local W
local ns
local Window
local db
local charDB

local frame = WindowHelper.frame
local rowNames = WindowHelper.rowNames
local rowNamed = WindowHelper.rowNamed
local allRows = WindowHelper.allRows
local toggle = WindowHelper.toggle
local click = WindowHelper.click
local headings = WindowHelper.headings
local foldButtons = WindowHelper.foldButtons
local totalOf = WindowHelper.totalOf
local dismissOf = WindowHelper.dismissOf
local shownBoxes = WindowHelper.shownBoxes

local CAP = 4 -- SkillFill GROUP_CAP
local MISSED_LEVEL = 5
local MISSED_BASE = 1000
local KNOWN_RANK_OFFSET = 100000
local QUEST_SPELL, RANK_2_SPELL = 3001, 3002
local FADE_1, FADE_2, RENEW = 586, 9586, 139
local SHADOW_PAIN = "Shadow Word: Pain"
local EYE_CROSSED = "Interface\\AddOns\\LevelUpInfo\\Media\\EyeCrossed.tga"
local EYE_OPEN = "Interface\\AddOns\\LevelUpInfo\\Media\\EyeOpen.tga"

-- Fresh fake client, modules, db and character table per test. The priest cache
-- starts empty and covers level 10 (no hint row).
local function setup(otherSources)
  W = WindowHelper.install()
  W.money = 1000
  db = WindowHelper.db({ PRIEST = { covered = { Scourge = 10 }, levels = {} } })
  charDB = WindowHelper.charDB()
  ns = { OtherSources = { PRIEST = otherSources or {} } }
  Window = WindowHelper.load(ns)
  Window.Install(db, charDB)
  ns.SpellFacts.Install(Window.Refresh)
end

local function trainerSpell(spellID, level, name, rank)
  W.spells[spellID] = W.spells[spellID] or { name = name, iconID = spellID }
  if (tonumber(rank:match("%d+")) or 0) >= 2 then
    W.spells[spellID + KNOWN_RANK_OFFSET] = { name = name, iconID = spellID }
    W.known[spellID + KNOWN_RANK_OFFSET] = true
  end
  db.trainers.PRIEST.levels[level] = db.trainers.PRIEST.levels[level] or {}
  db.trainers.PRIEST.levels[level][spellID] = { cost = 100, rank = rank, races = { Scourge = true } }
end

local function addMissed(count)
  for index = 1, count do
    trainerSpell(MISSED_BASE + index, MISSED_LEVEL, "Missed " .. index, "Rank 1")
  end
end

local function record()
  return { fromLevel = 9, toLevel = 10, gains = { health = 15 }, before = { health = 100 } }
end

local function clickDismiss(name)
  W.fireScript(rowNamed(name).dismiss, "OnClick")
end

-- Three Not yet learned rows (total 300c); the dismiss button hides Missed 1.
local function showAndHideMissed1()
  setup()
  addMissed(3)
  Window.Show(record())
  clickDismiss("Missed 1")
end

-- Then opens Hidden and clicks Missed 1's restore button.
local function hideAndRestoreMissed1()
  showAndHideMissed1()
  click(foldButtons()[2])
  clickDismiss("Missed 1")
end

local function test_dismiss_click_saves_the_name_as_hidden()
  showAndHideMissed1()
  Assert.equal(charDB.hidden["Missed 1"], true)
end

local function test_dismiss_click_moves_the_row_to_the_hidden_group()
  showAndHideMissed1()
  Assert.equal(rowNames(), "Missed 2|Missed 3")
  Assert.equal(headings(), "Stats|Not yet learned|Hidden (1)")
end

local function test_dismiss_click_takes_the_cost_out_of_the_group_total()
  showAndHideMissed1()
  Assert.equal(totalOf("Not yet learned"):GetText(), "200c")
end

local function test_an_opened_hidden_group_shows_the_restore_button()
  showAndHideMissed1()
  click(foldButtons()[2])
  Assert.equal(headings(), "Stats|Not yet learned|Hidden")
  Assert.equal(dismissOf("Missed 1"), EYE_OPEN)
  Assert.equal(dismissOf("Missed 2"), EYE_CROSSED)
end

local function test_restore_click_clears_the_saved_name()
  hideAndRestoreMissed1()
  Assert.equal(charDB.hidden["Missed 1"], nil)
end

local function test_restore_click_moves_the_row_back_to_its_group()
  hideAndRestoreMissed1()
  Assert.equal(rowNames(), "Missed 1|Missed 2|Missed 3")
  Assert.equal(headings(), "Stats|Not yet learned")
end

local function test_restore_click_puts_the_cost_back_in_the_total()
  hideAndRestoreMissed1()
  Assert.equal(totalOf("Not yet learned"):GetText(), "300c")
end

local function test_dismiss_click_pins_the_top_edge_like_a_fold_click()
  setup()
  addMissed(2)
  db.scale = 1.5
  Window.Show(record())
  W.state(frame()).left = 100
  W.state(frame()).top = 600
  W.state(_G.UIParent).top = 768
  clickDismiss("Missed 1")
  local point, relativeTo, relativePoint, x, y = frame():GetPoint(1)
  Assert.equal(point, "TOPLEFT")
  Assert.equal(relativeTo, _G.UIParent)
  Assert.equal(relativePoint, "TOPLEFT")
  Assert.equal(x, 100)
  Assert.equal(y, 88)
  Assert.equal(db.position, nil)
end

-- The last row leaves an expanded group, so its heading, toggle
-- and box go; the Hidden heading takes the count.
local function test_hiding_the_last_entry_of_an_expanded_group_removes_the_group()
  setup()
  addMissed(CAP + 1)
  Window.Show(record())
  click(toggle("more not yet learned"))
  Assert.equal(shownBoxes(), 1)
  for index = 1, CAP do
    clickDismiss("Missed " .. index)
  end
  W.state(frame()).left = 100
  W.state(frame()).top = 600
  clickDismiss("Missed " .. CAP + 1)
  Assert.equal(headings(), "Stats|Hidden (" .. CAP + 1 .. ")")
  Assert.equal(shownBoxes(), 0)
  Assert.equal(toggle("Show less"), nil)
  Assert.equal(toggle("not yet learned"), nil)
  local point, _, _, x = frame():GetPoint(1)
  Assert.equal(point, "TOPLEFT")
  Assert.equal(x, 100)
end

-- A quest Rank 1 and a trainer Rank 2 share a name; one dismiss
-- click moves both, one click on the restore button returns both.
local function test_a_repeated_name_hides_and_restores_together()
  local otherSources = {}
  setup(otherSources)
  W.spells[QUEST_SPELL] = { name = SHADOW_PAIN, iconID = 1 }
  otherSources[1] = { spellID = QUEST_SPELL, level = 1, kind = "quest", quest = "Q", npc = "N", place = "P" }
  trainerSpell(RANK_2_SPELL, 10, SHADOW_PAIN, "Rank 2")
  Window.Show(record())
  Assert.equal(headings(), "Stats|New ranks|Not yet learned")
  W.fireScript(allRows()[1].dismiss, "OnClick")
  Assert.equal(headings(), "Stats|Hidden (2)")
  click(foldButtons()[1])
  Assert.equal(rowNames(), SHADOW_PAIN .. "|" .. SHADOW_PAIN)
  W.fireScript(allRows()[1].dismiss, "OnClick")
  Assert.equal(next(charDB.hidden), nil)
  Assert.equal(headings(), "Stats|New ranks|Not yet learned")
end

-- A /lui test or Show last record is not a live level-up.
local function test_dismiss_works_on_a_test_record()
  setup()
  addMissed(2)
  Window.Show({ fromLevel = 9, toLevel = 10, gains = {}, before = {}, isTest = true })
  clickDismiss("Missed 2")
  Assert.equal(charDB.hidden["Missed 2"], true)
  Assert.equal(headings(), "Not yet learned|Hidden (1)")
end

local function test_dismiss_click_without_a_live_record_changes_nothing()
  setup()
  addMissed(2)
  Window.Show(record())
  W.fireScript(frame(), "OnHide")
  clickDismiss("Missed 1")
  Assert.equal(next(charDB.hidden), nil)
  Assert.equal(#allRows(), 2)
end

local function test_a_new_show_marks_the_list_from_the_saved_names()
  setup()
  addMissed(2)
  charDB.hidden["Missed 1"] = true
  Window.Show(record())
  Assert.equal(rowNames(), "Missed 2")
  Assert.equal(headings(), "Stats|Not yet learned|Hidden (1)")
end

local function test_show_hidden_skills_wipes_the_list_and_refills()
  setup()
  addMissed(3)
  charDB.hidden["Missed 1"] = true
  charDB.hidden["Missed 3"] = true
  Window.Show(record())
  Assert.equal(headings(), "Stats|Not yet learned|Hidden (2)")
  Window.ShowHidden()
  Assert.equal(next(charDB.hidden), nil)
  Assert.equal(rowNames(), "Missed 1|Missed 2|Missed 3")
  Assert.equal(headings(), "Stats|Not yet learned")
end

local function test_show_hidden_skills_with_the_window_closed_still_wipes()
  setup()
  addMissed(2)
  charDB.hidden["Missed 1"] = true
  Window.Show(record())
  W.fireScript(frame(), "OnHide")
  Window.ShowHidden()
  Assert.equal(next(charDB.hidden), nil)
  Window.Show(record())
  Assert.equal(rowNames(), "Missed 1|Missed 2")
end

-- Fade Rank 1 is a row; its Rank 2 is the only skill of level 14, so
-- hiding Fade moves the line on, or hides it with nothing after.
local function setupNextLevel()
  setup()
  W.spells[FADE_1] = { name = "Fade", iconID = 1 }
  W.spells[FADE_2] = { name = "Fade", iconID = 1 }
  W.spells[RENEW] = { name = "Renew", iconID = 2 }
  local levels = db.trainers.PRIEST.levels
  levels[10] = { [FADE_1] = { cost = 100, rank = "Rank 1", races = { Scourge = true } } }
  levels[14] = { [FADE_2] = { cost = 100, rank = "Rank 2", races = { Scourge = true } } }
  levels[18] = { [RENEW] = { cost = 100, rank = "Rank 1", races = { Scourge = true } } }
end

local function nextLineText()
  for _, widget in ipairs(W.frames) do
    local text = widget:GetText() or ""
    if W.state(widget).frameType == "FontString" and widget:IsShown() and text:sub(1, 7) == "Next at" then
      return text
    end
  end
end

local function test_hiding_the_only_skill_of_the_next_level_moves_the_line_on()
  setupNextLevel()
  Window.Show(record())
  Assert.equal(nextLineText(), "Next at 14: Fade (Rank 2)")
  clickDismiss("Fade")
  Assert.equal(nextLineText(), "Next at 18: Renew (Rank 1)")
  click(foldButtons()[1])
  clickDismiss("Fade")
  Assert.equal(nextLineText(), "Next at 14: Fade (Rank 2)")
end

local function test_hiding_the_only_skill_of_the_last_level_hides_the_line()
  setupNextLevel()
  db.trainers.PRIEST.levels[18] = nil
  Window.Show(record())
  clickDismiss("Fade")
  Assert.equal(nextLineText(), nil)
end

local function test_install_needs_a_character_table()
  setup()
  Assert.equal(pcall(Window.Install, db), false)
  Assert.equal(pcall(Window.Install, db, charDB), true)
end

return function()
  test_dismiss_click_saves_the_name_as_hidden()
  test_dismiss_click_moves_the_row_to_the_hidden_group()
  test_dismiss_click_takes_the_cost_out_of_the_group_total()
  test_an_opened_hidden_group_shows_the_restore_button()
  test_restore_click_clears_the_saved_name()
  test_restore_click_moves_the_row_back_to_its_group()
  test_restore_click_puts_the_cost_back_in_the_total()
  test_dismiss_click_pins_the_top_edge_like_a_fold_click()
  test_hiding_the_last_entry_of_an_expanded_group_removes_the_group()
  test_a_repeated_name_hides_and_restores_together()
  test_dismiss_works_on_a_test_record()
  test_dismiss_click_without_a_live_record_changes_nothing()
  test_a_new_show_marks_the_list_from_the_saved_names()
  test_show_hidden_skills_wipes_the_list_and_refills()
  test_show_hidden_skills_with_the_window_closed_still_wipes()
  test_hiding_the_only_skill_of_the_next_level_moves_the_line_on()
  test_hiding_the_only_skill_of_the_last_level_hides_the_line()
  test_install_needs_a_character_table()
end
