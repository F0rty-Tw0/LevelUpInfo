local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local ARROW = require("LevelUpInfo.Core.Format").ARROW

local W
local Window
local db

local HEADING_FONT = "GameFontNormalLarge"

local function spell(cost, rank)
  return { cost = cost, rank = rank, races = { Scourge = true } }
end

-- Fresh fake client, modules and db per test. Priest cache at level 10:
-- Mind Blast (skill), Shadow Word: Pain Rank 2 (rank).
local function setup()
  W = Wow.Install()
  W.money = 1000
  W.spells[8092] = { name = "Mind Blast", iconID = 136224 }
  W.spells[589] = { name = "Shadow Word: Pain", iconID = 136207 }
  db = {
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
    trainers = {
      PRIEST = {
        covered = { Scourge = 10 },
        levels = { [10] = { [8092] = spell(300, "Rank 1"), [589] = spell(50, "Rank 2") } },
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

local function record(overrides)
  local result = {
    fromLevel = 9,
    toLevel = 10,
    gains = { health = 15, stamina = 1 },
    before = { health = 100, stamina = 25 },
  }
  for key, value in pairs(overrides or {}) do
    result[key] = value
  end
  return result
end

local function content()
  for _, widget in ipairs(W.frames) do
    if widget:GetParent() == Window.Frame() and W.state(widget).frameType == "Frame" then
      return widget
    end
  end
end

-- The content's own widgets of this type (and font, when given), in pool order.
local function children(frameType, template)
  local found = {}
  for _, widget in ipairs(W.frames) do
    local stub = W.state(widget)
    if stub.frameType == frameType and widget:GetParent() == content() and (not template or stub.template == template) then
      found[#found + 1] = widget
    end
  end
  return found
end

local function headingNamed(title)
  for _, heading in ipairs(children("FontString", HEADING_FONT)) do
    if heading:GetText() == title then
      return heading
    end
  end
end

-- GREEN_FONT_COLOR (0.1, 1, 0.1) as hex.
local GREEN = "|cff1aff1a"
local GRAY = "|cff808080"

-- Every gain key with its stub name and expected stat color, in display order.
local GAIN_COLORS = {
  { key = "health", name = "Health", hex = "49d36b" },
  { key = "power", name = "Mana", hex = "4d8dff" },
  { key = "talents", name = "Talent points", hex = "c084fc" },
  { key = "strength", name = "Strength", hex = "ff5c5c" },
  { key = "agility", name = "Agility", hex = "ffa340" },
  { key = "stamina", name = "Stamina", hex = "d9b38c" },
  { key = "intellect", name = "Intellect", hex = "4fd1e8" },
  { key = "spirit", name = "Spirit", hex = "f5a3d0" },
}

local function gainLines()
  local texts = {}
  for _, line in ipairs(children("FontString", "GameFontHighlight")) do
    if line:IsShown() then
      texts[#texts + 1] = line:GetText()
    end
  end
  return texts
end

local function test_gain_with_before_reads_gray_old_arrow_new_and_green_gain()
  setup()
  Window.Show(record({ gains = { stamina = 1 } }))
  Assert.equal(gainLines()[1], "|cffd9b38cStamina|r " .. GRAY .. "25|r " .. ARROW .. " 26 " .. GREEN .. "(+1)|r")
end

local function test_talent_line_uses_short_form()
  setup()
  Window.Show(record({ gains = { talents = 1 }, before = { talents = 0 } }))
  Assert.equal(gainLines()[1], "|cffc084fcTalent points|r " .. GREEN .. "(+1)|r")
end

local function test_every_gain_has_distinct_hex_color()
  setup()
  local gains, before = {}, {}
  for _, gain in ipairs(GAIN_COLORS) do
    gains[gain.key] = 1
    before[gain.key] = 10
  end
  Window.Show(record({ gains = gains, before = before }))
  local texts = gainLines()
  Assert.equal(#texts, #GAIN_COLORS)
  local seen = {}
  for index, gain in ipairs(GAIN_COLORS) do
    local colored = "|cff" .. gain.hex .. gain.name .. "|r"
    Assert.equal(string.find(texts[index], colored, 1, true) ~= nil, true)
    Assert.equal(seen[gain.hex], nil)
    seen[gain.hex] = true
  end
end

local function test_headings_have_no_divider_lines()
  setup()
  Window.Show(record())
  Assert.equal(headingNamed("New skills"):IsShown(), true)
  Assert.equal(#children("Texture"), 0)
end

local function topOf(region)
  return select(5, region:GetPoint(1))
end

local function test_gain_lines_sit_under_a_stats_heading()
  setup()
  Window.Show(record())
  local heading = headingNamed("Stats")
  Assert.equal(heading:IsShown(), true)
  Assert.equal(topOf(heading), 0)
  Assert.equal(select(4, heading:GetPoint(1)), 4)
  local first = children("FontString", "GameFontHighlight")[1]
  Assert.equal(topOf(first), -24)
end

local function test_no_stats_heading_without_gains()
  setup()
  Window.Show(record())
  Window.Show(record({ gains = {} }))
  Assert.equal(headingNamed("Stats"):IsShown(), false)
  Assert.equal(topOf(headingNamed("New skills")), 0)
end

local function test_fallback_gain_name_keeps_its_color()
  setup()
  rawset(_G, "SPELL_STAT3_NAME", nil)
  Window.Show(record({ gains = { stamina = 1 } }))
  Assert.equal(gainLines()[1], "|cffd9b38cStamina|r " .. GRAY .. "25|r " .. ARROW .. " 26 " .. GREEN .. "(+1)|r")
end

return function()
  test_gain_with_before_reads_gray_old_arrow_new_and_green_gain()
  test_talent_line_uses_short_form()
  test_every_gain_has_distinct_hex_color()
  test_headings_have_no_divider_lines()
  test_gain_lines_sit_under_a_stats_heading()
  test_no_stats_heading_without_gains()
  test_fallback_gain_name_keeps_its_color()
end
