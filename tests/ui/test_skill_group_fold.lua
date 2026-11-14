-- Fold state: saved flags, startFolded and the fold icon.
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local PLUS_ICON = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS_ICON = "Interface\\Buttons\\UI-MinusButton-Up"

-- Fresh fake client and module per test; AutoHide.Pause/Resume are counted.
local function setup()
  local W = Wow.Install()
  local ns = {}
  for _, path in ipairs({ "Core/Localization.lua", "Core/Events.lua", "UI/AutoHide.lua", "UI/ScrollBox.lua" }) do
    assert(loadfile(path))("LevelUpInfo", ns)
  end
  local t = { W = W, spy = { pause = 0, resume = 0 }, toggled = {} }
  ns.AutoHide.Pause = function()
    t.spy.pause = t.spy.pause + 1
  end
  ns.AutoHide.Resume = function()
    t.spy.resume = t.spy.resume + 1
  end
  t.SkillGroup = assert(loadfile("UI/SkillGroup.lua"))("LevelUpInfo", ns)
  t.content = _G.CreateFrame("Frame", nil, _G.UIParent)
  return t
end

local FOLD_SPECS = {
  { group = "missed", cap = 4, fold = true },
  { group = "weapon", cap = 4, fold = true },
  { group = "hidden", cap = 4, fold = true, startFolded = true },
  { group = "skill", cap = 4 },
}

-- Built with the saved fold flags `saved` (the db's foldedGroups).
local function builtFolding(saved)
  local t = setup()
  t.SkillGroup.Build(t.content, FOLD_SPECS, function() end, saved, function() end)
  return t
end

local function test_missing_fold_flag_follows_start_folded()
  local t = builtFolding({})
  Assert.equal(t.SkillGroup.IsFolded("missed"), false)
  Assert.equal(t.SkillGroup.IsFolded("weapon"), false)
  Assert.equal(t.SkillGroup.IsFolded("hidden"), true)
end

local function test_saved_boolean_beats_start_folded()
  local t = builtFolding({ hidden = false, weapon = true })
  Assert.equal(t.SkillGroup.IsFolded("hidden"), false)
  Assert.equal(t.SkillGroup.IsFolded("weapon"), true)
end

-- A save from before Hidden existed: only `true` flags, no `false`.
local function test_older_save_keeps_missed_folded_weapon_open_and_hidden_folded()
  local t = builtFolding({ missed = true })
  Assert.equal(t.SkillGroup.IsFolded("missed"), true)
  Assert.equal(t.SkillGroup.IsFolded("weapon"), false)
  Assert.equal(t.SkillGroup.IsFolded("hidden"), true)
end

local function test_flip_saves_booleans_and_never_clears_the_key()
  local saved = {}
  local t = builtFolding(saved)
  t.SkillGroup.Flip("hidden")
  Assert.equal(saved.hidden, false)
  Assert.equal(t.SkillGroup.IsFolded("hidden"), false)
  t.SkillGroup.Flip("hidden")
  Assert.equal(saved.hidden, true)
  t.SkillGroup.Flip("weapon")
  Assert.equal(saved.weapon, true)
  t.SkillGroup.Flip("weapon")
  Assert.equal(saved.weapon, false)
end

local function test_a_group_without_a_fold_button_is_never_folded()
  local t = builtFolding({ skill = true })
  Assert.equal(t.SkillGroup.IsFolded("skill"), false)
  Assert.equal(t.SkillGroup.IsFolded("nope"), false)
end

local function test_fold_icon_follows_the_start_state()
  local t = builtFolding({})
  Assert.equal(t.W.state(t.SkillGroup.FoldButton("hidden").foldIcon).texture, PLUS_ICON)
  Assert.equal(t.W.state(t.SkillGroup.FoldButton("weapon").foldIcon).texture, MINUS_ICON)
end

return function()
  test_missing_fold_flag_follows_start_folded()
  test_saved_boolean_beats_start_folded()
  test_older_save_keeps_missed_folded_weapon_open_and_hidden_folded()
  test_flip_saves_booleans_and_never_clears_the_key()
  test_a_group_without_a_fold_button_is_never_folded()
  test_fold_icon_follows_the_start_state()
end
