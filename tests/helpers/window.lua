-- Shared fixture for the window tests: loads the window's modules into one ns
-- and finds the widgets the tests assert on. install() remembers the fake
-- client, so the finders read the current test's widgets.
local Wow = require("tests.helpers.wow")

local WindowHelper = {}

local LOAD_EVENT = "SPELL_DATA_LOAD_RESULT"

-- The modules the window tests load into one ns, in TOC order (checked by
-- tests/integration/test_toc_load_order.lua), then the window itself.
-- Data/BuiltinSpells, Data/RankDiff and Data/WeaponIcons (and what they import)
-- are left out on purpose and come in through the require fallback; tests stub
-- ns.OtherSources, and loading BuiltinSpells here would add built-in rows.
WindowHelper.FILES = {
  "Core/Localization.lua",
  "Core/Format.lua",
  "Core/Events.lua",
  "Data/TrainerCache.lua",
  "Data/SkillList.lua",
  "Data/NextLevel.lua",
  "Data/RankChanges.lua",
  "Data/SpellFacts.lua",
  "UI/AutoHide.lua",
  "UI/ScrollBox.lua",
  "UI/SkillRow.lua",
  "UI/SkillGroup.lua",
  "UI/Layout.lua",
  "UI/GainLines.lua",
  "UI/NextLevelLine.lua",
  "UI/SkillFill.lua",
  "UI/Window.lua",
}

local W

-- A fresh fake client (Wow.Install), kept for the finders below.
function WindowHelper.install()
  W = Wow.Install()
  return W
end

-- Loads FILES into `ns` and returns the window module, not yet installed.
function WindowHelper.load(ns)
  for _, file in ipairs(WindowHelper.FILES) do
    assert(loadfile(file))("LevelUpInfo", ns)
  end
  return ns.Window
end

-- The settings every window test starts from, with this trainer cache.
function WindowHelper.db(trainers)
  return { duration = 10, reducedMotion = false, scale = 1.0, foldedGroups = {}, trainers = trainers }
end

-- A trainer cache entry the Scourge player can buy.
function WindowHelper.spell(cost, rank)
  return { cost = cost, rank = rank, races = { Scourge = true } }
end

function WindowHelper.mana(cost)
  return { { cost = cost, name = "MANA" } }
end

function WindowHelper.frame()
  return _G.LevelUpInfoFrame
end

-- The scroll child of the window's own view.
function WindowHelper.content()
  for _, widget in ipairs(W.frames) do
    if widget:GetParent() == WindowHelper.frame() and W.state(widget).frameType == "ScrollFrame" then
      return widget:GetScrollChild()
    end
  end
end

-- Shown skill rows placed straight on the content, in pool order.
function WindowHelper.shownRows()
  local rows = {}
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "Button" and widget.name and widget:GetParent() == WindowHelper.content() and widget:IsShown() then
      rows[#rows + 1] = widget
    end
  end
  return rows
end

function WindowHelper.rowNames()
  local names = {}
  for _, row in ipairs(WindowHelper.shownRows()) do
    names[#names + 1] = row.name:GetText()
  end
  return table.concat(names, "|")
end

-- Shown skill rows anywhere, scroll boxes included.
function WindowHelper.allRows()
  local rows = {}
  for _, widget in ipairs(W.frames) do
    if W.state(widget).frameType == "Button" and widget.name and widget:IsShown() then
      rows[#rows + 1] = widget
    end
  end
  return rows
end

function WindowHelper.rowNamed(name)
  for _, row in ipairs(WindowHelper.allRows()) do
    if row.name:GetText() == name then
      return row
    end
  end
end

-- The shown toggle (a Button without a name) whose label contains `text`.
function WindowHelper.toggle(text)
  for _, widget in ipairs(W.frames) do
    local label = widget.label
    if W.state(widget).frameType == "Button" and not widget.name and label and widget:IsShown() then
      if string.find(label:GetText() or "", text, 1, true) then
        return widget
      end
    end
  end
end

function WindowHelper.click(button)
  W.fireScript(button, "OnClick")
end

function WindowHelper.shownBoxes()
  local count = 0
  for _, widget in ipairs(W.frames) do
    -- The window's own view (a child of the frame) is always shown; skip it.
    if W.state(widget).frameType == "ScrollFrame" and widget:IsShown() and widget:GetParent() ~= WindowHelper.frame() then
      count = count + 1
    end
  end
  return count
end

-- Shown rank-change lines under one row.
function WindowHelper.shownLines(row)
  local count = 0
  for _, line in ipairs(row.changeLines) do
    if line:IsShown() then
      count = count + 1
    end
  end
  return count
end

-- The client finishes loading this spell's text.
function WindowHelper.loadText(spellID, text)
  W.spells[spellID].description = text
  W.broadcast(LOAD_EVENT, spellID, true)
end

function WindowHelper.topOf(region)
  return select(5, region:GetPoint(1))
end

-- Every later fill fails inside `guarded` (GetMoney throws); the error is swallowed.
function WindowHelper.breakFill()
  W.def("geterrorhandler", function()
    return function() end
  end)
  W.def("debugstack", function()
    return ""
  end)
  W.def("GetMoney", function()
    error("boom")
  end)
end

return WindowHelper
