local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local ns
local Window
local db

local MISSED_LEVEL = 5
local MISSED_BASE = 1000
local WEAPON_BASE = 2000
local KNOWN_RANK_OFFSET = 100000
local SOURCE_ROW_HEIGHT = 59
local ROW_GAP = 4
local TOGGLE_HEIGHT = 16
local CAP = 5
local RANK_1 = 589
local RANK_2 = 594
local HEADING_FONT = "GameFontNormalLarge"
local PLUS_ICON = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS_ICON = "Interface\\Buttons\\UI-MinusButton-Up"
local FOLDED_HEIGHT_SAVED = CAP * SOURCE_ROW_HEIGHT + (CAP - 1) * ROW_GAP + TOGGLE_HEIGHT

-- Fresh fake client, modules and db per test. The priest cache starts empty and
-- covers level 10 (no hint row); ns.OtherSources is this test's fixture.
local function setup(otherSources)
  W = Wow.Install()
  W.money = 1000
  db = {
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
    foldedGroups = {},
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
  ns.SpellFacts.Install(Window.Refresh)
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
    if widget:GetParent() == frame() and W.state(widget).frameType == "ScrollFrame" then
      return widget:GetScrollChild()
    end
  end
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

local function shownScrollBoxes()
  local count = 0
  for _, widget in ipairs(W.frames) do
    -- The window's own view (a child of the frame) is always shown; skip it.
    if W.state(widget).frameType == "ScrollFrame" and widget:IsShown() and widget:GetParent() ~= frame() then
      count = count + 1
    end
  end
  return count
end

-- Shown fold buttons in build order: Not yet learned, then Weapon skills.
local function foldButtons()
  local buttons = {}
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "Button" and widget.foldIcon and widget:IsShown() then
      buttons[#buttons + 1] = widget
    end
  end
  return buttons
end

-- The shown heading whose text starts with `prefix`.
local function headingWidget(prefix)
  for _, widget in ipairs(W.frames) do
    local stub = W.state(widget)
    if stub.frameType == "FontString" and stub.template == HEADING_FONT and stub.shown then
      if string.sub(widget:GetText() or "", 1, #prefix) == prefix then
        return widget
      end
    end
  end
end

local function headingText(prefix)
  local heading = headingWidget(prefix)
  return heading and heading:GetText()
end

local function topOf(region)
  return select(5, region:GetPoint(1))
end

local function iconOf(button)
  return W.state(button.foldIcon).texture
end

-- description "" makes SpellFacts request text; the stub's default never would.
local function waitingRank()
  W.spells[RANK_1] = { name = "Shadow Word: Pain", iconID = 1, description = "", costs = { { cost = 25, name = "MANA" } } }
  W.spells[RANK_2] = { name = "Shadow Word: Pain", iconID = 1, description = "", costs = { { cost = 50, name = "MANA" } } }
  W.known[RANK_1] = true
  trainerSpell(RANK_1, 4, "Shadow Word: Pain", "Rank 1")
  trainerSpell(RANK_2, 6, "Shadow Word: Pain", "Rank 2")
end

local function test_folding_hides_rows_and_toggle_and_shows_count()
  setupWeapons(6)
  Window.Show(record())
  local open = frame():GetHeight()
  click(foldButtons()[1])
  Assert.equal(#allRows(), 0)
  Assert.equal(toggle("more"), nil)
  Assert.equal(headingText("Weapon skills"), "Weapon skills (6)")
  Assert.equal(open - frame():GetHeight(), FOLDED_HEIGHT_SAVED)
  Assert.equal(iconOf(foldButtons()[1]), PLUS_ICON)
end

local function test_unfolding_restores_capped_view()
  setupWeapons(6)
  Window.Show(record())
  click(foldButtons()[1])
  click(foldButtons()[1])
  Assert.equal(#allRows(), CAP)
  Assert.equal(toggle("more") ~= nil, true)
  Assert.equal(headingText("Weapon skills"), "Weapon skills")
  Assert.equal(iconOf(foldButtons()[1]), MINUS_ICON)
  Assert.equal(db.foldedGroups.weapon, nil)
end

local function test_new_show_keeps_fold_and_resets_expansion()
  setupWeapons(6)
  addMissed(8)
  Window.Show(record())
  click(toggle("not yet learned"))
  click(foldButtons()[2])
  Window.Show(record())
  Assert.equal(db.foldedGroups.weapon, true)
  Assert.equal(rowNamed("Weapon 1"), nil)
  Assert.equal(rowNamed("Missed 1"):GetParent(), content())
  Assert.equal(toggle("more").label:GetText(), "+3 more not yet learned")
end

local function test_folded_state_from_saved_data_applies_on_first_show()
  setup()
  db.foldedGroups.missed = true
  addMissed(2)
  Window.Show(record())
  Assert.equal(#allRows(), 0)
  Assert.equal(headingText("Not yet learned"), "Not yet learned (2)")
end

local function test_folding_a_boxed_group_resets_scroll_and_unfolds_capped()
  setup()
  addMissed(8)
  Window.Show(record())
  click(toggle("not yet learned"))
  local box = rowNamed("Missed 1"):GetParent():GetParent()
  W.fireScript(box, "OnMouseWheel", -1)
  click(foldButtons()[1])
  Assert.equal(shownScrollBoxes(), 0)
  Assert.equal(box:GetVerticalScroll(), 0)
  click(foldButtons()[1])
  Assert.equal(rowNamed("Missed 1"):GetParent(), content())
  Assert.equal(#allRows(), CAP)
  Assert.equal(toggle("more") ~= nil, true)
end

local function test_empty_group_has_no_fold_button_and_keeps_fold()
  setup()
  db.foldedGroups.missed = true
  Window.Show(record())
  Assert.equal(#foldButtons(), 0)
  Assert.equal(db.foldedGroups.missed, true)
  Assert.equal(headingText("Not yet learned"), nil)
end

local function test_fold_button_hides_when_group_empties()
  setup()
  addMissed(2)
  Window.Show(record())
  Assert.equal(#foldButtons(), 1)
  _G.wipe(db.trainers.PRIEST.levels)
  Window.Show(record())
  Assert.equal(#foldButtons(), 0)
  Assert.equal(headingText("Not yet learned"), nil)
end

local function test_stale_fold_flag_on_a_non_foldable_group_is_ignored()
  setup()
  db.foldedGroups.skill = true
  trainerSpell(11, 10, "New Skill", "Rank 1")
  Window.Show(record())
  Assert.equal(rowNamed("New Skill") ~= nil, true)
  Assert.equal(headingText("New skills"), "New skills")
end

local function test_heading_click_without_a_live_record_changes_nothing()
  setup()
  addMissed(8)
  Window.Show(record())
  click(toggle("not yet learned"))
  local shown = #allRows()
  W.fireScript(frame(), "OnHide")
  click(foldButtons()[1])
  Assert.equal(next(db.foldedGroups), nil)
  Assert.equal(#allRows(), shown)
  Assert.equal(shownScrollBoxes(), 1)
end

local function test_fold_icon_sits_at_the_top_right_of_its_button()
  setup()
  addMissed(2)
  Window.Show(record())
  local button = foldButtons()[1]
  local point, relativeTo, relativePoint = button.foldIcon:GetPoint(1)
  Assert.equal(point, "TOPRIGHT")
  Assert.equal(relativeTo, button)
  Assert.equal(relativePoint, "TOPRIGHT")
end

local function test_only_two_groups_fold()
  setupWeapons(1)
  trainerSpell(11, 10, "New Skill", "Rank 1")
  trainerSpell(12, 10, "New Rank", "Rank 2")
  addMissed(1)
  Window.Show(record())
  Assert.equal(headingText("New skills"), "New skills")
  Assert.equal(headingText("New ranks"), "New ranks")
  Assert.equal(#foldButtons(), 2)
end

local function test_folded_rows_request_no_spell_text()
  setup()
  db.foldedGroups.missed = true
  waitingRank()
  Window.Show(record())
  Assert.equal(W.calls.RequestLoadSpellData, nil)
  click(foldButtons()[1])
  Assert.equal(W.calls.RequestLoadSpellData, 2)
end

local function test_spell_text_after_folding_stays_folded()
  setup()
  waitingRank()
  Window.Show(record())
  Assert.equal(#allRows(), 1)
  click(foldButtons()[1])
  Window.Refresh(RANK_2)
  Window.Refresh()
  Assert.equal(#allRows(), 0)
end

local function test_block_gap_stays_under_a_folded_group()
  setupWeapons(2)
  addMissed(2)
  db.foldedGroups.missed = true
  Window.Show({ fromLevel = 9, toLevel = 10, gains = {}, before = {} })
  local heading = headingWidget("Weapon skills")
  Assert.equal(topOf(heading), -38)
  Assert.equal(topOf(foldButtons()[2]), topOf(heading))
end

local function test_fold_button_pauses_countdown()
  setup()
  addMissed(2)
  Window.Show(record())
  local button = foldButtons()[1]
  Assert.equal(W.liveTimers, 1)
  W.fireScript(button, "OnEnter")
  Assert.equal(W.liveTimers, 0)
  W.fireScript(button, "OnLeave")
  Assert.equal(W.liveTimers, 1)
end

local function test_failed_fill_hides_fold_buttons()
  setup()
  addMissed(2)
  Window.Show(record())
  Assert.equal(#foldButtons(), 1)
  W.def("geterrorhandler", function()
    return function() end
  end)
  W.def("debugstack", function()
    return ""
  end)
  W.def("GetMoney", function()
    error("boom")
  end)
  Window.Show(record())
  Assert.equal(#foldButtons(), 0)
end

local function test_heading_click_pins_top_edge()
  setup()
  addMissed(2)
  db.scale = 1.5
  Window.Show(record())
  W.state(frame()).left = 100
  W.state(frame()).top = 600
  W.state(_G.UIParent).top = 768
  click(foldButtons()[1])
  local point, relativeTo, relativePoint, x, y = frame():GetPoint(1)
  Assert.equal(point, "TOPLEFT")
  Assert.equal(relativeTo, _G.UIParent)
  Assert.equal(relativePoint, "TOPLEFT")
  Assert.equal(x, 100)
  Assert.equal(y, 88)
  Assert.equal(db.position, nil)
end

local function test_next_show_applies_saved_anchor()
  setup()
  addMissed(2)
  Window.Show(record())
  click(foldButtons()[1])
  Window.Show(record())
  local point, _, relativePoint, x, y = frame():GetPoint(1)
  Assert.equal(point, "CENTER")
  Assert.equal(relativePoint, "CENTER")
  Assert.equal(x, 0)
  Assert.equal(y, 120)
end

return function()
  test_folding_hides_rows_and_toggle_and_shows_count()
  test_unfolding_restores_capped_view()
  test_new_show_keeps_fold_and_resets_expansion()
  test_folded_state_from_saved_data_applies_on_first_show()
  test_folding_a_boxed_group_resets_scroll_and_unfolds_capped()
  test_empty_group_has_no_fold_button_and_keeps_fold()
  test_fold_button_hides_when_group_empties()
  test_stale_fold_flag_on_a_non_foldable_group_is_ignored()
  test_heading_click_without_a_live_record_changes_nothing()
  test_fold_icon_sits_at_the_top_right_of_its_button()
  test_only_two_groups_fold()
  test_folded_rows_request_no_spell_text()
  test_spell_text_after_folding_stays_folded()
  test_block_gap_stays_under_a_folded_group()
  test_fold_button_pauses_countdown()
  test_failed_fill_hides_fold_buttons()
  test_heading_click_pins_top_edge()
  test_next_show_applies_saved_anchor()
end
