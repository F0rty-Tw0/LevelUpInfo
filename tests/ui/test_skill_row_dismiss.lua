-- The row's hide / show button (an eye).
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local SkillRow
local parent
local log
local dismissNames

local ENTRY = { spellID = 8092, name = "Mind Blast", icon = 136224, rank = "Rank 1", cost = 300 }
local HIDDEN_ENTRY = { spellID = 8092, name = "Mind Blast", icon = 1, rank = "", cost = 1, hidden = true }
local EYE_CROSSED = "Interface\\AddOns\\LevelUpInfo\\Media\\EyeCrossed.tga"
local EYE_OPEN = "Interface\\AddOns\\LevelUpInfo\\Media\\EyeOpen.tga"
local QUEST_ENTRY = {
  spellID = 2652,
  name = "Touch of Weakness",
  icon = 136143,
  rank = "",
  source = { kind = "quest", quest = "Q", npc = "N", place = "P" },
}

-- Fresh fake client, module and parent frame per test; onEnter/onLeave log into `log`.
local function setup()
  W = Wow.Install()
  W.money = 1000
  SkillRow = assert(loadfile("UI/SkillRow.lua"))("LevelUpInfo", {})
  parent = _G.CreateFrame("Frame", nil, _G.UIParent)
  log = {}
  dismissNames = {}
end

local function newRow()
  return SkillRow.Create(parent, function()
    log[#log + 1] = "enter"
  end, function()
    log[#log + 1] = "leave"
  end, function(name)
    dismissNames[#dismissNames + 1] = name
  end)
end

local function test_dismiss_is_a_plain_16_by_16_button_at_the_top_right()
  setup()
  local row = newRow()
  local dismiss = row.dismiss
  Assert.equal(W.state(dismiss).frameType, "Button")
  Assert.equal(W.state(dismiss).template, nil)
  Assert.equal(dismiss:GetParent(), row)
  local width, height = dismiss:GetSize()
  Assert.equal(width, 16)
  Assert.equal(height, 16)
  local point, relativeTo, relativePoint, x, y = dismiss:GetPoint()
  Assert.equal(point, "TOPRIGHT")
  Assert.equal(relativeTo, row)
  Assert.equal(relativePoint, "TOPRIGHT")
  Assert.equal(x, -6)
  Assert.equal(y, -6)
  Assert.equal(W.state(dismiss.texture).allPoints, true)
end

-- Hover only (user decision, 2026-11-15): invisible until the row is hovered.
local function test_button_is_invisible_until_the_row_is_hovered()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  Assert.equal(row.dismiss:GetAlpha(), 0)
end

local function test_row_hover_shows_the_button_dim()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row, "OnEnter")
  Assert.equal(row.dismiss:GetAlpha(), 0.6)
end

local function test_leaving_the_row_hides_the_button()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row, "OnEnter")
  W.fireScript(row, "OnLeave")
  Assert.equal(row.dismiss:GetAlpha(), 0)
end

-- Moving onto the button leaves the row, but the mouse is still inside it.
local function test_moving_onto_the_button_keeps_it_shown()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row, "OnEnter")
  W.mouseOver[row] = true
  W.fireScript(row, "OnLeave")
  Assert.equal(row.dismiss:GetAlpha(), 0.6)
end

local function test_leaving_the_button_back_onto_the_row_dims_it()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row.dismiss, "OnEnter")
  W.mouseOver[row] = true
  W.fireScript(row.dismiss, "OnLeave")
  Assert.equal(row.dismiss:GetAlpha(), 0.6)
end

-- Hidden rows always show their Show eye (user decision, 2026-11-15).
local function test_hidden_row_shows_the_eye_dim_without_hover()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, HIDDEN_ENTRY, W.money)
  Assert.equal(row.dismiss:GetAlpha(), 0.6)
end

local function test_leaving_a_hidden_row_keeps_the_eye_dim()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, HIDDEN_ENTRY, W.money)
  W.fireScript(row, "OnEnter")
  W.fireScript(row, "OnLeave")
  Assert.equal(row.dismiss:GetAlpha(), 0.6)
end

local function test_leaving_a_hidden_rows_eye_keeps_it_dim()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, HIDDEN_ENTRY, W.money)
  W.fireScript(row.dismiss, "OnEnter")
  W.fireScript(row.dismiss, "OnLeave")
  Assert.equal(row.dismiss:GetAlpha(), 0.6)
end

local function test_a_shown_row_reused_as_hidden_shows_its_eye()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  SkillRow.SetSkill(row, HIDDEN_ENTRY, W.money)
  Assert.equal(row.dismiss:GetAlpha(), 0.6)
end

local function test_a_hidden_row_reused_as_shown_hides_its_eye()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, HIDDEN_ENTRY, W.money)
  SkillRow.SetSkill(row, ENTRY, W.money)
  Assert.equal(row.dismiss:GetAlpha(), 0)
end

local function test_shown_row_gets_the_crossed_eye_and_no_tint()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  Assert.equal(W.state(row.dismiss.texture).texture, EYE_CROSSED)
  Assert.equal(W.state(row.dismiss.texture).vertexColor, nil)
  Assert.equal(row.hidden, false)
  Assert.equal(row.dismiss:IsShown(), true)
  Assert.equal(row.skillName, "Mind Blast")
end

local function test_hidden_row_gets_the_open_eye_and_no_tint()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, HIDDEN_ENTRY, W.money)
  Assert.equal(W.state(row.dismiss.texture).texture, EYE_OPEN)
  Assert.equal(W.state(row.dismiss.texture).vertexColor, nil)
  Assert.equal(row.hidden, true)
end

local function test_a_reused_row_swaps_its_eye_with_its_entry()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, HIDDEN_ENTRY, W.money)
  SkillRow.SetSkill(row, ENTRY, W.money)
  Assert.equal(W.state(row.dismiss.texture).texture, EYE_CROSSED)
  Assert.equal(W.state(row.dismiss.texture).vertexColor, nil)
end

local function test_dismiss_click_passes_the_rows_current_skill_name()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row.dismiss, "OnClick")
  SkillRow.SetSkill(row, QUEST_ENTRY, W.money)
  W.fireScript(row.dismiss, "OnClick")
  Assert.equal(table.concat(dismissNames, "|"), "Mind Blast|Touch of Weakness")
end

local function test_dismiss_hover_shows_dismiss_tooltip_and_pauses()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row.dismiss, "OnEnter")
  Assert.equal(#W.tooltip, 3)
  Assert.equal(W.tooltip[1][1], "SetOwner")
  Assert.equal(W.tooltip[1][2], row.dismiss)
  Assert.equal(W.tooltip[1][3], "ANCHOR_RIGHT")
  Assert.equal(W.tooltip[2][1], "SetText")
  Assert.equal(W.tooltip[2][2], "Hide")
  Assert.equal(W.tooltip[3][1], "Show")
  Assert.equal(row.dismiss:GetAlpha(), 1)
  Assert.equal(log[1], "enter")
end

local function test_restore_hover_shows_restore_tooltip()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, HIDDEN_ENTRY, W.money)
  W.fireScript(row.dismiss, "OnEnter")
  Assert.equal(W.tooltip[2][1], "SetText")
  Assert.equal(W.tooltip[2][2], "Show")
end

-- Review Focus 1: the row is pooled and refilled; the tooltip reads the new entry.
local function test_reused_row_tooltip_follows_its_new_entry()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  SkillRow.SetSkill(row, HIDDEN_ENTRY, W.money)
  W.fireScript(row.dismiss, "OnEnter")
  Assert.equal(W.tooltip[2][2], "Show")
end

local function test_dismiss_leave_hides_tooltip_and_resumes()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row.dismiss, "OnEnter")
  W.fireScript(row.dismiss, "OnLeave")
  Assert.equal(W.tooltip[#W.tooltip][1], "Hide")
  Assert.equal(row.dismiss:GetAlpha(), 0)
  Assert.equal(log[2], "leave")
end

-- A row pooled while its button was hovered gets no OnLeave before its reuse.
local function test_set_skill_hides_a_hovered_button_again()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row.dismiss, "OnEnter")
  SkillRow.SetSkill(row, QUEST_ENTRY, W.money)
  Assert.equal(row.dismiss:GetAlpha(), 0)
end

local function test_hint_row_hides_the_button_and_clears_the_name()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  SkillRow.SetHint(row)
  Assert.equal(row.dismiss:IsShown(), false)
  Assert.equal(row.skillName, nil)
  SkillRow.SetSkill(row, ENTRY, W.money)
  Assert.equal(row.dismiss:IsShown(), true)
end

local function test_entry_without_a_name_has_no_button()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, { spellID = 1, name = "", icon = 1, rank = "", cost = 1 }, W.money)
  Assert.equal(row.dismiss:IsShown(), false)
end

-- The paths are the game's (relative to the AddOns folder); the files are the
-- addon's own Media textures.
local function test_eye_texture_paths_name_files_the_addon_ships()
  local prefix = "Interface\\AddOns\\LevelUpInfo\\"
  for _, path in ipairs({ EYE_CROSSED, EYE_OPEN }) do
    Assert.equal(string.sub(path, 1, #prefix), prefix)
    local file = string.gsub(string.sub(path, #prefix + 1), "\\", "/")
    local handle = io.open(file, "rb")
    Assert.equal(handle ~= nil, true, "missing " .. file)
    handle:close()
  end
end

return function()
  test_dismiss_is_a_plain_16_by_16_button_at_the_top_right()
  test_shown_row_gets_the_crossed_eye_and_no_tint()
  test_hidden_row_gets_the_open_eye_and_no_tint()
  test_a_reused_row_swaps_its_eye_with_its_entry()
  test_dismiss_click_passes_the_rows_current_skill_name()
  test_dismiss_hover_shows_dismiss_tooltip_and_pauses()
  test_restore_hover_shows_restore_tooltip()
  test_reused_row_tooltip_follows_its_new_entry()
  test_dismiss_leave_hides_tooltip_and_resumes()
  test_set_skill_hides_a_hovered_button_again()
  test_button_is_invisible_until_the_row_is_hovered()
  test_row_hover_shows_the_button_dim()
  test_leaving_the_row_hides_the_button()
  test_moving_onto_the_button_keeps_it_shown()
  test_leaving_the_button_back_onto_the_row_dims_it()
  test_a_hidden_row_reused_as_shown_hides_its_eye()
  test_hidden_row_shows_the_eye_dim_without_hover()
  test_leaving_a_hidden_row_keeps_the_eye_dim()
  test_leaving_a_hidden_rows_eye_keeps_it_dim()
  test_a_shown_row_reused_as_hidden_shows_its_eye()
  test_hint_row_hides_the_button_and_clears_the_name()
  test_entry_without_a_name_has_no_button()
  test_eye_texture_paths_name_files_the_addon_ships()
end
