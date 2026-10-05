local Assert = require("tests.helpers.assert")

local CLASSES = {
  WARRIOR = true,
  PALADIN = true,
  HUNTER = true,
  ROGUE = true,
  PRIEST = true,
  SHAMAN = true,
  MAGE = true,
  WARLOCK = true,
  DRUID = true,
}
local RACES = {
  Human = true,
  Dwarf = true,
  NightElf = true,
  Gnome = true,
  Orc = true,
  Scourge = true,
  Tauren = true,
  Troll = true,
}
local FACTIONS = { Horde = true, Alliance = true }
local KINDS = { quest = true, weapon = true }

local function loadModule()
  local ns = {}
  local module = assert(loadfile("Data/OtherSources.lua"))("LevelUpInfo", ns)
  return module, ns
end

local function isPositiveInteger(value)
  return type(value) == "number" and value >= 1 and value == math.floor(value)
end

local function isNonNegativeInteger(value)
  return type(value) == "number" and value >= 0 and value == math.floor(value)
end

local function isText(value)
  return type(value) == "string" and value ~= ""
end

-- Raises with "<class>[<index>]: <field>" when a row breaks the row shape.
local function checkRow(class, index, row)
  local function check(ok, field)
    if not ok then
      error(class .. "[" .. index .. "]: " .. field, 0)
    end
  end
  check(isPositiveInteger(row.spellID), "spellID")
  check(isPositiveInteger(row.level), "level")
  check(KINDS[row.kind], "kind")
  check(isText(row.npc), "npc")
  check(isText(row.place), "place")
  check(row.race == nil or RACES[row.race], "race")
  check(row.faction == nil or FACTIONS[row.faction], "faction")
  local isQuest = row.kind == "quest"
  check(isQuest == isText(row.quest) and (isQuest or row.quest == nil), "quest")
  local isWeapon = row.kind == "weapon"
  check(isWeapon == isNonNegativeInteger(row.cost) and (isWeapon or row.cost == nil), "cost")
  check(not isWeapon or row.faction ~= nil, "weapon faction")
end

local function test_module_is_returned_and_published_on_ns()
  local module, ns = loadModule()
  Assert.equal(type(module), "table")
  Assert.equal(ns.OtherSources, module)
end

local function test_keys_are_class_tokens()
  local module = loadModule()
  for class in pairs(module) do
    Assert.equal(CLASSES[class], true, "unknown class token " .. tostring(class))
  end
end

local function test_every_row_has_the_row_shape()
  local module = loadModule()
  for class, rows in pairs(module) do
    for index, row in ipairs(rows) do
      checkRow(class, index, row)
    end
  end
end

local function test_no_duplicate_class_spell_npc()
  local module = loadModule()
  for class, rows in pairs(module) do
    local seen = {}
    for index, row in ipairs(rows) do
      local key = row.spellID .. "|" .. row.npc
      Assert.equal(seen[key], nil, class .. "[" .. index .. "] duplicates " .. key)
      seen[key] = true
    end
  end
end

local function expectRejected(row, field)
  local ok, err = pcall(checkRow, "PRIEST", 1, row)
  Assert.equal(ok, false, "expected row to be rejected for " .. field)
  Assert.contains(err, "PRIEST[1]: " .. field)
end

local function test_check_row_rejects_bad_rows()
  local quest = { spellID = 2652, level = 10, kind = "quest", npc = "N", place = "P", quest = "Q" }
  checkRow("PRIEST", 1, quest)

  expectRejected({ spellID = 2652, level = 10, kind = "trainer", npc = "N", place = "P", quest = "Q" }, "kind")
  expectRejected({ spellID = 202, level = 1, kind = "weapon", faction = "Horde", npc = "N", place = "P", cost = 1000, quest = "Q" }, "quest")
  expectRejected({ spellID = 202, level = 1, kind = "weapon", npc = "N", place = "P", cost = 1000 }, "weapon faction")
  expectRejected({ spellID = 2652, level = 0, kind = "quest", npc = "N", place = "P", quest = "Q" }, "level")
end

return function()
  test_module_is_returned_and_published_on_ns()
  test_keys_are_class_tokens()
  test_every_row_has_the_row_shape()
  test_no_duplicate_class_spell_npc()
  test_check_row_rejects_bad_rows()
end
