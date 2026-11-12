-- Built-in priest trainer tables, one file per client: shape and counts.
local Assert = require("tests.helpers.assert")

local CLIENTS = { "forever", "era", "tbc" }
local EXPECTED = {
  forever = { file = "Forever", rows = 159, levels = 30, top = 60 },
  era = { file = "Era", rows = 139, levels = 30, top = 60 },
  tbc = { file = "Tbc", rows = 187, levels = 40, top = 70 },
}
-- Racial on Era and TBC (excluded there); baseline on Forever (kept).
local DEVOURING_PLAGUE = { 2944, 19276, 19277, 19278, 19279, 19280 }

local function loadData(client)
  local ns = {}
  assert(loadfile("Data/ClassSpells/" .. EXPECTED[client].file .. ".lua"))("LevelUpInfo", ns)
  return ns
end

local function priestLevels(client)
  return loadData(client).ClassSpellData[client]().PRIEST
end

local function isPositiveInteger(value)
  return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function test_each_file_registers_only_its_own_client()
  for _, client in ipairs(CLIENTS) do
    local ns = loadData(client)
    local first = next(ns.ClassSpellData)
    Assert.equal(first, client)
    Assert.equal(next(ns.ClassSpellData, first), nil, client)
    local byClass = ns.ClassSpellData[client]()
    local class = next(byClass)
    Assert.equal(class, "PRIEST", client)
    Assert.equal(next(byClass, class), nil, client)
  end
end

local function test_row_level_and_top_counts()
  for _, client in ipairs(CLIENTS) do
    local rows, levels, top = 0, 0, 0
    for level, spells in pairs(priestLevels(client)) do
      levels = levels + 1
      top = math.max(top, level)
      for _ in pairs(spells) do
        rows = rows + 1
      end
    end
    Assert.equal(rows, EXPECTED[client].rows, client .. " rows")
    Assert.equal(levels, EXPECTED[client].levels, client .. " levels")
    Assert.equal(top, EXPECTED[client].top, client .. " top")
  end
end

local function assertRowShape(client, level, spellID, entry)
  local where = client .. " " .. tostring(level) .. "/" .. tostring(spellID)
  assert(isPositiveInteger(level), where .. " level")
  assert(isPositiveInteger(spellID), where .. " spellID")
  assert(type(entry.cost) == "number" and entry.cost >= 0, where .. " cost")
  assert(type(entry.rank) == "string", where .. " rank")
  for key in pairs(entry) do
    assert(key == "cost" or key == "rank", where .. " extra key " .. tostring(key))
  end
end

local function test_every_row_has_only_cost_and_rank()
  for _, client in ipairs(CLIENTS) do
    for level, spells in pairs(priestLevels(client)) do
      for spellID, entry in pairs(spells) do
        assertRowShape(client, level, spellID, entry)
      end
    end
  end
end

local function test_no_spell_is_listed_at_two_levels()
  for _, client in ipairs(CLIENTS) do
    local seenAt = {}
    for level, spells in pairs(priestLevels(client)) do
      for spellID in pairs(spells) do
        assert(seenAt[spellID] == nil, client .. " " .. spellID .. " at " .. tostring(seenAt[spellID]) .. " and " .. level)
        seenAt[spellID] = level
      end
    end
  end
end

local function hasSpell(levels, spellID)
  for _, spells in pairs(levels) do
    if spells[spellID] then
      return true
    end
  end
  return false
end

local function test_devouring_plague_only_on_forever()
  for _, client in ipairs(CLIENTS) do
    local levels = priestLevels(client)
    for _, spellID in ipairs(DEVOURING_PLAGUE) do
      Assert.equal(hasSpell(levels, spellID), client == "forever", client .. " " .. spellID)
    end
  end
end

local function test_fortitude_and_renew_rank_one_prices()
  for _, client in ipairs(CLIENTS) do
    local levels = priestLevels(client)
    Assert.equal(levels[1][1243].cost, 10, client)
    Assert.equal(levels[1][1243].rank, "Rank 1", client)
    Assert.equal(levels[8][139].cost, 200, client)
    Assert.equal(levels[8][139].rank, "Rank 1", client)
  end
end

return function()
  test_each_file_registers_only_its_own_client()
  test_row_level_and_top_counts()
  test_every_row_has_only_cost_and_rank()
  test_no_spell_is_listed_at_two_levels()
  test_devouring_plague_only_on_forever()
  test_fortitude_and_renew_rank_one_prices()
end
