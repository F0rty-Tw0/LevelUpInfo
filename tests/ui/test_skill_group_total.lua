local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local SPECS = { { group = "skill", cap = 5 }, { group = "weapon", cap = 5, fold = true } }

-- Fresh fake client and module per test, built with one plain and one foldable capped group.
local function setup()
  local W = Wow.Install()
  local ns = {}
  for _, path in ipairs({ "Core/Localization.lua", "Core/Events.lua", "UI/AutoHide.lua" }) do
    assert(loadfile(path))("LevelUpInfo", ns)
  end
  local t = { W = W }
  t.SkillGroup = assert(loadfile("UI/SkillGroup.lua"))("LevelUpInfo", ns)
  t.content = _G.CreateFrame("Frame", nil, _G.UIParent)
  t.SkillGroup.Build(t.content, SPECS, function() end, {}, function() end)

  return t
end

local function colorOf(t, fontString)
  return table.concat(t.W.state(fontString).textColor, ",")
end

local function test_total_shows_the_money_string()
  local t = setup()
  local fs = t.SkillGroup.Total("skill", 350, 1000)
  Assert.equal(fs:GetText(), "350c")
end

local function test_total_is_white_when_affordable()
  local t = setup()
  local fs = t.SkillGroup.Total("skill", 350, 350)
  Assert.equal(colorOf(t, fs), "1,1,1")
end

local function test_total_is_red_when_short()
  local t = setup()
  local fs = t.SkillGroup.Total("skill", 350, 349)
  Assert.equal(colorOf(t, fs), "1,0.1,0.1")
end

local function test_total_widths_line_up()
  local t = setup()
  Assert.equal(t.SkillGroup.Total("skill", 1, 1):GetWidth(), 292)
  Assert.equal(t.SkillGroup.Total("weapon", 1, 1):GetWidth(), 278)
end

local function test_total_is_a_16_high_right_aligned_line()
  local t = setup()
  local fs = t.SkillGroup.Total("skill", 1, 1)
  Assert.equal(fs:GetHeight(), 16)
  Assert.equal(t.W.state(fs).justifyH, "RIGHT")
  Assert.equal(t.W.state(fs).wordWrap, false)
end

local function test_build_creates_totals_hidden()
  local t = setup()
  local skill = t.SkillGroup.Total("skill", 1, 1)
  local weapon = t.SkillGroup.Total("weapon", 1, 1)
  Assert.equal(skill ~= weapon, true)
  Assert.equal(skill:IsShown(), false)
  Assert.equal(weapon:IsShown(), false)
end

local function test_hide_total_hides_it()
  local t = setup()
  local fs = t.SkillGroup.Total("skill", 1, 1)
  fs:Show()
  t.SkillGroup.HideTotal("skill")
  Assert.equal(fs:IsShown(), false)
end

local function test_hide_total_ignores_an_unknown_group()
  local t = setup()
  t.SkillGroup.HideTotal("nope")
end

local function test_hide_all_hides_totals()
  local t = setup()
  local skill = t.SkillGroup.Total("skill", 1, 1)
  local weapon = t.SkillGroup.Total("weapon", 1, 1)
  skill:Show()
  weapon:Show()
  t.SkillGroup.HideAll()
  Assert.equal(skill:IsShown(), false)
  Assert.equal(weapon:IsShown(), false)
end

return function()
  test_total_shows_the_money_string()
  test_total_is_white_when_affordable()
  test_total_is_red_when_short()
  test_total_widths_line_up()
  test_total_is_a_16_high_right_aligned_line()
  test_build_creates_totals_hidden()
  test_hide_total_hides_it()
  test_hide_total_ignores_an_unknown_group()
  test_hide_all_hides_totals()
end
