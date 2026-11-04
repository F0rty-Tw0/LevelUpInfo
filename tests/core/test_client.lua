local Assert = require("tests.helpers.assert")

local function returns(value)
  return function()
    return value
  end
end

-- Installs the two probed globals and returns a freshly loaded Client.
local function clientWith(tooltipInfo, classicExpansionLevel)
  _G.C_TooltipInfo = tooltipInfo
  _G.GetClassicExpansionLevel = classicExpansionLevel
  return assert(loadfile("Core/Client.lua"))("LevelUpInfo", {})
end

local function test_forever_when_trainer_tooltip_api_exists()
  local Client = clientWith({ GetTrainerService = returns(nil) }, returns(1))
  Assert.equal(Client.Get(), "forever")
end

local function test_tbc_when_classic_expansion_level_is_1()
  local Client = clientWith({}, returns(1))
  Assert.equal(Client.Get(), "tbc")
end

local function test_era_when_classic_expansion_level_is_0()
  local Client = clientWith({}, returns(0))
  Assert.equal(Client.Get(), "era")
end

local function test_era_when_classic_expansion_level_is_missing()
  local Client = clientWith(nil, nil)
  Assert.equal(Client.Get(), "era")
end

local function test_era_when_classic_expansion_level_is_not_a_number()
  local Client = clientWith({}, returns(nil))
  Assert.equal(Client.Get(), "era")
end

local function test_client_is_read_live_on_every_call()
  local Client = clientWith({}, returns(0))
  _G.GetClassicExpansionLevel = returns(1)
  Assert.equal(Client.Get(), "tbc")
end

local function test_module_is_published_on_ns()
  local ns = {}
  local module = assert(loadfile("Core/Client.lua"))("LevelUpInfo", ns)
  Assert.equal(ns.Client, module)
end

return function()
  test_forever_when_trainer_tooltip_api_exists()
  test_tbc_when_classic_expansion_level_is_1()
  test_era_when_classic_expansion_level_is_0()
  test_era_when_classic_expansion_level_is_missing()
  test_era_when_classic_expansion_level_is_not_a_number()
  test_client_is_read_live_on_every_call()
  test_module_is_published_on_ns()
  _G.C_TooltipInfo = nil
  _G.GetClassicExpansionLevel = nil
end
