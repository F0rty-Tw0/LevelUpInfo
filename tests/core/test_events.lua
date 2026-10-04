local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local function loadEvents()
  local W = Wow.Install()
  local ns = {}
  assert(loadfile("Core/Events.lua"))("LevelUpInfo", ns)
  return W, ns.Events
end

local function test_on_registers_and_passes_the_payload_without_the_event_name()
  local W, Events = loadEvents()
  local got
  Events.On("PLAYER_LEVEL_UP", function(...)
    got = { ... }
  end)
  Assert.equal(Events.frame:IsEventRegistered("PLAYER_LEVEL_UP"), true)
  W.fireEvent(Events.frame, "PLAYER_LEVEL_UP", 5, 20, 15)
  Assert.equal(#got, 3)
  Assert.equal(got[1], 5)
  Assert.equal(got[3], 15)
end

local function test_off_unregisters_the_event()
  local W, Events = loadEvents()
  local calls = 0
  Events.On("TRAINER_UPDATE", function()
    calls = calls + 1
  end)
  Events.Off("TRAINER_UPDATE")
  Assert.equal(Events.frame:IsEventRegistered("TRAINER_UPDATE"), false)
  W.fireEvent(Events.frame, "TRAINER_UPDATE")
  Assert.equal(calls, 0)
end

local function test_each_event_routes_to_its_own_handler()
  local W, Events = loadEvents()
  local seen = {}
  Events.On("TRAINER_SHOW", function()
    seen[#seen + 1] = "show"
  end)
  Events.On("TRAINER_CLOSED", function()
    seen[#seen + 1] = "closed"
  end)
  W.fireEvent(Events.frame, "TRAINER_CLOSED")
  W.fireEvent(Events.frame, "TRAINER_SHOW")
  Assert.equal(table.concat(seen, ","), "closed,show")
end

return function()
  test_on_registers_and_passes_the_payload_without_the_event_name()
  test_off_unregisters_the_event()
  test_each_event_routes_to_its_own_handler()
end
