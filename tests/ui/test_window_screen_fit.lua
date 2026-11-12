local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local Window
local db

local KNOWN_PAIN_1 = 100589
-- Frame units: header 68 + footer 12, and 2 * 16 screen margin for the full cap.
local CHROME = 68 + 12
local MARGINS = 2 * 16

local function spell(cost, rank)
  return { cost = cost, rank = rank, races = { Scourge = true } }
end

-- Fresh fake client, modules and db per test. Priest cache at level 10:
-- Mind Blast (skill), Renew (skill), Shadow Word: Pain Rank 2 (rank; Rank 1 known).
local function setup()
  W = Wow.Install()
  W.money = 1000
  W.spells[8092] = { name = "Mind Blast", iconID = 136224 }
  W.spells[139] = { name = "Renew", iconID = 135953 }
  W.spells[589] = { name = "Shadow Word: Pain", iconID = 136207 }
  W.spells[KNOWN_PAIN_1] = { name = "Shadow Word: Pain", iconID = 136207 }
  W.known[KNOWN_PAIN_1] = true
  db = {
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
    foldedGroups = {},
    trainers = {
      PRIEST = {
        covered = { Scourge = 10 },
        levels = { [10] = { [8092] = spell(300, "Rank 1"), [139] = spell(100, "Rank 1"), [589] = spell(50, "Rank 2") } },
      },
    },
  }
  local ns = { OtherSources = {} }
  for _, file in ipairs({
    "Core/Localization.lua",
    "Core/Format.lua",
    "Core/Events.lua",
    "Data/TrainerCache.lua",
    "Data/SkillList.lua",
    "Data/RankChanges.lua",
    "Data/SpellFacts.lua",
    "UI/AutoHide.lua",
    "UI/ScrollBox.lua",
    "UI/SkillRow.lua",
    "UI/SkillGroup.lua",
    "UI/Layout.lua",
    "UI/GainLines.lua",
  }) do
    assert(loadfile(file))("LevelUpInfo", ns)
  end
  Window = assert(loadfile("UI/Window.lua"))("LevelUpInfo", ns)
  Window.Install(db)
end

local function record()
  return {
    fromLevel = 9,
    toLevel = 10,
    gains = { health = 15, power = 0, talents = 0, strength = 0, agility = 0, stamina = 1, intellect = 0, spirit = 0 },
    before = { health = 100, stamina = 25 },
  }
end

local function frame()
  return _G.LevelUpInfoFrame
end

local function childOf(parent, frameType)
  for _, widget in ipairs(W.frames) do
    if widget:GetParent() == parent and W.state(widget).frameType == frameType then
      return widget
    end
  end
end

local function view()
  return childOf(frame(), "ScrollFrame")
end

local function viewBar()
  return childOf(view(), "Slider")
end

local function contentHeight()
  return view():GetScrollChild():GetHeight()
end

local function width()
  return (frame():GetSize())
end

local function maxValue()
  return select(2, viewBar():GetMinMaxValues())
end

local function screen(height)
  _G.UIParent:SetHeight(height)
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

local function test_window_is_clamped_to_screen()
  setup()
  Window.Show(record())
  Assert.equal(frame():IsClampedToScreen(), true)
end

-- The clamp rect reaches 16 above and below the frame, so the clamp keeps
-- that margin to the screen edges too.
local function test_clamp_keeps_the_screen_margin()
  setup()
  Window.Show(record())
  local left, right, top, bottom = frame():GetClampRectInsets()
  Assert.equal(left, 0)
  Assert.equal(right, 0)
  Assert.equal(top, 16)
  Assert.equal(bottom, -16)
end

local function test_view_holds_content()
  setup()
  Window.Show(record())
  Assert.equal(view():GetWidth(), 310)
  Assert.equal(view():GetScrollChild():GetWidth(), 298)
  Assert.equal(view():IsMouseEnabled(), false)
end

local function test_short_content_keeps_today_size()
  setup()
  Window.Show(record())
  Assert.equal(width(), 338)
  Assert.equal(frame():GetHeight(), CHROME + contentHeight())
  Assert.equal(viewBar():IsShown(), false)
  Assert.equal(view():IsMouseWheelEnabled(), false)
end

local function test_tall_content_caps_the_frame()
  setup()
  screen(300)
  Window.Show(record())
  Assert.equal(frame():GetHeight(), 0.6 * 300)
  Assert.equal(width(), 350)
  Assert.equal(viewBar():IsShown(), true)
  Assert.equal(viewBar():GetHeight(), 0.6 * 300 - CHROME)
  Assert.equal(view():IsMouseWheelEnabled(), true)
  Assert.equal(maxValue(), contentHeight() - (0.6 * 300 - CHROME))
end

-- Content 277 overflows the 1.5 cap (100) and the 1.0 cap (190): scaling
-- after the fill would give 270.
local function test_first_show_uses_the_saved_scale()
  setup()
  screen(450)
  db.scale = 1.5
  Window.Show(record())
  Assert.equal(frame():GetHeight(), 0.6 * 450 / 1.5)
end

local function test_show_scrolls_the_view_to_top()
  setup()
  screen(300)
  Window.Show(record())
  viewBar():SetValue(40)
  Assert.equal(view():GetVerticalScroll(), 40)
  Window.Show(record())
  Assert.equal(view():GetVerticalScroll(), 0)
end

local function test_refresh_keeps_the_view_scroll()
  setup()
  screen(300)
  Window.Show(record())
  viewBar():SetValue(40)
  Window.Refresh(nil)
  Assert.equal(view():GetVerticalScroll(), 40)
end

local function test_refresh_that_fits_resets_scroll_and_width()
  setup()
  screen(300)
  Window.Show(record())
  viewBar():SetValue(40)
  screen(768)
  Window.Refresh(nil)
  Assert.equal(view():GetVerticalScroll(), 0)
  Assert.equal(width(), 338)
  Assert.equal(viewBar():IsShown(), false)
  Assert.equal(view():IsMouseWheelEnabled(), false)
end

local function test_apply_scale_replaces_with_new_cap()
  setup()
  screen(450)
  Window.Show(record())
  Assert.equal(frame():GetHeight(), 0.6 * 450)
  db.scale = 1.5
  Window.ApplyScale()
  Assert.equal(frame():GetHeight(), 0.6 * 450 / 1.5)
end

local function test_apply_scale_while_hidden_does_not_place()
  setup()
  Window.ApplyScale()
  Assert.equal(Window.Frame(), nil)
  screen(450)
  Window.Show(record())
  Assert.equal(frame():GetHeight(), 0.6 * 450)
  frame():Hide()
  db.scale = 1.5
  Window.ApplyScale()
  Assert.equal(frame():GetScale(), 1.5)
  Assert.equal(frame():GetHeight(), 0.6 * 450)
end

local function test_apply_scale_while_stale_does_not_place()
  setup()
  screen(450)
  Window.Show(record())
  Assert.equal(frame():GetHeight(), 0.6 * 450)
  breakFill()
  Window.Show(record())
  Assert.equal(frame():IsShown(), true)
  db.scale = 1.5
  Window.ApplyScale()
  Assert.equal(frame():GetScale(), 1.5)
  Assert.equal(frame():GetHeight(), 0.6 * 450)
end

-- Content 277 is taller than the 60% cap (screen 450 / scale 1.5 = 300 frame
-- units: 0.6 * 300 = 180 less the chrome): the frame stops at 180.
local function test_tall_content_stops_at_sixty_percent_of_the_screen()
  setup()
  screen(450)
  db.scale = 1.5
  Window.Show(record())
  Assert.equal(frame():GetHeight(), 0.6 * 450 / 1.5)
  Assert.equal(viewBar():IsShown(), true)
  Assert.equal(view():IsMouseWheelEnabled(), true)
end

-- Screen 600 at scale 1: the 60% cap is 360 - 80 = 280 of view; content 277 fits.
local function test_content_shorter_than_the_cap_has_no_view_bar()
  setup()
  screen(600)
  Window.Show(record())
  Assert.equal(contentHeight(), 277)
  Assert.equal(viewBar():IsShown(), false)
  Assert.equal(width(), 338)
  Assert.equal(frame():GetHeight(), CHROME + 277)
end

local MISSED_BASE = 1000

-- Eight rank-1 spells at level 5 fill the "Not yet learned" group (content 531).
local function addMissed()
  for index = 1, 8 do
    W.spells[MISSED_BASE + index] = { name = "Missed " .. index, iconID = MISSED_BASE + index }
    db.trainers.PRIEST.levels[5] = db.trainers.PRIEST.levels[5] or {}
    db.trainers.PRIEST.levels[5][MISSED_BASE + index] = spell(10, "Rank 1")
  end
end

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

local function click(text)
  W.fireScript(toggle(text), "OnClick")
end

local function viewHeight()
  return view():GetHeight()
end

-- Screen 600 at scale 1.5 is 400 frame units: shortCap 160, fullCap 288. An
-- expanded box of plain rows is 4 * 47 + 3 * 4 = 200 tall and lifts the cap to it.
local function test_expanded_box_lifts_the_cap_and_collapsing_restores_it()
  setup()
  screen(600)
  db.scale = 1.5
  addMissed()
  Window.Show(record())
  Assert.equal(contentHeight(), 531)
  Assert.equal(viewHeight(), 160)
  click("not yet learned")
  Assert.equal(viewHeight(), 200)
  Assert.equal(frame():GetHeight(), CHROME + 200)
  click("Show less")
  Assert.equal(viewHeight(), 160)
  Assert.equal(frame():GetHeight(), CHROME + 160)
end

-- Screen 300 at scale 1: fullCap 188 is below the 200 box, so it wins.
local function test_box_taller_than_the_full_cap_stops_at_the_full_cap()
  setup()
  screen(300)
  addMissed()
  Window.Show(record())
  click("not yet learned")
  Assert.equal(viewHeight(), 188)
  Assert.equal(frame():GetHeight(), 300 - MARGINS)
end

local RANK_BASE = 3000

local function rankFacts(spellID, damage, cost)
  W.spells[spellID].description = "Deals " .. damage .. " Shadow damage over 18 sec."
  W.spells[spellID].costs = { { cost = cost, name = "MANA" } }
end

-- Five more Rank 2 spells at level 10 over a known Rank 1 at level 4. With
-- Shadow Word: Pain the "New ranks" group has six rows, each with a text and
-- a cost change line: 59 tall.
local function addRanks()
  rankFacts(KNOWN_PAIN_1, 30, 25)
  rankFacts(589, 66, 50)
  db.trainers.PRIEST.levels[4] = {}
  for index = 1, 5 do
    local name = "Ranked " .. index
    local old, new = RANK_BASE + index, RANK_BASE + 100 + index
    W.spells[old] = { name = name, iconID = old }
    W.spells[new] = { name = name, iconID = new }
    rankFacts(old, 30, 25)
    rankFacts(new, 66, 50)
    W.known[old] = true
    db.trainers.PRIEST.levels[4][old] = spell(10, "Rank 1")
    db.trainers.PRIEST.levels[10][new] = spell(10, "Rank 2")
  end
end

-- Screen 600 at scale 1.5: shortCap 160, fullCap 288. The ranks box is
-- 4 * 59 + 3 * 4 = 248, the later "Not yet learned" box 200: the taller one
-- sets the floor, whichever box is fitted last.
local function test_tallest_expanded_box_sets_the_floor()
  setup()
  screen(600)
  db.scale = 1.5
  addMissed()
  addRanks()
  Window.Show(record())
  click("new ranks")
  click("not yet learned")
  Assert.equal(viewHeight(), 248)
  Assert.equal(frame():GetHeight(), CHROME + 248)
end

local function test_fill_error_hides_the_view_bar()
  setup()
  screen(300)
  Window.Show(record())
  Assert.equal(viewBar():IsShown(), true)
  breakFill()
  Window.Show(record())
  Assert.equal(viewBar():IsShown(), false)
  Assert.equal(view():IsMouseWheelEnabled(), false)
end

return function()
  test_window_is_clamped_to_screen()
  test_clamp_keeps_the_screen_margin()
  test_view_holds_content()
  test_short_content_keeps_today_size()
  test_tall_content_caps_the_frame()
  test_first_show_uses_the_saved_scale()
  test_show_scrolls_the_view_to_top()
  test_refresh_keeps_the_view_scroll()
  test_refresh_that_fits_resets_scroll_and_width()
  test_apply_scale_replaces_with_new_cap()
  test_apply_scale_while_hidden_does_not_place()
  test_apply_scale_while_stale_does_not_place()
  test_tall_content_stops_at_sixty_percent_of_the_screen()
  test_content_shorter_than_the_cap_has_no_view_bar()
  test_expanded_box_lifts_the_cap_and_collapsing_restores_it()
  test_box_taller_than_the_full_cap_stops_at_the_full_cap()
  test_tallest_expanded_box_sets_the_floor()
  test_fill_error_hides_the_view_bar()
end
