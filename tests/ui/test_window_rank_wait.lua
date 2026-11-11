-- A trainer entry above your level has no cached rank text. On the first show
-- the spell's own rank text may not be loaded: the row waits for it, then the
-- list is built again (player report, 2026-11-11, Forever: Binding Heal showed
-- with no rank, though Rank 2 can't be bought without Rank 1).
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local Window

local LOAD_EVENT = "SPELL_DATA_LOAD_RESULT"
local SMITE_2 = 591
local BINDING_2 = 32546
local FADE = 586
local SHACKLE = 9484

local function setup()
  W = Wow.Install()
  W.money = 1000
  local db = {
    duration = 10,
    reducedMotion = false,
    scale = 1.0,
    foldedGroups = {},
    trainers = { PRIEST = { covered = { Scourge = 60 }, levels = {} } },
  }
  local levels = db.trainers.PRIEST.levels
  -- Smite Rank 2 is cached and known: the probe proving lookups by name work.
  W.spells[SMITE_2] = { name = "Smite", iconID = 1, subtext = "Rank 2" }
  W.known[SMITE_2] = true
  levels[6] = { [SMITE_2] = { cost = 10, rank = "Rank 2", races = { Scourge = true } } }
  levels[60] = {}
  local ns = { OtherSources = {} }
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
  ns.SpellFacts.Install(Window.Refresh)
  return levels
end

-- A cached spell above your level: the trainer left its rank text empty.
local function cacheUnranked(levels, spellID, name)
  W.spells[spellID] = { name = name, iconID = 2, description = "" }
  levels[60][spellID] = { cost = 50, rank = "", races = { Scourge = true } }
end

local function record()
  return { fromLevel = 59, toLevel = 60, gains = { health = 15 }, before = { health = 100 } }
end

local function rowNamed(name)
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "Button" and widget.name and widget:IsShown() then
      if widget.name:GetText() == name then
        return widget
      end
    end
  end
end

local function load(spellID, subtext)
  W.spells[spellID].subtext = subtext
  W.spells[spellID].description = "Spell text."
  W.broadcast(LOAD_EVENT, spellID, true)
end

local function test_unbuyable_rank_never_shows_while_its_rank_text_loads()
  local levels = setup()
  cacheUnranked(levels, BINDING_2, "Binding Heal")
  Window.Show(record())
  Assert.equal(rowNamed("Binding Heal"), nil)
  Assert.equal(W.calls.RequestLoadSpellData, 1)
  load(BINDING_2, "Rank 2")
  Assert.equal(rowNamed("Binding Heal"), nil)
end

local function test_new_unranked_spell_shows_once_its_text_loads()
  local levels = setup()
  cacheUnranked(levels, FADE, "Fade")
  Window.Show(record())
  Assert.equal(rowNamed("Fade"), nil)
  load(FADE, nil)
  Assert.equal(rowNamed("Fade") ~= nil, true)
end

-- One rebuild for the whole wait, not one per arriving spell.
local function test_list_is_built_again_once_the_last_waiting_spell_loads()
  local levels = setup()
  cacheUnranked(levels, FADE, "Fade")
  cacheUnranked(levels, SHACKLE, "Shackle Undead")
  Window.Show(record())
  load(FADE, nil)
  Assert.equal(rowNamed("Fade"), nil)
  load(SHACKLE, nil)
  Assert.equal(rowNamed("Fade") ~= nil, true)
  Assert.equal(rowNamed("Shackle Undead") ~= nil, true)
end

return function()
  test_unbuyable_rank_never_shows_while_its_rank_text_loads()
  test_new_unranked_spell_shows_once_its_text_loads()
  test_list_is_built_again_once_the_last_waiting_spell_loads()
end
