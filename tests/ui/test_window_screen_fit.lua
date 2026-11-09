local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local Window
local db

local KNOWN_PAIN_1 = 100589
-- Frame units: header 68 + footer 12 + 2 * 16 screen margin.
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
  Assert.equal(frame():GetHeight(), 300 - MARGINS)
  Assert.equal(width(), 350)
  Assert.equal(viewBar():IsShown(), true)
  Assert.equal(view():IsMouseWheelEnabled(), true)
  Assert.equal(maxValue(), contentHeight() - (300 - MARGINS - CHROME))
end

-- Content 277 overflows the 1.5 cap (188) but fits the 1.0 cap (338):
-- scaling after the fill would give 357.
local function test_first_show_uses_the_saved_scale()
  setup()
  screen(450)
  db.scale = 1.5
  Window.Show(record())
  Assert.equal(frame():GetHeight(), 450 / 1.5 - MARGINS)
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
  Assert.equal(frame():GetHeight(), 357)
  db.scale = 1.5
  Window.ApplyScale()
  Assert.equal(frame():GetHeight(), 268)
end

local function test_apply_scale_while_hidden_does_not_place()
  setup()
  Window.ApplyScale()
  Assert.equal(Window.Frame(), nil)
  screen(450)
  Window.Show(record())
  Assert.equal(frame():GetHeight(), 357)
  frame():Hide()
  db.scale = 1.5
  Window.ApplyScale()
  Assert.equal(frame():GetScale(), 1.5)
  Assert.equal(frame():GetHeight(), 357)
end

local function test_apply_scale_while_stale_does_not_place()
  setup()
  screen(450)
  Window.Show(record())
  Assert.equal(frame():GetHeight(), 357)
  breakFill()
  Window.Show(record())
  Assert.equal(frame():IsShown(), true)
  db.scale = 1.5
  Window.ApplyScale()
  Assert.equal(frame():GetScale(), 1.5)
  Assert.equal(frame():GetHeight(), 357)
end

local function test_fill_error_hides_the_view_bar()
  setup()
  screen(300)
  Window.Show(record())
  Assert.equal(viewBar():IsShown(), true)
  breakFill()
  Window.Show(record())
  Assert.equal(viewBar():IsShown(), false)
end

return function()
  test_window_is_clamped_to_screen()
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
  test_fill_error_hides_the_view_bar()
end
