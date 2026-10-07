local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local SkillRow
local parent

local ENTRY = { spellID = 2053, name = "Lesser Heal", icon = 135929, rank = "Rank 2", cost = 100 }
local THREE_LINES = { "Healing: 47-58 -> 76-91", "Mana cost: 30 -> 45", "Cast time: 1.5 sec -> 2 sec" }

local function setup()
  W = Wow.Install()
  W.money = 1000
  SkillRow = assert(loadfile("UI/SkillRow.lua"))("LevelUpInfo", {})
  parent = _G.CreateFrame("Frame", nil, _G.UIParent)
end

local function newRow()
  local row = SkillRow.Create(parent, function() end, function() end)
  SkillRow.SetSkill(row, ENTRY, W.money)
  return row
end

local function assertLinesHidden(row)
  for _, line in ipairs(row.changeLines) do
    Assert.equal(line:IsShown(), false)
  end
end

local function test_three_lines_height_71()
  setup()
  local row = newRow()
  local height = SkillRow.SetChanges(row, THREE_LINES)
  Assert.equal(height, 71)
  Assert.equal(row:GetHeight(), 71)
  for i, text in ipairs(THREE_LINES) do
    Assert.equal(row.changeLines[i]:IsShown(), true)
    Assert.equal(row.changeLines[i]:GetText(), text)
  end
end

local function test_line_three_anchor()
  setup()
  local row = newRow()
  SkillRow.SetChanges(row, THREE_LINES)
  local point, relativeTo, relativePoint, x, y = row.changeLines[3]:GetPoint()
  Assert.equal(point, "TOPLEFT")
  Assert.equal(relativeTo, row.name)
  Assert.equal(relativePoint, "BOTTOMLEFT")
  Assert.equal(x, 0)
  Assert.equal(y, -26)
  for _, line in ipairs(row.changeLines) do
    local state = W.state(line)
    Assert.equal(state.height, 12)
    Assert.equal(state.width, 190)
    Assert.equal(state.template, "GameFontDisableSmall")
    Assert.equal(state.wordWrap, false)
    Assert.equal(state.justifyH, "LEFT")
  end
end

local function test_fewer_lines_reuses_strings()
  setup()
  local row = newRow()
  SkillRow.SetChanges(row, THREE_LINES)
  local widgets = #W.frames
  local height = SkillRow.SetChanges(row, { "Mana cost: 30 -> 45" })
  Assert.equal(#W.frames, widgets)
  Assert.equal(height, 47)
  Assert.equal(row:GetHeight(), 47)
  Assert.equal(row.changeLines[1]:IsShown(), true)
  Assert.equal(row.changeLines[1]:GetText(), "Mana cost: 30 -> 45")
  Assert.equal(row.changeLines[2]:IsShown(), false)
  Assert.equal(row.changeLines[3]:IsShown(), false)
end

local function test_create_makes_no_change_lines()
  setup()
  local row = SkillRow.Create(parent, function() end, function() end)
  Assert.equal(#row.changeLines, 0)
end

local function test_set_skill_resets()
  setup()
  local row = newRow()
  SkillRow.SetChanges(row, THREE_LINES)
  SkillRow.SetSkill(row, ENTRY, W.money)
  assertLinesHidden(row)
  Assert.equal(row:GetHeight(), 47)
end

local function test_set_hint_resets()
  setup()
  local row = newRow()
  SkillRow.SetChanges(row, THREE_LINES)
  SkillRow.SetHint(row)
  assertLinesHidden(row)
  Assert.equal(row:GetHeight(), 47)
end

local function test_empty_changes_resets()
  setup()
  local row = newRow()
  SkillRow.SetChanges(row, THREE_LINES)
  Assert.equal(SkillRow.SetChanges(row, {}), 47)
  assertLinesHidden(row)
  Assert.equal(row:GetHeight(), 47)
end

return function()
  test_three_lines_height_71()
  test_line_three_anchor()
  test_fewer_lines_reuses_strings()
  test_create_makes_no_change_lines()
  test_set_skill_resets()
  test_set_hint_resets()
  test_empty_changes_resets()
end
