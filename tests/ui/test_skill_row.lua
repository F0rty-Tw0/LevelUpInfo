local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local SkillRow
local parent
local log

local ENTRY = { spellID = 8092, name = "Mind Blast", icon = 136224, rank = "Rank 1", cost = 300 }
local QUEST_ENTRY = {
  spellID = 2652,
  name = "Touch of Weakness",
  icon = 136143,
  rank = "",
  source = { kind = "quest", quest = "Q", npc = "N", place = "P" },
}
local WEAPON_ENTRY = {
  spellID = 202,
  name = "Two-Handed Swords",
  icon = 135327,
  rank = "",
  cost = 1000,
  source = { kind = "weapon", npc = "N", place = "P", cost = 1000 },
}

-- Fresh fake client, module and parent frame per test; onEnter/onLeave log into `log`.
local function setup()
  W = Wow.Install()
  W.money = 1000
  SkillRow = assert(loadfile("UI/SkillRow.lua"))("LevelUpInfo", {})
  parent = _G.CreateFrame("Frame", nil, _G.UIParent)
  log = {}
end

local function newRow()
  return SkillRow.Create(parent, function()
    log[#log + 1] = "enter:" .. #W.tooltip
  end, function()
    log[#log + 1] = "leave:" .. #W.tooltip
  end)
end

local function test_row_uses_trainer_texture_with_exact_tex_coords()
  setup()
  local row = newRow()
  local normal = W.state(row.background)
  Assert.equal(normal.texture, "Interface\\ClassTrainerFrame\\TrainerTextures")
  Assert.equal(table.concat(normal.texCoord, ","), "0.00195313,0.57421875,0.65820313,0.75")
  local highlight = W.state(row.highlight)
  Assert.equal(highlight.texture, "Interface\\ClassTrainerFrame\\TrainerTextures")
  Assert.equal(table.concat(highlight.texCoord, ","), "0.00195313,0.57421875,0.75390625,0.84570313")
  Assert.equal(highlight.blendMode, "ADD")
end

local function test_row_is_298_by_47()
  setup()
  local width, height = newRow():GetSize()
  Assert.equal(width, 298)
  Assert.equal(height, 47)
end

local function test_icon_is_36_by_36_at_topleft_6_minus_5_5()
  setup()
  local row = newRow()
  local width, height = row.icon:GetSize()
  Assert.equal(width, 36)
  Assert.equal(height, 36)
  local point, relativeTo, relativePoint, x, y = row.icon:GetPoint()
  Assert.equal(point, "TOPLEFT")
  Assert.equal(relativeTo, row)
  Assert.equal(relativePoint, "TOPLEFT")
  Assert.equal(x, 6)
  Assert.equal(y, -5.5)
end

local function test_name_sits_right_of_icon_top()
  setup()
  local row = newRow()
  local point, relativeTo, relativePoint, x, y = row.name:GetPoint()
  Assert.equal(point, "TOPLEFT")
  Assert.equal(relativeTo, row.icon)
  Assert.equal(relativePoint, "TOPRIGHT")
  Assert.equal(x, 6)
  Assert.equal(y, -1)
end

local function test_rank_is_anchored_right_after_the_name()
  setup()
  local row = newRow()
  local point, relativeTo, relativePoint = row.rank:GetPoint()
  Assert.equal(point, "LEFT")
  Assert.equal(relativeTo, row.name)
  Assert.equal(relativePoint, "RIGHT")
end

local function test_fonts_follow_spec()
  setup()
  local row = newRow()
  Assert.equal(W.state(row.name).template, "GameFontNormal")
  Assert.equal(W.state(row.rank).template, "GameFontDisableSmall")
  Assert.equal(W.state(row.price).template, "GameFontHighlightSmall")
end

local function test_set_skill_fills_icon_name_rank_and_price()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  Assert.equal(W.state(row.icon).texture, 136224)
  Assert.equal(row.name:GetText(), "Mind Blast")
  Assert.equal(row.rank:GetText(), "Rank 1")
  Assert.equal(row.price:GetText(), "300c")
end

local function test_price_is_white_when_affordable()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, 300)
  Assert.equal(table.concat(W.state(row.price).textColor, ","), "1,1,1")
end

local function test_price_is_red_when_unaffordable()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, 299)
  Assert.equal(table.concat(W.state(row.price).textColor, ","), "1,0.1,0.1")
end

local function test_enter_shows_spell_tooltip_then_calls_on_enter()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row, "OnEnter")
  Assert.equal(W.tooltip[1][1], "SetOwner")
  Assert.equal(W.tooltip[1][2], row)
  Assert.equal(W.tooltip[1][3], "ANCHOR_RIGHT")
  Assert.equal(W.tooltip[2][1], "SetSpellByID")
  Assert.equal(W.tooltip[2][2], 8092)
  Assert.equal(W.tooltip[3][1], "Show")
  Assert.equal(log[1], "enter:3")
end

local function test_leave_hides_tooltip_then_calls_on_leave()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row, "OnEnter")
  W.fireScript(row, "OnLeave")
  Assert.equal(W.tooltip[4][1], "Hide")
  Assert.equal(log[2], "leave:4")
end

local function test_hint_row_shows_hint_icon_and_text_with_empty_price()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  SkillRow.SetHint(row)
  Assert.equal(W.state(row.icon).texture, "Interface\\Icons\\INV_Misc_Book_09")
  Assert.equal(row.name:GetText(), "Visit your class trainer to see all new skills.")
  Assert.equal(row.rank:GetText(), "")
  Assert.equal(row.price:GetText(), "")
end

local function test_hovering_the_hint_row_shows_no_tooltip_but_still_pauses()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  SkillRow.SetHint(row)
  W.fireScript(row, "OnEnter")
  W.fireScript(row, "OnLeave")
  Assert.equal(#W.tooltip, 0)
  Assert.equal(log[1], "enter:0")
  Assert.equal(log[2], "leave:0")
end

local function test_game_tooltip_fields_stay_unchanged()
  setup()
  local snapshot = W.snapshot(_G.GameTooltip)
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row, "OnEnter")
  W.fireScript(row, "OnLeave")
  Assert.equal(W.changedKeys(_G.GameTooltip, snapshot), "")
end

local function test_source_line_layout()
  setup()
  local row = newRow()
  local state = W.state(row.sourceLine)
  Assert.equal(state.template, "GameFontDisableSmall")
  local point, relativeTo, relativePoint, x, y = row.sourceLine:GetPoint()
  Assert.equal(point, "TOPLEFT")
  Assert.equal(relativeTo, row.name)
  Assert.equal(relativePoint, "BOTTOMLEFT")
  Assert.equal(x, 0)
  Assert.equal(y, -2)
  Assert.equal(state.width, 190)
  Assert.equal(state.wordWrap, false)
end

local function test_quest_entry_shows_quest_line_and_no_price()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, QUEST_ENTRY, W.money)
  Assert.equal(row.sourceLine:GetText(), "Quest: Q · N · P")
  Assert.equal(row.sourceLine:IsShown(), true)
  Assert.equal(row.price:GetText(), "")
end

local function test_weapon_entry_shows_master_line_and_price()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, WEAPON_ENTRY, 999)
  Assert.equal(row.sourceLine:GetText(), "Weapon master: N · P")
  Assert.equal(row.sourceLine:IsShown(), true)
  Assert.equal(row.price:GetText(), "1000c")
  Assert.equal(table.concat(W.state(row.price).textColor, ","), "1,0.1,0.1")
  SkillRow.SetSkill(row, WEAPON_ENTRY, 1000)
  Assert.equal(table.concat(W.state(row.price).textColor, ","), "1,1,1")
end

local function test_trainer_entry_hides_source_line_after_reuse()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, QUEST_ENTRY, W.money)
  SkillRow.SetSkill(row, ENTRY, W.money)
  Assert.equal(row.sourceLine:IsShown(), false)
  Assert.equal(row.price:GetText(), "300c")
end

local function test_hint_hides_source_line_after_reuse()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, WEAPON_ENTRY, W.money)
  SkillRow.SetHint(row)
  Assert.equal(row.sourceLine:IsShown(), false)
end

return function()
  test_row_uses_trainer_texture_with_exact_tex_coords()
  test_row_is_298_by_47()
  test_icon_is_36_by_36_at_topleft_6_minus_5_5()
  test_name_sits_right_of_icon_top()
  test_rank_is_anchored_right_after_the_name()
  test_fonts_follow_spec()
  test_set_skill_fills_icon_name_rank_and_price()
  test_price_is_white_when_affordable()
  test_price_is_red_when_unaffordable()
  test_enter_shows_spell_tooltip_then_calls_on_enter()
  test_leave_hides_tooltip_then_calls_on_leave()
  test_hint_row_shows_hint_icon_and_text_with_empty_price()
  test_hovering_the_hint_row_shows_no_tooltip_but_still_pauses()
  test_game_tooltip_fields_stay_unchanged()
  test_source_line_layout()
  test_quest_entry_shows_quest_line_and_no_price()
  test_weapon_entry_shows_master_line_and_price()
  test_trainer_entry_hides_source_line_after_reuse()
  test_hint_hides_source_line_after_reuse()
end
