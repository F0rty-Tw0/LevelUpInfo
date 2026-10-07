local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local Window

-- Fresh fake client, modules and an empty trainer cache per test.
local function setup()
  W = Wow.Install()
  local db = { duration = 10, reducedMotion = false, scale = 1.0, trainers = {} }
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

local function record(fromLevel, toLevel)
  return {
    fromLevel = fromLevel,
    toLevel = toLevel,
    gains = { health = 15, power = 0, talents = 0, strength = 0, agility = 0, stamina = 0, intellect = 0, spirit = 0 },
    before = { health = 100 },
  }
end

local function frame()
  return _G.LevelUpInfoFrame
end

-- The font strings made directly on the window frame, in creation order.
local function headerLines()
  local found = {}
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "FontString" and widget:GetParent() == frame() then
      found[#found + 1] = widget
    end
  end
  return found
end

local function test_title_says_level_up()
  setup()
  Window.Show(record(13, 15))
  Assert.equal(W.state(frame()).title, "Level Up!")
end

local function test_header_is_one_line_naming_the_reached_level()
  setup()
  Window.Show(record(13, 15))
  local lines = headerLines()
  Assert.equal(#lines, 1)
  Assert.equal(lines[1]:GetText(), "Congratulations! You reached level 15.")
  Assert.equal(W.state(lines[1]).template, "GameFontNormal")
end

local function test_header_sits_right_of_the_portrait_under_the_title_bar()
  setup()
  Window.Show(record(9, 10))
  local point, relativeTo, relativePoint, x, y = headerLines()[1]:GetPoint(1)
  Assert.equal(point, "TOPLEFT")
  Assert.equal(relativeTo, frame())
  Assert.equal(relativePoint, "TOPLEFT")
  Assert.equal(x, 62)
  Assert.equal(y, -35)
end

local function test_reshow_updates_the_header_line()
  setup()
  Window.Show(record(9, 10))
  Window.Show(record(10, 11))
  Assert.equal(W.state(frame()).title, "Level Up!")
  Assert.equal(headerLines()[1]:GetText(), "Congratulations! You reached level 11.")
  Assert.equal(#headerLines(), 1)
end

return function()
  test_title_says_level_up()
  test_header_is_one_line_naming_the_reached_level()
  test_header_sits_right_of_the_portrait_under_the_title_bar()
  test_reshow_updates_the_header_line()
end
