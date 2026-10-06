local Assert = require("tests.helpers.assert")

local function load(path)
  return assert(loadfile(path))("LevelUpInfo", {})
end

local function test_every_weapon_row_has_an_icon()
  local otherSources = load("Data/OtherSources.lua")
  local weaponIcons = load("Data/WeaponIcons.lua")
  for class, rows in pairs(otherSources) do
    for index, row in ipairs(rows) do
      if row.kind == "weapon" then
        local icon = weaponIcons[row.spellID]
        local label = class .. "[" .. index .. "] spell " .. row.spellID
        Assert.equal(type(icon), "string", label)
        Assert.equal(icon ~= "", true, label)
      end
    end
  end
end

local function test_keys_are_positive_integers()
  for key in pairs(load("Data/WeaponIcons.lua")) do
    Assert.equal(type(key) == "number" and key > 0 and key % 1 == 0, true, "bad key " .. tostring(key))
  end
end

return function()
  test_every_weapon_row_has_an_icon()
  test_keys_are_positive_integers()
end
