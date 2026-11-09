local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local Window
local db

local MISSED_LEVEL = 5
local MISSED_BASE = 1000
local WEAPON_BASE = 2000
local HEADING_TO_ROW = 24

local function setup(otherSources)
  W = Wow.Install()
  W.money = 1000
  db = {
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
    foldedGroups = {},
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
    "UI/ScrollBox.lua",
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

local function addMissed(count)
  for index = 1, count do
    trainerSpell(MISSED_BASE + index, MISSED_LEVEL, "Missed " .. index, "Rank 1")
  end
end

local function weaponRow(spellID, name, faction)
  W.spells[spellID] = { name = name, iconID = spellID }

  return { spellID = spellID, level = 1, kind = "weapon", faction = faction, npc = "Npc", place = "Place", cost = 100 }
end

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
    local isChild = widget:GetParent() == frame()
    local isView = W.state(widget).frameType == "ScrollFrame"
    if isChild and isView then
      return widget:GetScrollChild()
    end
  end
end

local function shownRows()
  local rows = {}
  for _, widget in ipairs(W.frames) do
    local stub = W.state(widget)
    local isRow = stub.frameType == "Button" and widget.name ~= nil
    local isInContent = widget:GetParent() == content()
    if isRow and isInContent and stub.shown then
      rows[#rows + 1] = widget
    end
  end

  return rows
end

local function topOf(region)
  return select(5, region:GetPoint(1))
end

-- The shown heading whose text starts with `title`.
local function headingOf(title)
  for _, widget in ipairs(W.frames) do
    local stub = W.state(widget)
    local isHeading = stub.frameType == "FontString" and stub.template == "GameFontNormalLarge"
    local text = widget:GetText() or ""
    local startsWithTitle = text:sub(1, #title) == title
    if isHeading and stub.shown and startsWithTitle then
      return widget
    end
  end
end

-- The shown total on the same line as the heading, else nil. Never GetTop (the stub returns 0).
local function totalOf(title)
  local lineTop = topOf(headingOf(title))
  for _, widget in ipairs(W.frames) do
    local stub = W.state(widget)
    local isTotal = stub.frameType == "FontString" and stub.template == "GameFontHighlightSmall"
    local isInContent = widget:GetParent() == content()
    local isOnLine = isTotal and topOf(widget) == lineTop
    if isTotal and stub.shown and isInContent and isOnLine then
      return widget
    end
  end
end

local function color(fontString)
  return table.concat(W.state(fontString).textColor, ",")
end

local function test_new_skills_heading_shows_total()
  setup()
  trainerSpell(11, 10, "One", "Rank 1")
  trainerSpell(12, 10, "Two", "Rank 1")
  Window.Show(record())
  local total = totalOf("New skills")
  Assert.equal(total:GetText(), "200c")
  Assert.equal(color(total), "1,1,1")
end

local function test_single_priced_skill_shows_no_total()
  setup()
  trainerSpell(11, 10, "One", "Rank 1")
  Window.Show(record())
  Assert.equal(totalOf("New skills"), nil)
end

local function test_total_counts_rows_past_the_cap()
  setup()
  addMissed(7)
  Window.Show(record())
  Assert.equal(#shownRows(), 5)
  Assert.equal(totalOf("Not yet learned"):GetText(), "700c")
end

local function test_folded_group_keeps_its_total()
  setupWeapons(6)
  db.foldedGroups.weapon = true
  Window.Show(record())
  Assert.equal(headingOf("Weapon skills"):GetText(), "Weapon skills (6)")
  Assert.equal(totalOf("Weapon skills"):GetText(), "600c")
end

local function test_total_is_red_when_short()
  setup()
  W.money = 150
  trainerSpell(11, 10, "One", "Rank 1")
  trainerSpell(12, 10, "Two", "Rank 1")
  Window.Show(record())
  Assert.equal(color(totalOf("New skills")), "1,0.1,0.1")
end

local function test_total_sits_on_the_heading_line()
  setup()
  trainerSpell(11, 10, "One", "Rank 1")
  trainerSpell(12, 10, "Two", "Rank 1")
  Window.Show(record())
  local heading = headingOf("New skills")
  Assert.equal(topOf(totalOf("New skills")), topOf(heading))
  Assert.equal(topOf(heading) - topOf(shownRows()[1]), HEADING_TO_ROW)
end

local function test_total_hides_when_group_empties()
  setup()
  trainerSpell(11, 10, "One", "Rank 1")
  trainerSpell(12, 10, "Two", "Rank 1")
  Window.Show(record())
  local total = totalOf("New skills")
  W.known[11], W.known[12] = true, true
  Window.Show(record())
  Assert.equal(total:IsShown(), false)
end

local function test_total_hides_when_group_drops_below_two_priced()
  setup()
  trainerSpell(11, 10, "One", "Rank 1")
  trainerSpell(12, 10, "Two", "Rank 1")
  Window.Show(record())
  local total = totalOf("New skills")
  W.known[11] = true
  Window.Show(record())
  Assert.equal(total:IsShown(), false)
end

return function()
  test_new_skills_heading_shows_total()
  test_single_priced_skill_shows_no_total()
  test_total_counts_rows_past_the_cap()
  test_folded_group_keeps_its_total()
  test_total_is_red_when_short()
  test_total_sits_on_the_heading_line()
  test_total_hides_when_group_empties()
  test_total_hides_when_group_drops_below_two_priced()
end
