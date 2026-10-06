local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local Window
local db

local HINT = "Visit your class trainer to see all new skills."
local MISSED_LEVEL = 5
local MISSED_BASE = 1000
local WEAPON_BASE = 2000

-- Fresh fake client, modules and db per test. The priest cache starts empty and
-- covers level 10 (no hint row); ns.OtherSources is this test's fixture.
local function setup(otherSources)
  W = Wow.Install()
  W.money = 1000
  db = {
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
    trainers = { PRIEST = { covered = { Scourge = 10 }, levels = {} } },
  }
  local ns = { OtherSources = { PRIEST = otherSources or {} } }
  for _, file in ipairs({
    "Core/Localization.lua",
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

local function trainerSpell(spellID, level, name, rank)
  W.spells[spellID] = { name = name, iconID = spellID }
  db.trainers.PRIEST.levels[level] = db.trainers.PRIEST.levels[level] or {}
  db.trainers.PRIEST.levels[level][spellID] = { cost = 100, rank = rank, races = { Scourge = true } }
end

-- Trainer spells at or below the old level 9: "Missed 1" .. "Missed n".
local function addMissed(count)
  for index = 1, count do
    trainerSpell(MISSED_BASE + index, MISSED_LEVEL, "Missed " .. index, "Rank 1")
  end
end

local function weaponRow(spellID, name, faction)
  W.spells[spellID] = { name = name, iconID = spellID }
  return { spellID = spellID, level = 1, kind = "weapon", faction = faction, npc = "Npc", place = "Place", cost = 100 }
end

-- Fresh setup with Horde weapon rows "Weapon 1" .. "Weapon n".
local function setupWeapons(count)
  local otherSources = {}
  setup(otherSources)
  for index = 1, count do
    otherSources[index] = weaponRow(WEAPON_BASE + index, "Weapon " .. index, "Horde")
  end
end

local function record()
  return {
    fromLevel = 9,
    toLevel = 10,
    gains = { health = 15 },
    before = { health = 100 },
  }
end

local function frame()
  return _G.LevelUpInfoFrame
end

local function content()
  for _, widget in ipairs(W.frames) do
    if widget:GetParent() == frame() and W.state(widget).frameType == "Frame" then
      return widget
    end
  end
end

-- Shown texts of the content's own font strings with this font, in pool order.
local function lines(template)
  local texts = {}
  for _, widget in ipairs(W.frames) do
    local stub = W.state(widget)
    if stub.frameType == "FontString" and widget:GetParent() == content() and stub.template == template and stub.shown then
      texts[#texts + 1] = widget:GetText()
    end
  end
  return table.concat(texts, "|")
end

local function shownRows()
  local rows = {}
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "Button" and widget:GetParent() == content() and widget:IsShown() then
      rows[#rows + 1] = widget
    end
  end
  return rows
end

local function rowNames()
  local names = {}
  for _, row in ipairs(shownRows()) do
    names[#names + 1] = row.name:GetText()
  end
  return table.concat(names, "|")
end

local function test_groups_render_in_order_with_headings()
  local otherSources = {}
  setup(otherSources)
  trainerSpell(11, 10, "New Skill", "Rank 1")
  trainerSpell(12, 10, "New Rank", "Rank 2")
  trainerSpell(13, MISSED_LEVEL, "Old Skill", "Rank 1")
  otherSources[1] = weaponRow(14, "Axe", "Horde")
  Window.Show(record())
  Assert.equal(lines("GameFontNormalLarge"), "New skills|New ranks|Not yet learned|Weapon skills")
  Assert.equal(rowNames(), "New Skill|New Rank|Old Skill|Axe")
end

local function test_not_yet_learned_caps_at_five_with_more_line()
  setup()
  addMissed(5)
  Window.Show(record())
  local withFive = frame():GetHeight()
  addMissed(7)
  Window.Show(record())
  Assert.equal(rowNames(), "Missed 1|Missed 2|Missed 3|Missed 4|Missed 5")
  Assert.equal(lines("GameFontDisableSmall"), "+2 more not yet learned")
  Assert.equal(frame():GetHeight() > withFive, true)
end

local function test_weapon_skills_cap_at_five_with_more_line()
  setupWeapons(6)
  Window.Show(record())
  Assert.equal(rowNames(), "Weapon 1|Weapon 2|Weapon 3|Weapon 4|Weapon 5")
  Assert.equal(lines("GameFontDisableSmall"), "+1 more weapon skills")
end

local function test_no_more_line_at_exactly_five()
  setupWeapons(5)
  addMissed(5)
  Window.Show(record())
  Assert.equal(#shownRows(), 10)
  Assert.equal(lines("GameFontDisableSmall"), "")
end

local function test_reshow_with_fewer_missed_hides_more_line_and_creates_no_frames()
  setup()
  addMissed(7)
  Window.Show(record())
  local frameCount = #W.frames
  for index = 3, 7 do
    W.known[MISSED_BASE + index] = true
  end
  Window.Show(record())
  Assert.equal(rowNames(), "Missed 1|Missed 2")
  Assert.equal(lines("GameFontDisableSmall"), "")
  Assert.equal(#W.frames, frameCount)
end

local function test_hint_row_follows_weapon_skills()
  setupWeapons(1)
  db.trainers.PRIEST.covered.Scourge = 9
  Window.Show(record())
  Assert.equal(rowNames(), "Weapon 1|" .. HINT)
end

local function test_fill_reads_player_faction()
  local otherSources = {}
  setup(otherSources)
  otherSources[1] = weaponRow(21, "Horde Axe", "Horde")
  otherSources[2] = weaponRow(22, "Alliance Mace", "Alliance")
  W.faction = "Alliance"
  Window.Show(record())
  Assert.equal(rowNames(), "Alliance Mace")
end

return function()
  test_groups_render_in_order_with_headings()
  test_not_yet_learned_caps_at_five_with_more_line()
  test_weapon_skills_cap_at_five_with_more_line()
  test_no_more_line_at_exactly_five()
  test_reshow_with_fewer_missed_hides_more_line_and_creates_no_frames()
  test_hint_row_follows_weapon_skills()
  test_fill_reads_player_faction()
end
