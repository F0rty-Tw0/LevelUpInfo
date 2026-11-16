-- The window's last group, Next at N: what the trainer teaches at the next
-- cached level that has something. Folded on every show behind a count and the
-- group's price; opened, trainer rows without the hide eye.
local Assert = require("tests.helpers.assert")
local WindowHelper = require("tests.helpers.window")

local W
local ns
local Window
local levels
local db

local content = WindowHelper.content
local rowNamed = WindowHelper.rowNamed
local toggle = WindowHelper.toggle
local click = WindowHelper.click
local breakFill = WindowHelper.breakFill
local headings = WindowHelper.headings
local foldButtons = WindowHelper.foldButtons
local totalOf = WindowHelper.totalOf
local nextHeading = WindowHelper.nextHeading

local LOAD_EVENT = "SPELL_DATA_LOAD_RESULT"
local HINT = "Visit your class trainer to see all new skills."
local PREFIX = "Next at"
local HEADING_HEIGHT = 24
local GROUP_GAP = 14
local ROW_HEIGHT = 47
local ROW_GAP = 4
local CAP = 4
local MISSED_LEVEL = 5
local MISSED_BASE = 1000
local NEXT_BASE = 2000
local MIND_BLAST, FADE, RENEW, INNER_FIRE = 8092, 586, 139, 588
local FADE_2 = 9586

local function rank1()
  return { cost = 100, rank = "Rank 1", races = { Scourge = true } }
end

local function unranked()
  return { cost = 50, rank = "", races = { Scourge = true } }
end

-- Fresh fake client, modules and db per test. Mind Blast is new at 10; the
-- cache also holds level 14 (Fade, Renew).
local function setup()
  W = WindowHelper.install()
  W.money = 1000
  W.spells[MIND_BLAST] = { name = "Mind Blast", iconID = 1 }
  W.spells[FADE] = { name = "Fade", iconID = 2 }
  W.spells[RENEW] = { name = "Renew", iconID = 3 }
  W.spells[INNER_FIRE] = { name = "Inner Fire", iconID = 4 }
  db = WindowHelper.db({ PRIEST = { covered = { Scourge = 10 }, levels = {} } })
  levels = db.trainers.PRIEST.levels
  levels[10] = { [MIND_BLAST] = rank1() }
  levels[14] = { [FADE] = rank1(), [RENEW] = rank1() }
  ns = { OtherSources = { PRIEST = {} } }
  Window = WindowHelper.load(ns)
  Window.Install(db, WindowHelper.charDB())
  ns.SpellFacts.Install(Window.Refresh)
end

local function record()
  return { fromLevel = 9, toLevel = 10, gains = { health = 15 }, before = { health = 100 } }
end

-- The shown heading texts in layout order.
local function shownHeadings()
  local found = {}
  for text in string.gmatch(headings(), "[^|]+") do
    found[#found + 1] = text
  end

  return found
end

local function lastHeading()
  local found = shownHeadings()

  return found[#found]
end

-- The shown font string whose text is `text`, on the content frame.
local function headingNamed(text)
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "FontString" and widget:IsShown() and widget:GetParent() == content() then
      if widget:GetText() == text then
        return widget
      end
    end
  end
end

local function offset(widget)
  return -select(5, widget:GetPoint())
end

local function contentHeight()
  return content():GetHeight()
end

local function openNext()
  local buttons = foldButtons()
  click(buttons[#buttons])
end

-- `count` rank 1 skills named "<prefix> <n>" at `level`, in place of what was there.
local function skillsAt(level, base, prefix, count)
  levels[level] = {}
  for index = 1, count do
    local spellID = base + index
    W.spells[spellID] = { name = prefix .. " " .. index, iconID = spellID }
    levels[level][spellID] = rank1()
  end
end

-- Wraps SkillList.Build with a call counter.
local function countBuilds()
  local counter = { count = 0 }
  local build = ns.SkillList.Build
  ns.SkillList.Build = function(...)
    counter.count = counter.count + 1

    return build(...)
  end

  return counter
end

local function test_folded_heading_sits_last_with_the_14px_gap()
  setup()
  Window.Show(record())
  Assert.equal(lastHeading(), "Next at 14 (2)")
  local heading, row = headingNamed("Next at 14 (2)"), rowNamed("Mind Blast")
  Assert.equal(offset(heading) - offset(row), row:GetHeight() + GROUP_GAP)
end

local function test_folded_heading_shows_the_group_total()
  setup()
  Window.Show(record())
  Assert.equal(totalOf(PREFIX):GetText(), _G.GetMoneyString(200))
end

local function test_no_heading_when_nothing_is_cached_above()
  setup()
  levels[14] = nil
  Window.Show(record())
  Assert.equal(nextHeading(), nil)
  Assert.equal(#foldButtons(), 0)
end

local function test_heading_alone_sits_at_the_top_with_no_gap()
  setup()
  levels[10] = nil
  Window.Show({ fromLevel = 9, toLevel = 10, gains = {}, before = {} })
  Assert.equal(offset(headingNamed("Next at 14 (2)")), 0)
  Assert.equal(contentHeight(), HEADING_HEIGHT)
end

local function test_content_height_includes_the_heading_and_its_gap()
  setup()
  Window.Show(record())
  local withHeading = contentHeight()
  levels[14] = nil
  Window.Show(record())
  Assert.equal(withHeading - contentHeight(), HEADING_HEIGHT + GROUP_GAP)
end

local function test_heading_follows_the_hint_row()
  setup()
  db.trainers.PRIEST.covered.Scourge = 9
  Window.Show(record())
  local hint = rowNamed(HINT)
  Assert.equal(offset(headingNamed("Next at 14 (2)")) - offset(hint), hint:GetHeight() + GROUP_GAP)
end

-- No gains and no skill groups: only the hint sits above, so the gap comes from the hint alone.
local function test_heading_after_a_lone_hint_row_keeps_the_block_gap()
  setup()
  levels[10] = nil
  db.trainers.PRIEST.covered.Scourge = 9
  Window.Show({ fromLevel = 9, toLevel = 10, gains = {}, before = {} })
  local hint = rowNamed(HINT)
  Assert.equal(offset(headingNamed("Next at 14 (2)")) - offset(hint), hint:GetHeight() + GROUP_GAP)
end

local function test_open_group_lists_the_rows_without_an_eye()
  setup()
  Window.Show(record())
  openNext()
  Assert.equal(lastHeading(), "Next at 14")
  Assert.equal(rowNamed("Fade").dismiss:IsShown(), false)
  Assert.equal(rowNamed("Renew").dismiss:IsShown(), false)
end

local function test_opening_the_group_saves_no_fold()
  setup()
  Window.Show(record())
  openNext()
  Assert.equal(db.foldedGroups.next, nil)
end

local function test_show_again_folds_the_open_group()
  setup()
  Window.Show(record())
  openNext()
  Window.Show(record())
  Assert.equal(lastHeading(), "Next at 14 (2)")
  Assert.equal(rowNamed("Fade"), nil)
end

local function test_six_next_skills_open_to_four_rows_and_a_more_toggle()
  setup()
  skillsAt(14, NEXT_BASE, "Next", 6)
  Window.Show(record())
  openNext()
  local shown = 0
  for index = 1, 6 do
    shown = shown + (rowNamed("Next " .. index) and 1 or 0)
  end
  Assert.equal(shown, 4)
  Assert.equal(toggle("+2 more next level") ~= nil, true)
end

local function test_expanded_next_group_survives_a_dismiss_elsewhere()
  setup()
  skillsAt(14, NEXT_BASE, "Next", 6)
  Window.Show(record())
  openNext()
  click(toggle("+2 more next level"))
  Assert.equal(toggle("Show less") ~= nil, true)
  W.fireScript(rowNamed("Mind Blast").dismiss, "OnClick")
  Assert.equal(toggle("Show less") ~= nil, true)
end

local function test_toggle_refill_keeps_the_group_without_a_new_build()
  setup()
  skillsAt(MISSED_LEVEL, MISSED_BASE, "Missed", 6)
  local builds = countBuilds()
  Window.Show(record())
  local text = lastHeading()
  builds.count = 0
  click(toggle("more"))
  Assert.equal(builds.count, 0)
  Assert.equal(lastHeading(), text)
end

-- The expanded box keeps the group's size (CAP rows and their gaps) and scrolls all six.
local function test_expanded_next_box_is_cap_rows_tall_and_scrolls_all_six()
  setup()
  skillsAt(14, NEXT_BASE, "Next", 6)
  Window.Show(record())
  openNext()
  click(toggle("+2 more next level"))
  local box, child = ns.SkillGroup.Box("next")
  Assert.equal(box:GetHeight(), CAP * ROW_HEIGHT + (CAP - 1) * ROW_GAP)
  Assert.equal(child:GetHeight(), 6 * ROW_HEIGHT + 5 * ROW_GAP)
end

local function test_fill_error_hides_the_group()
  setup()
  Window.Show(record())
  local total = totalOf(PREFIX)
  openNext()
  Assert.equal(total:IsShown(), true)
  breakFill()
  Window.Refresh()
  Assert.equal(nextHeading(), nil)
  Assert.equal(#foldButtons(), 0)
  Assert.equal(total:IsShown(), false)
end

local function test_rank_wait_rebuild_recomputes_the_group()
  setup()
  levels[10] = { [FADE] = unranked() }
  levels[14] = nil
  W.spells[FADE].description = ""
  Window.Show(record())
  Assert.equal(nextHeading(), nil)
  levels[14] = { [INNER_FIRE] = rank1() }
  W.spells[FADE].description = "Spell text."
  W.broadcast(LOAD_EVENT, FADE, true)
  Assert.equal(lastHeading(), "Next at 14 (1)")
end

-- Fade Rank 1 is new at 10, Rank 2 comes at 14 and lists a change line against Rank 1.
local function setupFadeRankChange()
  setup()
  W.spells[FADE_2] = { name = "Fade", iconID = 2 }
  W.spells[FADE].description = ""
  W.spells[FADE_2].description = ""
  levels[10] = { [FADE] = rank1() }
  levels[14] = { [FADE_2] = { cost = 100, rank = "Rank 2", races = { Scourge = true } } }
end

local function test_folded_group_requests_no_spell_text()
  setupFadeRankChange()
  local requests = W.calls.RequestLoadSpellData or 0
  Window.Show(record())
  Assert.equal(lastHeading(), "Next at 14 (1)")
  Assert.equal(W.calls.RequestLoadSpellData or 0, requests)
end

local function test_opening_the_group_requests_spell_text()
  setupFadeRankChange()
  Window.Show(record())
  local requests = W.calls.RequestLoadSpellData or 0
  openNext()
  Assert.equal((W.calls.RequestLoadSpellData or 0) > requests, true)
end

return function()
  test_folded_heading_sits_last_with_the_14px_gap()
  test_folded_heading_shows_the_group_total()
  test_no_heading_when_nothing_is_cached_above()
  test_heading_alone_sits_at_the_top_with_no_gap()
  test_content_height_includes_the_heading_and_its_gap()
  test_heading_follows_the_hint_row()
  test_heading_after_a_lone_hint_row_keeps_the_block_gap()
  test_open_group_lists_the_rows_without_an_eye()
  test_opening_the_group_saves_no_fold()
  test_show_again_folds_the_open_group()
  test_six_next_skills_open_to_four_rows_and_a_more_toggle()
  test_expanded_next_group_survives_a_dismiss_elsewhere()
  test_toggle_refill_keeps_the_group_without_a_new_build()
  test_expanded_next_box_is_cap_rows_tall_and_scrolls_all_six()
  test_fill_error_hides_the_group()
  test_rank_wait_rebuild_recomputes_the_group()
  test_folded_group_requests_no_spell_text()
  test_opening_the_group_requests_spell_text()
end
