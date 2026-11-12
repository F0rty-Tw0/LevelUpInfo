local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")
local SkillList = ns.SkillList or require("LevelUpInfo.Data.SkillList")
local SpellFacts = ns.SpellFacts or require("LevelUpInfo.Data.SpellFacts")
local AutoHide = ns.AutoHide or require("LevelUpInfo.UI.AutoHide")
local SkillRow = ns.SkillRow or require("LevelUpInfo.UI.SkillRow")
local SkillGroup = ns.SkillGroup or require("LevelUpInfo.UI.SkillGroup")
local Layout = ns.Layout or require("LevelUpInfo.UI.Layout")
local NextLevelLine = ns.NextLevelLine or require("LevelUpInfo.UI.NextLevelLine")

local format = string.format
local ipairs = ipairs
local min = math.min
local pairs = pairs

local Text = Localization.Text

local LINE_HEIGHT = 16
local HEADING_HEIGHT = 24
-- Spacing hierarchy: rows of a group sit closest, a heading sits right on its
-- rows, blocks (stats, each skill group, the hint) are pushed further apart.
local GROUP_GAP = 14
local ROW_HEIGHT = 47
local ROW_GAP = 4
local TEXT_LEFT = 4
local GROUP_CAP = 5
local NO_LINES = {}

-- Skill groups in display order; a capped group shows its first `cap` rows
-- and a `+N more` toggle, or, expanded, all rows in a scroll box. A `fold`
-- group has a button that hides its rows behind a count in the heading.
local GROUPS = {
  { group = "skill", title = "New skills", cap = GROUP_CAP, more = "+%d more new skills" },
  { group = "rank", title = "New ranks", cap = GROUP_CAP, more = "+%d more new ranks" },
  { group = "missed", title = "Not yet learned", cap = GROUP_CAP, fold = true, more = "+%d more not yet learned" },
  { group = "weapon", title = "Weapon skills", cap = GROUP_CAP, fold = true, more = "+%d more weapon skills" },
}

-- The window's skill area: group headings, skill rows, the hint row and the
-- next-level line, added to the layout list of the window's content frame.
-- Headings are made in Build, rows on first use; both are reused after.
local SkillFill = {}

local content
local rows = {}
local headings = {}
local POOLS = { rows, headings } -- all hidden when a fill fails
local rowsUsed
local rowEntries = {} -- entry shown in rows[i], read only when rowLines[i]
local rowLines = {} -- whether rows[i] shows change lines
local boxFirstRow = {} -- group → index in `rows` of its expanded box's first row

-- A reused row that sat in another container (content or a box) moves over.
local function nextRow(parent)
  rowsUsed = rowsUsed + 1
  local row = rows[rowsUsed]
  if not row then
    row = SkillRow.Create(parent, AutoHide.Pause, AutoHide.Resume)
    rows[rowsUsed] = row
  elseif row:GetParent() ~= parent then
    row:SetParent(parent)
  end
  return row
end

local function addRow(entry, money, parent)
  local row = nextRow(parent)
  SkillRow.SetSkill(row, entry, money)
  local lines = entry.previousSpellID ~= nil
  rowLines[rowsUsed] = lines
  if lines then
    rowEntries[rowsUsed] = entry
    SkillRow.SetChanges(row, SpellFacts.Changes(entry.previousSpellID, entry.spellID) or NO_LINES)
  end
  Layout.Add(row, parent, 0, nil)
end

-- A capped group's toggle: `Show less` under its box, `+N more` when
-- collapsed rows were left out, else hidden.
local function fillToggle(spec, count)
  local group = spec.group
  local text
  if SkillGroup.IsExpanded(group) and count > 0 then
    text = Text("Show less")
  else
    SkillGroup.HideBox(group)
    if count > spec.cap then
      text = format(Text(spec.more), count - spec.cap)
    end
  end
  if text then
    Layout.Add(SkillGroup.Toggle(group, text), content, 0, LINE_HEIGHT)
  else
    SkillGroup.HideToggle(group)
  end
end

-- Heading (and, for a foldable group, its button on the same line) with `gap`
-- above; returns the row parent: content, or the box of an expanded group.
local function addHeading(spec, gap, expanded, total, money)
  local group = spec.group
  local heading = headings[group]
  heading:SetText(Text(spec.title))
  Layout.AddGap(content, gap)
  if spec.fold then
    Layout.Add(SkillGroup.FoldButton(group), content, 0, 0)
  end
  if total then
    Layout.Add(SkillGroup.Total(group, total, money), content, 0, 0)
  end
  Layout.Add(heading, content, TEXT_LEFT, HEADING_HEIGHT)
  if not expanded then
    return content
  end
  local box, child = SkillGroup.Box(group)
  boxFirstRow[group] = rowsUsed + 1
  Layout.Add(box, content, 0, nil)
  return child
end

-- `gap` goes above the heading when the group has rows; returns the row count
-- (a folded group counts its hidden rows, so the next block's gap stays).
local function fillGroup(spec, entries, money, gap)
  local group = spec.group
  local expanded = SkillGroup.IsExpanded(group)
  local folded = SkillGroup.IsFolded(group)
  local parent = content
  local count = 0
  local total = SkillList.GroupTotal(entries, group)
  for _, entry in ipairs(entries) do
    if entry.group == group then
      count = count + 1
      if count == 1 then
        parent = addHeading(spec, gap, expanded, total, money)
      end
      if not folded and (expanded or not spec.cap or count <= spec.cap) then
        if count > 1 then
          Layout.AddGap(parent, ROW_GAP)
        end
        addRow(entry, money, parent)
      end
    end
  end
  if not total then
    SkillGroup.HideTotal(group)
  end
  if count == 0 then
    headings[group]:Hide()
    SkillGroup.HideFoldButton(group)
  elseif folded then
    headings[group]:SetText(format(Text("%s (%d)"), Text(spec.title), count))
  end
  if spec.cap then
    fillToggle(spec, folded and 0 or count)
  end
  return count
end

-- Makes the group headings and the group widgets on `parent`, the window's
-- content frame, which every later call fills.
function SkillFill.Build(parent, onToggle, foldedGroups, onFold)
  content = parent
  for _, spec in ipairs(GROUPS) do
    headings[spec.group] = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  end
  SkillGroup.Build(content, GROUPS, onToggle, foldedGroups, onFold)
end

-- Adds the groups, the hint row and the next-level line to the layout list;
-- `gainCount` gain lines above decide the first block's gap.
function SkillFill.Fill(entries, hint, nextLevel, nextEntries, gainCount)
  local money = _G.GetMoney()
  rowsUsed = 0
  _G.wipe(boxFirstRow)
  local gap = gainCount > 0 and GROUP_GAP or 0
  for _, spec in ipairs(GROUPS) do
    if fillGroup(spec, entries, money, gap) > 0 then
      gap = GROUP_GAP
    end
  end
  if hint then
    Layout.AddGap(content, gap)
    local row = nextRow(content)
    SkillRow.SetHint(row)
    rowLines[rowsUsed] = false
    Layout.Add(row, content, 0, ROW_HEIGHT)
  end
  local line = NextLevelLine.Set(content, nextLevel, nextEntries)
  if line then
    Layout.AddGap(content, hint and GROUP_GAP or gap)
    Layout.Add(line, content, TEXT_LEFT, LINE_HEIGHT)
  end
  for index = rowsUsed + 1, #rows do
    rows[index]:Hide()
  end
end

-- Each expanded group's scroll child is as tall as the rows placed in it.
function SkillFill.SizeBoxes(cursors)
  for _, spec in ipairs(GROUPS) do
    if spec.cap and SkillGroup.IsExpanded(spec.group) then
      local _, child = SkillGroup.Box(spec.group)
      SkillGroup.SetContentHeight(spec.group, cursors[child] or 0)
    end
  end
end

-- An expanded box is as tall as its group's first `cap` rows and the gaps
-- between them, so expanding keeps the group's size and only adds the
-- scrollbar. Runs before placing: the layout reads the box's height.
function SkillFill.FitBoxes()
  for _, spec in ipairs(GROUPS) do
    local first = boxFirstRow[spec.group]
    if spec.cap and first and SkillGroup.IsExpanded(spec.group) then
      local last = min(first + spec.cap - 1, rowsUsed)
      local height = (last - first) * ROW_GAP
      for index = first, last do
        height = height + rows[index]:GetHeight()
      end
      SkillGroup.SetBoxHeight(spec.group, height)
    end
  end
end

-- Recomputes the change lines of shown rows that use `spellID`; returns
-- whether one matched (the window then places itself again).
function SkillFill.RefreshRows(spellID)
  local changed = false
  for index = 1, rowsUsed do
    local entry = rowEntries[index]
    if rowLines[index] and (entry.spellID == spellID or entry.previousSpellID == spellID) then
      SkillRow.SetChanges(rows[index], SpellFacts.Changes(entry.previousSpellID, entry.spellID) or NO_LINES)
      changed = true
    end
  end
  return changed
end

-- Hides every group widget, the next-level line, the headings and the rows
-- after a failed fill. Runs only after Build.
function SkillFill.HideAll()
  SkillGroup.HideAll()
  NextLevelLine.Set(content, nil)
  for _, pool in ipairs(POOLS) do
    for _, region in pairs(pool) do
      region:Hide()
    end
  end
end

ns.SkillFill = SkillFill
return SkillFill
