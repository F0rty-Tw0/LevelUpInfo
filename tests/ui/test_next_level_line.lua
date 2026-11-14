local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local NextLevelLine
local parent

-- Fresh fake client and modules per test: the string is a module upvalue.
local function setup()
  W = Wow.Install()
  local ns = {}
  assert(loadfile("Core/Localization.lua"))("LevelUpInfo", ns)
  NextLevelLine = assert(loadfile("UI/NextLevelLine.lua"))("LevelUpInfo", ns)
  parent = _G.CreateFrame("Frame")
end

local function test_text_names_the_level_and_skills_with_ranks()
  setup()
  local line = NextLevelLine.Set(parent, 14, { { name = "Renew", rank = "Rank 2" }, { name = "Fade", rank = "" } })
  Assert.equal(line:GetText(), "Next at 14: Renew (Rank 2), Fade")
end

local function test_skill_without_rank_text_shows_its_name_alone()
  setup()
  local line = NextLevelLine.Set(parent, 14, { { name = "Fade", rank = "" } })
  Assert.equal(line:GetText(), "Next at 14: Fade")
end

local function test_nil_level_hides_an_existing_string_and_returns_nil()
  setup()
  local line = NextLevelLine.Set(parent, 14, { { name = "Fade", rank = "" } })
  line:Show()
  Assert.equal(NextLevelLine.Set(parent, nil), nil)
  Assert.equal(line:IsShown(), false)
end

local function test_nil_level_with_no_string_makes_none()
  setup()
  local frames = #W.frames
  Assert.equal(NextLevelLine.Set(parent, nil), nil)
  Assert.equal(#W.frames, frames)
end

local function test_the_string_is_made_once()
  setup()
  local frames = #W.frames
  local first = NextLevelLine.Set(parent, 14, { { name = "Fade", rank = "" } })
  Assert.equal(#W.frames, frames + 1)
  local second = NextLevelLine.Set(parent, 16, { { name = "Inner Fire", rank = "Rank 1" } })
  Assert.equal(second, first)
  Assert.equal(#W.frames, frames + 1)
  Assert.equal(second:GetText(), "Next at 16: Inner Fire (Rank 1)")
end

local function test_string_shape()
  setup()
  local line = NextLevelLine.Set(parent, 14, { { name = "Fade", rank = "" } })
  local state = W.state(line)
  Assert.equal(state.template, "GameFontHighlightSmall")
  Assert.equal(state.width, 290)
  Assert.equal(state.height, 16)
  Assert.equal(state.justifyH, "LEFT")
  Assert.equal(state.wordWrap, false)
  Assert.equal(line:GetParent(), parent)
end

return function()
  test_text_names_the_level_and_skills_with_ranks()
  test_skill_without_rank_text_shows_its_name_alone()
  test_nil_level_hides_an_existing_string_and_returns_nil()
  test_nil_level_with_no_string_makes_none()
  test_the_string_is_made_once()
  test_string_shape()
end
