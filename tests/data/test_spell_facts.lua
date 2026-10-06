local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local EVENT = "SPELL_DATA_LOAD_RESULT"
local OLD_ID = 100
local NEW_ID = 200

local function setup()
  local W = Wow.Install()
  local ns = {}
  for _, path in ipairs({ "Core/Localization.lua", "Core/Events.lua", "Data/RankChanges.lua" }) do
    assert(loadfile(path))("LevelUpInfo", ns)
  end
  local SpellFacts = assert(loadfile("Data/SpellFacts.lua"))("LevelUpInfo", ns)
  return W, ns, SpellFacts
end

local function installCounting(SpellFacts)
  local counter = { calls = 0 }
  SpellFacts.Install(function()
    counter.calls = counter.calls + 1
  end)
  return counter
end

local function registered(ns)
  return ns.Events.frame:IsEventRegistered(EVENT)
end

local function test_loaded_returns_facts()
  local W, _, SpellFacts = setup()
  W.spells[OLD_ID] = {
    description = "Heals for 47 to 58.",
    castTime = 2500,
    cooldown = 8000,
    costs = { { cost = 25, name = "MANA" } },
  }
  local facts = SpellFacts.Read(OLD_ID)
  Assert.equal(facts.description, "Heals for 47 to 58.")
  Assert.equal(facts.castTime, 2500)
  Assert.equal(facts.cooldown, 8000)
  Assert.equal(facts.cost, 25)
  Assert.equal(facts.powerToken, "MANA")
end

local function test_unloaded_returns_nil_and_requests_once()
  local W, ns, SpellFacts = setup()
  W.spells[OLD_ID] = { description = "" }
  local registeredAtRequest
  W.onRequestLoad = function()
    registeredAtRequest = registered(ns)
  end
  Assert.equal(SpellFacts.Read(OLD_ID), nil)
  Assert.equal(SpellFacts.Read(OLD_ID), nil)
  Assert.equal(W.calls.RequestLoadSpellData, 1)
  Assert.equal(registeredAtRequest, true)
end

local function test_result_inside_request_returns_facts()
  local W, ns, SpellFacts = setup()
  W.spells[OLD_ID] = { description = "" }
  W.onRequestLoad = function(spellID)
    W.spells[spellID].description = "Loaded text."
    W.broadcast(EVENT, spellID, true)
  end
  local facts = SpellFacts.Read(OLD_ID)
  Assert.equal(facts.description, "Loaded text.")
  Assert.equal(registered(ns), false)
end

local function test_one_of_two_results_calls_onloaded_keeps_event()
  local W, ns, SpellFacts = setup()
  local counter = installCounting(SpellFacts)
  W.spells[OLD_ID] = { description = "" }
  W.spells[NEW_ID] = { description = "" }
  SpellFacts.Read(OLD_ID)
  SpellFacts.Read(NEW_ID)
  W.broadcast(EVENT, OLD_ID, true)
  Assert.equal(counter.calls, 1)
  Assert.equal(registered(ns), true)
end

local function test_last_result_unregisters_event()
  local W, ns, SpellFacts = setup()
  local counter = installCounting(SpellFacts)
  W.spells[OLD_ID] = { description = "" }
  W.spells[NEW_ID] = { description = "" }
  SpellFacts.Read(OLD_ID)
  SpellFacts.Read(NEW_ID)
  W.broadcast(EVENT, OLD_ID, true)
  W.broadcast(EVENT, NEW_ID, false)
  Assert.equal(counter.calls, 2)
  Assert.equal(registered(ns), false)
end

local function test_still_empty_after_result_reads_normally()
  local W, _, SpellFacts = setup()
  local counter = installCounting(SpellFacts)
  W.spells[OLD_ID] = { description = "", castTime = 0 }
  SpellFacts.Read(OLD_ID)
  W.broadcast(EVENT, OLD_ID, false)
  local facts = SpellFacts.Read(OLD_ID)
  Assert.equal(facts.description, "")
  Assert.equal(facts.castTime, 0)
  Assert.equal(W.calls.RequestLoadSpellData, 1)
  Assert.equal(counter.calls, 1)
end

local function test_unknown_spell_result_ignored()
  local W, ns, SpellFacts = setup()
  local counter = installCounting(SpellFacts)
  W.spells[OLD_ID] = { description = "" }
  SpellFacts.Read(OLD_ID)
  W.broadcast(EVENT, NEW_ID, true)
  Assert.equal(counter.calls, 0)
  Assert.equal(registered(ns), true)
  Assert.equal(SpellFacts.Read(OLD_ID), nil)
end

local function test_stop_clears_and_unregisters()
  local W, ns, SpellFacts = setup()
  W.spells[OLD_ID] = { description = "" }
  SpellFacts.Read(OLD_ID)
  SpellFacts.Stop()
  Assert.equal(registered(ns), false)
  Assert.equal(SpellFacts.Read(OLD_ID), nil)
  Assert.equal(W.calls.RequestLoadSpellData, 2)
end

local function test_result_after_stop_ignored()
  local W, ns, SpellFacts = setup()
  local counter = installCounting(SpellFacts)
  W.spells[OLD_ID] = { description = "" }
  W.spells[NEW_ID] = { description = "" }
  SpellFacts.Read(OLD_ID)
  SpellFacts.Stop()
  W.fireScript(ns.Events.frame, "OnEvent", EVENT, OLD_ID, true)
  Assert.equal(counter.calls, 0)
  Assert.equal(registered(ns), false)
  SpellFacts.Read(NEW_ID)
  W.broadcast(EVENT, OLD_ID, true)
  Assert.equal(counter.calls, 0)
  Assert.equal(registered(ns), true)
end

local function test_no_request_api_no_wait()
  local W, ns, SpellFacts = setup()
  _G.C_Spell.RequestLoadSpellData = nil
  W.spells[OLD_ID] = { description = "" }
  local facts = SpellFacts.Read(OLD_ID)
  Assert.equal(facts.description, "")
  Assert.equal(registered(ns), false)
end

local function test_no_description_api_no_wait()
  local W, ns, SpellFacts = setup()
  _G.C_Spell.GetSpellDescription = nil
  W.spells[OLD_ID] = { description = "Unused." }
  local facts = SpellFacts.Read(OLD_ID)
  Assert.equal(facts.description, "")
  Assert.equal(W.calls.RequestLoadSpellData, nil)
  Assert.equal(registered(ns), false)
end

local function test_missing_cost_api_field_nil()
  local W, _, SpellFacts = setup()
  _G.C_Spell.GetSpellPowerCost = nil
  W.spells[OLD_ID] = { costs = { { cost = 25, name = "MANA" } }, castTime = 1500 }
  local facts = SpellFacts.Read(OLD_ID)
  Assert.equal(facts.cost, nil)
  Assert.equal(facts.powerToken, nil)
  Assert.equal(facts.castTime, 1500)
end

local function test_changes_requests_both_spells()
  local W, ns, SpellFacts = setup()
  installCounting(SpellFacts)
  W.spells[OLD_ID] = { description = "", costs = { { cost = 25, name = "MANA" } } }
  W.spells[NEW_ID] = { description = "", costs = { { cost = 40, name = "MANA" } } }
  Assert.equal(SpellFacts.Changes(OLD_ID, NEW_ID), nil)
  Assert.equal(W.calls.RequestLoadSpellData, 2)
  W.spells[OLD_ID].description = "Heals for 47 to 58."
  W.spells[NEW_ID].description = "Heals for 76 to 91."
  W.broadcast(EVENT, OLD_ID, true)
  W.broadcast(EVENT, NEW_ID, true)
  local expected = ns.RankChanges.Lines(SpellFacts.Read(OLD_ID), SpellFacts.Read(NEW_ID))
  local lines = SpellFacts.Changes(OLD_ID, NEW_ID)
  Assert.equal(#expected, 2)
  Assert.equal(table.concat(lines, "\n"), table.concat(expected, "\n"))
end

return function()
  test_loaded_returns_facts()
  test_unloaded_returns_nil_and_requests_once()
  test_result_inside_request_returns_facts()
  test_one_of_two_results_calls_onloaded_keeps_event()
  test_last_result_unregisters_event()
  test_still_empty_after_result_reads_normally()
  test_unknown_spell_result_ignored()
  test_stop_clears_and_unregisters()
  test_result_after_stop_ignored()
  test_no_request_api_no_wait()
  test_no_description_api_no_wait()
  test_missing_cost_api_field_nil()
  test_changes_requests_both_spells()
end
