-- Forever rows built from masters and class rules must match the v0.1.1
-- literal table, except that Polearms now need level 20.
local Assert = require("tests.helpers.assert")
local Helper = require("tests.helpers.other_sources")

local FIXTURE = "tests/fixtures/other_sources_forever_v011.lua"
local POLEARMS = 200
local POLEARMS_LEVEL = 20
local FIELDS = { "spellID", "level", "kind", "race", "faction", "npc", "place", "quest", "cost" }

local function loadFixture()
  return assert(loadfile(FIXTURE))("LevelUpInfo", {})
end

local function rowsOfKind(rows, kind)
  local found = {}
  for _, row in ipairs(rows) do
    if row.kind == kind then
      found[#found + 1] = row
    end
  end
  return found
end

local function assertSameRow(actual, expected, label)
  for _, field in ipairs(FIELDS) do
    Assert.equal(actual[field], expected[field], label .. " field " .. field)
  end
end

local function weaponRowsByKey(rows)
  local byKey = {}
  for _, row in ipairs(rowsOfKind(rows, "weapon")) do
    byKey[row.spellID .. "|" .. row.npc] = row
  end
  return byKey
end

-- spellID -> "npc1,npc2,..." in row order: the first npc is the one the window shows.
local function npcOrderBySpell(rows)
  local order = {}
  for _, row in ipairs(rowsOfKind(rows, "weapon")) do
    order[row.spellID] = (order[row.spellID] and order[row.spellID] .. "," or "") .. row.npc
  end
  return order
end

local function countKeys(map)
  local count = 0
  for _ in pairs(map) do
    count = count + 1
  end
  return count
end

local function test_forever_has_the_same_class_tokens_as_v011()
  local built, fixture = Helper.buildFor("forever"), loadFixture()
  for class in pairs(fixture) do
    Assert.equal(type(built[class]), "table", "missing class " .. class)
  end
  Assert.equal(countKeys(built), countKeys(fixture))
end

local function test_forever_quest_rows_match_v011()
  local built, fixture = Helper.buildFor("forever"), loadFixture()
  for class, rows in pairs(fixture) do
    local expected, actual = rowsOfKind(rows, "quest"), rowsOfKind(built[class], "quest")
    Assert.equal(#actual, #expected, class .. " quest row count")
    for index, row in ipairs(expected) do
      assertSameRow(actual[index], row, class .. " quest[" .. index .. "]")
    end
  end
end

local function test_forever_weapon_rows_match_v011_except_polearm_level()
  local built, fixture = Helper.buildFor("forever"), loadFixture()
  for class, rows in pairs(fixture) do
    local expected, actual = weaponRowsByKey(rows), weaponRowsByKey(built[class])
    Assert.equal(countKeys(actual), countKeys(expected), class .. " weapon row count")
    for key, row in pairs(expected) do
      local label = class .. " " .. key
      Assert.equal(type(actual[key]), "table", label .. " missing")
      local want = {}
      for _, field in ipairs(FIELDS) do
        want[field] = row[field]
      end
      if row.spellID == POLEARMS then
        want.level = POLEARMS_LEVEL
      end
      assertSameRow(actual[key], want, label)
    end
  end
end

local function test_forever_first_master_per_spell_matches_v011()
  local built, fixture = Helper.buildFor("forever"), loadFixture()
  for class, rows in pairs(fixture) do
    local actual = npcOrderBySpell(built[class])
    for spellID, npcs in pairs(npcOrderBySpell(rows)) do
      Assert.equal(actual[spellID], npcs, class .. " spell " .. spellID .. " master order")
    end
  end
end

return function()
  test_forever_has_the_same_class_tokens_as_v011()
  test_forever_quest_rows_match_v011()
  test_forever_weapon_rows_match_v011_except_polearm_level()
  test_forever_first_master_per_spell_matches_v011()
end
