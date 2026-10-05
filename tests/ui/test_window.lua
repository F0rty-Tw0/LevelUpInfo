local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local Window
local db

local function spell(cost, rank)
  return { cost = cost, rank = rank, races = { Scourge = true } }
end

-- Fresh fake client, modules and db per test. Priest cache at level 10:
-- Mind Blast (skill), Renew (skill), Shadow Word: Pain Rank 2 (rank).
local function setup()
  W = Wow.Install()
  W.money = 1000
  W.spells[8092] = { name = "Mind Blast", iconID = 136224 }
  W.spells[139] = { name = "Renew", iconID = 135953 }
  W.spells[589] = { name = "Shadow Word: Pain", iconID = 136207 }
  db = {
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
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
    "Data/TrainerCache.lua",
    "Data/SkillList.lua",
    "UI/AutoHide.lua",
    "UI/SkillRow.lua",
  }) do
    assert(loadfile(file))("LevelUpInfo", ns)
  end
  Window = assert(loadfile("UI/Window.lua"))("LevelUpInfo", ns)
  Window.Install(db)
end

local function record(overrides)
  local result = {
    fromLevel = 9,
    toLevel = 10,
    gains = { health = 15, power = 0, talents = 0, strength = 0, agility = 0, stamina = 1, intellect = 0, spirit = 0 },
    before = { health = 100, stamina = 25 },
  }
  for key, value in pairs(overrides or {}) do
    result[key] = value
  end
  return result
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

-- Shown texts of the content's own font strings with this font, in pool order.
local function lines(template)
  local texts = {}
  for _, widget in ipairs(W.frames) do
    local stub = W.state(widget)
    if stub.frameType == "FontString" and widget:GetParent() == content() and stub.template == template and stub.shown then
      texts[#texts + 1] = widget:GetText()
    end
  end
  return texts
end

local function shownRows()
  local rows = {}
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "Button" and widget:GetParent() == content() and widget:IsShown() then
      rows[#rows + 1] = widget
    end
  end
  return rows
end

local function rowNames()
  local names = {}
  for _, row in ipairs(shownRows()) do
    names[#names + 1] = row.name:GetText()
  end
  return table.concat(names, "|")
end

local HINT = "Visit your class trainer to see all new skills."

local function test_no_frame_exists_before_first_show()
  setup()
  Assert.equal(_G.LevelUpInfoFrame, nil)
  Assert.equal(Window.Frame(), nil)
  Assert.equal(Window.Current(), nil)
end

local function test_apply_and_reset_before_first_show_do_not_build_or_error()
  setup()
  db.position = { point = "TOP", x = 1, y = 2 }
  Window.ApplyScale()
  Window.ResetPosition()
  Assert.equal(db.position, nil)
  Assert.equal(_G.LevelUpInfoFrame, nil)
end

local function test_show_builds_named_frame_with_portrait_and_title()
  setup()
  Window.Show(record())
  Assert.equal(_G.LevelUpInfoFrame, Window.Frame())
  Assert.equal(W.state(frame()).template, "ButtonFrameTemplate")
  Assert.equal(W.state(frame()).portraitUnit, "player")
  Assert.equal(W.state(frame()).title, "Level 10")
  Assert.equal(W.calls.ButtonFrameTemplate_HideButtonBar, 1)
  Assert.equal(frame():GetParent(), _G.UIParent)
  Assert.equal(({ frame():GetSize() })[1], 338)
  Assert.equal(frame():IsMouseEnabled(), true)
end

local function test_gains_lines_in_spec_order_skip_zeros()
  setup()
  Window.Show(record())
  Assert.equal(table.concat(lines("GameFontHighlight"), "|"), "Health 100 → 115|Stamina 25 → 26")
end

local function test_talents_and_missing_before_use_plus_format()
  setup()
  Window.Show(record({
    gains = { health = 15, talents = 1 },
    before = { health = nil },
  }))
  Assert.equal(table.concat(lines("GameFontHighlight"), "|"), "+15 Health|+1 Talent points")
end

local function test_skill_rows_and_hint_follow_skill_list()
  setup()
  db.trainers.PRIEST.covered.Scourge = 9
  Window.Show(record({ fromLevel = 9, toLevel = 10 }))
  Assert.equal(rowNames(), "Mind Blast|Renew|Shadow Word: Pain|" .. HINT)
  local first = shownRows()[1]
  Assert.equal(first.price:GetText(), "300c")
end

local function test_new_skills_and_new_ranks_get_headings()
  setup()
  db.trainers.PRIEST.levels[10][139] = nil
  Window.Show(record())
  Assert.equal(table.concat(lines("GameFontNormal"), "|"), "New skills|New ranks")
  Assert.equal(rowNames(), "Mind Blast|Shadow Word: Pain")
end

local function test_heading_hidden_for_an_empty_group()
  setup()
  db.trainers.PRIEST.levels[10][8092] = nil
  db.trainers.PRIEST.levels[10][139] = nil
  Window.Show(record())
  Assert.equal(table.concat(lines("GameFontNormal"), "|"), "New ranks")
end

local function test_reshow_without_ranks_hides_new_ranks_heading()
  setup()
  db.trainers.PRIEST.levels[10][139] = nil
  Window.Show(record())
  db.trainers.PRIEST.levels[10][589] = nil
  Window.Show(record())
  Assert.equal(table.concat(lines("GameFontNormal"), "|"), "New skills")
end

local function test_no_skills_and_no_hint_hides_skills_section()
  setup()
  db.trainers.PRIEST.covered.Scourge = 11
  Window.Show(record({ fromLevel = 10, toLevel = 11 }))
  Assert.equal(#lines("GameFontNormal"), 0)
  Assert.equal(#shownRows(), 0)
end

local function test_height_fits_content()
  setup()
  Window.Show(record())
  local withThreeRows = frame():GetHeight()
  db.trainers.PRIEST.levels[10][139] = nil
  Window.Show(record())
  local withTwoRows = frame():GetHeight()
  Assert.equal(withTwoRows < withThreeRows, true)
  db.trainers.PRIEST.levels[10][8092] = spell(300, "Rank 1")
  db.trainers.PRIEST.levels[10][139] = spell(100, "Rank 1")
  db.trainers.PRIEST.covered.Scourge = 9
  Window.Show(record())
  Assert.equal(frame():GetHeight() > withThreeRows, true)
end

local function test_repeat_show_with_fewer_rows_creates_no_frames()
  setup()
  Window.Show(record())
  local frameCount = #W.frames
  db.trainers.PRIEST.levels[10][139] = nil
  db.trainers.PRIEST.levels[10][589] = nil
  Window.Show(record({ gains = { health = 15 } }))
  Assert.equal(#W.frames, frameCount)
  Assert.equal(#shownRows(), 1)
  Assert.equal(#lines("GameFontHighlight"), 1)
end

local function test_show_starts_the_countdown()
  setup()
  Window.Show(record())
  Assert.equal(W.liveTimers, 1)
  Assert.equal(W.lastTimerSeconds, 10)
end

local function test_show_and_reshow_keep_exactly_one_live_timer()
  setup()
  Window.Show(record())
  Assert.equal(W.liveTimers, 1)
  Window.Show(record())
  Assert.equal(W.liveTimers, 1)
  frame():Hide()
  Window.Show(record())
  Assert.equal(W.liveTimers, 1)
end

local function test_close_x_hides_and_cancels_countdown()
  setup()
  Window.Show(record())
  W.fireScript(frame().CloseButton, "OnClick")
  Assert.equal(frame():IsShown(), false)
  Assert.equal(W.liveTimers, 0)
end

local function test_hovering_a_row_pauses_the_countdown()
  setup()
  Window.Show(record())
  W.fireScript(shownRows()[1], "OnEnter")
  Assert.equal(W.liveTimers, 0)
  W.fireScript(shownRows()[1], "OnLeave")
  Assert.equal(W.liveTimers, 1)
end

local function test_reshow_while_hovered_keeps_window_and_starts_no_countdown()
  setup()
  Window.Show(record())
  W.mouseOver[frame()] = true
  Window.Show(record())
  Assert.equal(frame():IsShown(), true)
  Assert.equal(frame():GetAlpha(), 1)
  Assert.equal(W.liveTimers, 0)
end

local function test_default_anchor_and_saved_position()
  setup()
  Window.Show(record())
  local point, relativeTo, relativePoint, x, y = frame():GetPoint()
  Assert.equal(table.concat({ point, relativePoint, x, y }, ","), "CENTER,CENTER,0,120")
  Assert.equal(relativeTo, _G.UIParent)
  db.position = { point = "TOPLEFT", x = 30, y = -40 }
  Window.Show(record())
  Assert.equal(frame():GetNumPoints(), 1)
  point, _, relativePoint, x, y = frame():GetPoint()
  Assert.equal(table.concat({ point, relativePoint, x, y }, ","), "TOPLEFT,TOPLEFT,30,-40")
end

local function test_drag_stop_saves_position()
  setup()
  Window.Show(record())
  Assert.equal(W.state(frame()).movable, true)
  W.fireScript(frame(), "OnDragStart")
  Assert.equal(W.state(frame()).moving, true)
  W.dropAt = { point = "BOTTOMLEFT", x = 55, y = 66 }
  W.fireScript(frame(), "OnDragStop")
  Assert.equal(W.state(frame()).moving, false)
  Assert.equal(db.position.point, "BOTTOMLEFT")
  Assert.equal(db.position.x, 55)
  Assert.equal(db.position.y, 66)
end

local function test_reset_position_moves_now_and_clears_saved()
  setup()
  db.position = { point = "TOPLEFT", x = 30, y = -40 }
  Window.Show(record())
  Window.ResetPosition()
  Assert.equal(db.position, nil)
  local point, _, _, x, y = frame():GetPoint()
  Assert.equal(table.concat({ point, x, y }, ","), "CENTER,0,120")
end

local function test_scale_applies_on_show_and_on_apply()
  setup()
  db.scale = 0.8
  Window.Show(record())
  Assert.equal(frame():GetScale(), 0.8)
  db.scale = 1.25
  Window.ApplyScale()
  Assert.equal(frame():GetScale(), 1.25)
end

local function test_current_is_the_shown_record_and_nil_after_hide()
  setup()
  local shown = record()
  Window.Show(shown)
  Assert.equal(Window.Current(), shown)
  frame():Hide()
  Assert.equal(Window.Current(), nil)
end

local function test_template_onhide_still_runs()
  setup()
  Window.Show(record())
  local before = W.state(frame()).templateHides or 0
  frame():Hide()
  Assert.equal(W.state(frame()).templateHides, before + 1)
  Assert.equal(Window.Current(), nil)
end

return function()
  test_no_frame_exists_before_first_show()
  test_apply_and_reset_before_first_show_do_not_build_or_error()
  test_show_builds_named_frame_with_portrait_and_title()
  test_gains_lines_in_spec_order_skip_zeros()
  test_talents_and_missing_before_use_plus_format()
  test_skill_rows_and_hint_follow_skill_list()
  test_new_skills_and_new_ranks_get_headings()
  test_heading_hidden_for_an_empty_group()
  test_reshow_without_ranks_hides_new_ranks_heading()
  test_no_skills_and_no_hint_hides_skills_section()
  test_height_fits_content()
  test_repeat_show_with_fewer_rows_creates_no_frames()
  test_show_starts_the_countdown()
  test_show_and_reshow_keep_exactly_one_live_timer()
  test_close_x_hides_and_cancels_countdown()
  test_hovering_a_row_pauses_the_countdown()
  test_reshow_while_hovered_keeps_window_and_starts_no_countdown()
  test_default_anchor_and_saved_position()
  test_drag_stop_saves_position()
  test_reset_position_moves_now_and_clears_saved()
  test_scale_applies_on_show_and_on_apply()
  test_current_is_the_shown_record_and_nil_after_hide()
  test_template_onhide_still_runs()
end
