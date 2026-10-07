local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local opened
local tested
local testedLevel

local function setup()
  Wow.Install()
  local SlashCommand = assert(loadfile("Core/SlashCommand.lua"))("LevelUpInfo", {})
  opened, tested, testedLevel = 0, 0, nil
  SlashCommand.Register(function()
    opened = opened + 1
  end, function(level)
    tested = tested + 1
    testedLevel = level
  end)
end

local function run(message)
  _G.SlashCmdList.LEVELUPINFO(message)
end

local function test_registers_the_lui_command()
  setup()
  Assert.equal(_G.SLASH_LEVELUPINFO1, "/lui")
end

local function test_bare_command_opens_settings()
  setup()
  run("")
  Assert.equal(opened, 1)
  Assert.equal(tested, 0)
end

local function test_test_argument_runs_the_preview()
  setup()
  run("test")
  Assert.equal(tested, 1)
  Assert.equal(opened, 0)
end

local function test_test_argument_ignores_case_and_surrounding_spaces()
  setup()
  run("  TEST ")
  Assert.equal(tested, 1)
  Assert.equal(opened, 0)
end

local function test_test_without_level_passes_no_level()
  setup()
  run("test")
  Assert.equal(testedLevel, nil)
end

local function test_test_with_level_passes_the_level()
  setup()
  run(" test 40 ")
  Assert.equal(tested, 1)
  Assert.equal(testedLevel, 40)
end

local function test_test_with_non_number_opens_settings()
  setup()
  run("test x")
  Assert.equal(opened, 1)
  Assert.equal(tested, 0)
end

local function test_unknown_argument_opens_settings()
  setup()
  run("bogus")
  Assert.equal(opened, 1)
  Assert.equal(tested, 0)
end

return function()
  test_registers_the_lui_command()
  test_bare_command_opens_settings()
  test_test_argument_runs_the_preview()
  test_test_argument_ignores_case_and_surrounding_spaces()
  test_test_without_level_passes_no_level()
  test_test_with_level_passes_the_level()
  test_test_with_non_number_opens_settings()
  test_unknown_argument_opens_settings()
end
