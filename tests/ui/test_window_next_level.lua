-- The window's last line names what the trainer teaches at the next cached
-- level that has something: `Next at 14: Fade (Rank 1), Renew (Rank 1)`.
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local ns
local Window
local levels
local db

local LOAD_EVENT = "SPELL_DATA_LOAD_RESULT"
local HINT = "Visit your class trainer to see all new skills."
local LINE_PREFIX = "Next at"
local LINE_HEIGHT = 16
local GROUP_GAP = 14
local MISSED_LEVEL = 5
local MISSED_BASE = 1000
local MIND_BLAST, FADE, RENEW, INNER_FIRE = 8092, 586, 139, 588

local function rank1()
  return { cost = 100, rank = "Rank 1", races = { Scourge = true } }
end

local function unranked()
  return { cost = 50, rank = "", races = { Scourge = true } }
end

-- Fresh fake client, modules and db per test. Mind Blast is new at 10; the
-- cache also holds level 14 (Fade, Renew).
local function setup()
  W = Wow.Install()
  W.money = 1000
  W.spells[MIND_BLAST] = { name = "Mind Blast", iconID = 1 }
  W.spells[FADE] = { name = "Fade", iconID = 2 }
  W.spells[RENEW] = { name = "Renew", iconID = 3 }
  W.spells[INNER_FIRE] = { name = "Inner Fire", iconID = 4 }
  db = {
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
    foldedGroups = {},
    trainers = { PRIEST = { covered = { Scourge = 10 }, levels = {} } },
  }
  levels = db.trainers.PRIEST.levels
  levels[10] = { [MIND_BLAST] = rank1() }
  levels[14] = { [FADE] = rank1(), [RENEW] = rank1() }
  ns = { OtherSources = { PRIEST = {} } }
  for _, file in ipairs({
    "Core/Localization.lua",
    "Core/Events.lua",
    "Data/TrainerCache.lua",
    "Data/SkillList.lua",
    "Data/NextLevel.lua",
    "Data/RankChanges.lua",
    "Data/SpellFacts.lua",
    "UI/AutoHide.lua",
    "UI/ScrollBox.lua",
    "UI/SkillRow.lua",
    "UI/SkillGroup.lua",
    "UI/Layout.lua",
    "UI/GainLines.lua",
    "UI/NextLevelLine.lua",
  }) do
    assert(loadfile(file))("LevelUpInfo", ns)
  end
  Window = assert(loadfile("UI/Window.lua"))("LevelUpInfo", ns)
  Window.Install(db)
  ns.SpellFacts.Install(Window.Refresh)
end

local function record()
  return { fromLevel = 9, toLevel = 10, gains = { health = 15 }, before = { health = 100 } }
end

local function content()
  for _, widget in ipairs(W.frames) do
    if widget:GetParent() == _G.LevelUpInfoFrame and W.state(widget).frameType == "ScrollFrame" then
      return widget:GetScrollChild()
    end
  end
end

-- Every font string on the content frame whose text starts with `Next at`.
local function lines()
  local found = {}
  local parent = content()
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "FontString" and widget:GetParent() == parent then
      if string.find(widget:GetText() or "", LINE_PREFIX, 1, true) == 1 then
        found[#found + 1] = widget
      end
    end
  end
  return found
end

local function nextLine()
  for _, line in ipairs(lines()) do
    if line:IsShown() then
      return line
    end
  end
end

local function lineCount()
  return #lines()
end

local function offset(widget)
  return -select(5, widget:GetPoint())
end

local function contentHeight()
  return content():GetHeight()
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

-- Every later fill fails inside `guarded`; the error is swallowed.
local function breakFill()
  W.def("geterrorhandler", function()
    return function() end
  end)
  W.def("debugstack", function()
    return ""
  end)
  W.def("GetMoney", function()
    error("boom")
  end)
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

local function test_line_sits_last_with_the_14px_gap()
  setup()
  Window.Show(record())
  local line, row = nextLine(), rowNamed("Mind Blast")
  Assert.equal(line:GetText(), "Next at 14: Fade (Rank 1), Renew (Rank 1)")
  Assert.equal(offset(line) - offset(row), row:GetHeight() + GROUP_GAP)
end

local function test_no_line_when_nothing_is_cached_above()
  setup()
  levels[14] = nil
  Window.Show(record())
  Assert.equal(nextLine(), nil)
end

local function test_line_alone_sits_at_the_top_with_no_gap()
  setup()
  levels[10] = nil
  Window.Show({ fromLevel = 9, toLevel = 10, gains = {}, before = {} })
  Assert.equal(offset(nextLine()), 0)
  Assert.equal(contentHeight(), LINE_HEIGHT)
end

local function test_content_height_includes_the_line_and_its_gap()
  setup()
  Window.Show(record())
  local withLine = contentHeight()
  levels[14] = nil
  Window.Show(record())
  Assert.equal(withLine - contentHeight(), LINE_HEIGHT + GROUP_GAP)
end

local function test_line_follows_the_hint_row()
  setup()
  db.trainers.PRIEST.covered.Scourge = 9
  Window.Show(record())
  local hint = rowNamed(HINT)
  Assert.equal(offset(nextLine()) - offset(hint), hint:GetHeight() + GROUP_GAP)
end

-- No gains and no skill groups: only the hint sits above, so the gap comes from the hint alone.
local function test_line_after_a_lone_hint_row_keeps_the_block_gap()
  setup()
  levels[10] = nil
  db.trainers.PRIEST.covered.Scourge = 9
  Window.Show({ fromLevel = 9, toLevel = 10, gains = {}, before = {} })
  local hint = rowNamed(HINT)
  Assert.equal(offset(nextLine()) - offset(hint), hint:GetHeight() + GROUP_GAP)
end

local function test_toggle_refill_keeps_the_line_without_a_new_build()
  setup()
  levels[MISSED_LEVEL] = {}
  for index = 1, 6 do
    local spellID = MISSED_BASE + index
    W.spells[spellID] = { name = "Missed " .. index, iconID = spellID }
    levels[MISSED_LEVEL][spellID] = rank1()
  end
  local builds = countBuilds()
  Window.Show(record())
  local text = nextLine():GetText()
  builds.count = 0
  click(toggle("more"))
  Assert.equal(builds.count, 0)
  Assert.equal(nextLine():GetText(), text)
end

local function test_repeat_show_recomputes_and_reuses_the_string()
  setup()
  Window.Show(record())
  levels[14] = nil
  levels[16] = { [INNER_FIRE] = rank1() }
  Window.Show(record())
  Assert.equal(nextLine():GetText(), "Next at 16: Inner Fire (Rank 1)")
  Assert.equal(lineCount(), 1)
  levels[16] = nil
  Window.Show(record())
  Assert.equal(nextLine(), nil)
  Assert.equal(lineCount(), 1)
end

local function test_fill_error_hides_the_line()
  setup()
  Window.Show(record())
  breakFill()
  Window.Refresh()
  Assert.equal(nextLine(), nil)
end

local function test_rank_wait_rebuild_recomputes_the_line()
  setup()
  levels[10] = { [FADE] = unranked() }
  levels[14] = nil
  W.spells[FADE].description = ""
  Window.Show(record())
  Assert.equal(nextLine(), nil)
  levels[14] = { [INNER_FIRE] = rank1() }
  W.spells[FADE].description = "Spell text."
  W.broadcast(LOAD_EVENT, FADE, true)
  Assert.equal(nextLine():GetText(), "Next at 14: Inner Fire (Rank 1)")
end

local function test_unloaded_rank_text_shows_the_name_and_requests_nothing()
  setup()
  levels[14] = nil
  Window.Show(record())
  local requests = W.calls.RequestLoadSpellData or 0
  levels[14] = { [INNER_FIRE] = unranked() }
  W.spells[INNER_FIRE].description = ""
  Window.Show(record())
  Assert.equal(nextLine():GetText(), "Next at 14: Inner Fire")
  Assert.equal(W.calls.RequestLoadSpellData or 0, requests)
end

return function()
  test_line_sits_last_with_the_14px_gap()
  test_no_line_when_nothing_is_cached_above()
  test_line_alone_sits_at_the_top_with_no_gap()
  test_content_height_includes_the_line_and_its_gap()
  test_line_follows_the_hint_row()
  test_line_after_a_lone_hint_row_keeps_the_block_gap()
  test_toggle_refill_keeps_the_line_without_a_new_build()
  test_repeat_show_recomputes_and_reuses_the_string()
  test_fill_error_hides_the_line()
  test_rank_wait_rebuild_recomputes_the_line()
  test_unloaded_rank_text_shows_the_name_and_requests_nothing()
end
