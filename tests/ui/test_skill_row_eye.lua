-- The row's hide/restore eye button.
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local SkillRow
local parent
local log
local eyeNames

local ENTRY = { spellID = 8092, name = "Mind Blast", icon = 136224, rank = "Rank 1", cost = 300 }
local EYE_OPEN = "Interface\\AddOns\\LevelUpInfo\\Media\\EyeOpen.tga"
local EYE_CLOSED = "Interface\\AddOns\\LevelUpInfo\\Media\\EyeClosed.tga"
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
  eyeNames = {}
end

local function newRow()
  return SkillRow.Create(parent, function()
    log[#log + 1] = "enter:" .. #W.tooltip
  end, function()
    log[#log + 1] = "leave:" .. #W.tooltip
  end, function(name)
    eyeNames[#eyeNames + 1] = name
  end)
end

local function test_eye_is_a_plain_16_by_16_button_at_the_top_right()
  setup()
  local row = newRow()
  local eye = row.eye
  Assert.equal(W.state(eye).frameType, "Button")
  Assert.equal(W.state(eye).template, nil)
  Assert.equal(eye:GetParent(), row)
  local width, height = eye:GetSize()
  Assert.equal(width, 16)
  Assert.equal(height, 16)
  local point, relativeTo, relativePoint, x, y = eye:GetPoint()
  Assert.equal(point, "TOPRIGHT")
  Assert.equal(relativeTo, row)
  Assert.equal(relativePoint, "TOPRIGHT")
  Assert.equal(x, -6)
  Assert.equal(y, -6)
  Assert.equal(eye:GetAlpha(), 0.6)
  Assert.equal(W.state(eye.texture).allPoints, true)
end

local function test_set_skill_shows_the_open_eye_and_keeps_the_name()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  Assert.equal(W.state(row.eye.texture).texture, EYE_OPEN)
  Assert.equal(row.eye:IsShown(), true)
  Assert.equal(row.skillName, "Mind Blast")
end

local function test_a_hidden_entry_gets_the_closed_eye()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, { spellID = 8092, name = "Mind Blast", icon = 1, rank = "", cost = 1, hidden = true }, W.money)
  Assert.equal(W.state(row.eye.texture).texture, EYE_CLOSED)
  SkillRow.SetSkill(row, ENTRY, W.money)
  Assert.equal(W.state(row.eye.texture).texture, EYE_OPEN)
end

local function test_eye_click_passes_the_rows_current_skill_name()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row.eye, "OnClick")
  SkillRow.SetSkill(row, QUEST_ENTRY, W.money)
  W.fireScript(row.eye, "OnClick")
  Assert.equal(table.concat(eyeNames, "|"), "Mind Blast|Touch of Weakness")
end

local function test_eye_hover_brightens_it_and_pauses_without_a_tooltip()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row.eye, "OnEnter")
  Assert.equal(row.eye:GetAlpha(), 1)
  Assert.equal(log[1], "enter:0")
  W.fireScript(row.eye, "OnLeave")
  Assert.equal(row.eye:GetAlpha(), 0.6)
  Assert.equal(log[2], "leave:0")
  Assert.equal(#W.tooltip, 0)
end

-- A row pooled while its eye was hovered gets no OnLeave before its reuse.
local function test_set_skill_puts_a_hovered_eye_back_to_its_resting_alpha()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  W.fireScript(row.eye, "OnEnter")
  SkillRow.SetSkill(row, QUEST_ENTRY, W.money)
  Assert.equal(row.eye:GetAlpha(), 0.6)
end

local function test_hint_row_hides_the_eye_and_clears_the_name()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, ENTRY, W.money)
  SkillRow.SetHint(row)
  Assert.equal(row.eye:IsShown(), false)
  Assert.equal(row.skillName, nil)
  SkillRow.SetSkill(row, ENTRY, W.money)
  Assert.equal(row.eye:IsShown(), true)
end

local function test_entry_without_a_name_has_no_eye()
  setup()
  local row = newRow()
  SkillRow.SetSkill(row, { spellID = 1, name = "", icon = 1, rank = "", cost = 1 }, W.money)
  Assert.equal(row.eye:IsShown(), false)
end

-- The paths are the game's (relative to the AddOns folder); the files are the
-- addon's own Media textures.
local function test_eye_texture_paths_name_files_the_addon_ships()
  local prefix = "Interface\\AddOns\\LevelUpInfo\\"
  for _, path in ipairs({ EYE_OPEN, EYE_CLOSED }) do
    Assert.equal(string.sub(path, 1, #prefix), prefix)
    local file = string.gsub(string.sub(path, #prefix + 1), "\\", "/")
    local handle = io.open(file, "rb")
    Assert.equal(handle ~= nil, true, "missing " .. file)
    handle:close()
  end
end

return function()
  test_eye_is_a_plain_16_by_16_button_at_the_top_right()
  test_set_skill_shows_the_open_eye_and_keeps_the_name()
  test_a_hidden_entry_gets_the_closed_eye()
  test_eye_click_passes_the_rows_current_skill_name()
  test_eye_hover_brightens_it_and_pauses_without_a_tooltip()
  test_set_skill_puts_a_hovered_eye_back_to_its_resting_alpha()
  test_hint_row_hides_the_eye_and_clears_the_name()
  test_entry_without_a_name_has_no_eye()
  test_eye_texture_paths_name_files_the_addon_ships()
end
