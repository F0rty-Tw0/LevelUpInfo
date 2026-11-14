-- The Dismiss all / Restore all buttons on the group headings, through the window.
local Assert = require("tests.helpers.assert")
local WindowHelper = require("tests.helpers.window")

local W
local ns
local Window
local db
local charDB

local frame = WindowHelper.frame
local rowNames = WindowHelper.rowNames
local headings = WindowHelper.headings
local click = WindowHelper.click
local foldButtons = WindowHelper.foldButtons

local MISSED_LEVEL = 5
local MISSED_BASE = 1000
local SKILL_LEVEL = 10
local SKILL_SPELL = 2000
local WEAPON_BASE = 3000
local CAP = 4 -- SkillFill GROUP_CAP

-- Fresh fake client, modules, db and character table per test. The priest cache
-- starts empty and covers level 10 (no hint row).
local function setup(otherSources)
  W = WindowHelper.install()
  W.money = 1000
  db = WindowHelper.db({ PRIEST = { covered = { Scourge = 10 }, levels = {} } })
  charDB = WindowHelper.charDB()
  ns = { OtherSources = { PRIEST = otherSources or {} } }
  Window = WindowHelper.load(ns)
  Window.Install(db, charDB)
  ns.SpellFacts.Install(Window.Refresh)
end

local function trainerSpell(spellID, level, name)
  W.spells[spellID] = { name = name, iconID = spellID }
  db.trainers.PRIEST.levels[level] = db.trainers.PRIEST.levels[level] or {}
  db.trainers.PRIEST.levels[level][spellID] = { cost = 100, rank = "Rank 1", races = { Scourge = true } }
end

local function weaponRow(spellID, name)
  W.spells[spellID] = { name = name, iconID = spellID }
  return { spellID = spellID, level = 1, kind = "weapon", faction = "Horde", npc = "N", place = "P", cost = 100 }
end

local function addMissed(count)
  for index = 1, count do
    trainerSpell(MISSED_BASE + index, MISSED_LEVEL, "Missed " .. index)
  end
end

local function record()
  return { fromLevel = 9, toLevel = 10, gains = { health = 15 }, before = { health = 100 } }
end

local function clickGroupButton(group)
  click(ns.SkillGroup.GroupButton(group))
end

local function hiddenNames()
  local names = {}
  for name in pairs(charDB.hidden) do
    names[#names + 1] = name
  end
  table.sort(names)

  return table.concat(names, "|")
end

-- Six Not yet learned skills: two past the cap of four.
local function test_dismiss_all_hides_every_not_yet_learned_skill()
  setup()
  addMissed(CAP + 2)
  Window.Show(record())
  clickGroupButton("missed")
  Assert.equal(hiddenNames(), "Missed 1|Missed 2|Missed 3|Missed 4|Missed 5|Missed 6")
  Assert.equal(headings(), "Stats|Hidden (6)")
end

local function test_dismiss_all_on_a_folded_group_hides_all_its_entries()
  setup()
  addMissed(CAP + 2)
  Window.Show(record())
  click(foldButtons()[1])
  Assert.equal(headings(), "Stats|Not yet learned (6)")
  clickGroupButton("missed")
  Assert.equal(hiddenNames(), "Missed 1|Missed 2|Missed 3|Missed 4|Missed 5|Missed 6")
  Assert.equal(headings(), "Stats|Hidden (6)")
end

local function test_dismiss_all_skips_entries_without_a_name()
  setup()
  addMissed(2)
  trainerSpell(MISSED_BASE + 3, MISSED_LEVEL, "")
  Window.Show(record())
  clickGroupButton("missed")
  Assert.equal(hiddenNames(), "Missed 1|Missed 2")
  Assert.equal(charDB.hidden[""], nil)
end

local function test_dismiss_all_on_not_yet_learned_leaves_other_groups_alone()
  local otherSources = {}
  setup(otherSources)
  addMissed(2)
  trainerSpell(SKILL_SPELL, SKILL_LEVEL, "Smite")
  otherSources[1] = weaponRow(WEAPON_BASE + 1, "Axe")
  Window.Show(record())
  clickGroupButton("missed")
  Assert.equal(hiddenNames(), "Missed 1|Missed 2")
  Assert.equal(rowNames(), "Smite|Axe")
end

local function test_dismiss_all_on_weapon_skills_hides_only_weapon_rows()
  local otherSources = {}
  setup(otherSources)
  addMissed(2)
  trainerSpell(SKILL_SPELL, SKILL_LEVEL, "Smite")
  otherSources[1] = weaponRow(WEAPON_BASE + 1, "Axe")
  otherSources[2] = weaponRow(WEAPON_BASE + 2, "Mace")
  Window.Show(record())
  clickGroupButton("weapon")
  Assert.equal(hiddenNames(), "Axe|Mace")
  Assert.equal(rowNames(), "Smite|Missed 1|Missed 2")
end

local function test_restore_all_brings_every_hidden_skill_back()
  setup()
  addMissed(CAP + 2)
  charDB.hidden["Missed 1"] = true
  charDB.hidden["Missed 5"] = true
  charDB.hidden["Elsewhere"] = true
  Window.Show(record())
  Assert.equal(headings(), "Stats|Not yet learned|Hidden (2)")
  clickGroupButton("hidden")
  Assert.equal(next(charDB.hidden), nil)
  Assert.equal(headings(), "Stats|Not yet learned")
  Assert.equal(rowNames(), "Missed 1|Missed 2|Missed 3|Missed 4")
end

-- Alt+Z: the window hides and drops its record; unlike the options button,
-- the heading buttons then change nothing.
local function test_group_buttons_do_nothing_without_a_live_record()
  setup()
  addMissed(2)
  charDB.hidden["Elsewhere"] = true
  Window.Show(record())
  W.fireScript(frame(), "OnHide")
  clickGroupButton("missed")
  Assert.equal(hiddenNames(), "Elsewhere")
  clickGroupButton("hidden")
  Assert.equal(hiddenNames(), "Elsewhere")
end

return function()
  test_dismiss_all_hides_every_not_yet_learned_skill()
  test_dismiss_all_on_a_folded_group_hides_all_its_entries()
  test_dismiss_all_skips_entries_without_a_name()
  test_dismiss_all_on_not_yet_learned_leaves_other_groups_alone()
  test_dismiss_all_on_weapon_skills_hides_only_weapon_rows()
  test_restore_all_brings_every_hidden_skill_back()
  test_group_buttons_do_nothing_without_a_live_record()
end
