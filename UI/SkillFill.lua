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

local format = string.format
local ipairs = ipairs
local max = math.max
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
local GROUP_CAP = 4
local NO_LINES = {}
local NO_ENTRIES = {}
local HIDDEN = "hidden"

-- Skill groups in display order; a capped group shows its first `cap` rows
-- and a `+N more` toggle, or, expanded, all rows in a scroll box. A `fold`
-- group has a button that hides its rows behind a count in the heading;
-- `startFolded` folds it until the player opens it. Hidden holds every hidden
-- entry, whatever its own group. NEXT is filled apart, after the hint row:
-- `foldPerShow` folds it on every window show, `noDismiss` hides the row eye.
local GROUPS = {
  { group = "skill", title = "New skills", cap = GROUP_CAP, more = "+%d more new skills" },
  { group = "rank", title = "New ranks", cap = GROUP_CAP, more = "+%d more new ranks" },
  { group = "missed", title = "Not yet learned", cap = GROUP_CAP, fold = true, more = "+%d more not yet learned" },
  { group = "weapon", title = "Weapon skills", cap = GROUP_CAP, fold = true, more = "+%d more weapon skills" },
  { group = HIDDEN, title = "Hidden", cap = GROUP_CAP, fold = true, startFolded = true, more = "+%d more hidden" },
}
local NEXT =
  { group = "next", title = "Next at %d", cap = GROUP_CAP, fold = true, foldPerShow = true, noDismiss = true, more = "+%d more next level" }
local ALL_SPECS = {}
for index, spec in ipairs(GROUPS) do
  ALL_SPECS[index] = spec
end
ALL_SPECS[#GROUPS + 1] = NEXT

-- The window's skill area: group headings, skill rows, the hint row and the
-- Next at N group, added to the layout list of the window's content frame.
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
local dismissFn -- the window's dismiss/restore click: called with the row's skill name

-- A reused row that sat in another container (content or a box) moves over.
local function nextRow(parent)
  rowsUsed = rowsUsed + 1
  local row = rows[rowsUsed]
  if not row then
    row = SkillRow.Create(parent, AutoHide.Pause, AutoHide.Resume, dismissFn)
    rows[rowsUsed] = row
  elseif row:GetParent() ~= parent then
    row:SetParent(parent)
  end
  return row
end

local function addRow(entry, money, parent, noDismiss)
  local row = nextRow(parent)
  SkillRow.SetSkill(row, entry, money, noDismiss)
  -- A hidden row shows no change lines, so it requests no spell text.
  local lines = entry.previousSpellID ~= nil and entry.hidden ~= true
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
local function addHeading(spec, title, gap, expanded, total, money)
  local group = spec.group
  local heading = headings[group]
  heading:SetText(title)
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

-- A hidden entry sits only in the Hidden group; the others in their own.
local function belongs(spec, entry)
  if spec.group == HIDDEN then
    return entry.hidden == true
  end
  return entry.group == spec.group and entry.hidden ~= true
end

local function countIn(spec, entries)
  local count = 0
  for _, entry in ipairs(entries) do
    if belongs(spec, entry) then
      count = count + 1
    end
  end
  return count
end

-- `title` is the heading text; `gap` goes above it when the group has rows;
-- returns the row count (a folded group counts its folded-away rows, so the
-- next block's gap stays).
-- An expanded group a dismiss click shrank to its cap is collapsed for good: no
-- box, no toggle, and it does not come back expanded when entries return.
local function fillGroup(spec, title, entries, money, gap)
  local group = spec.group
  if spec.cap and SkillGroup.IsExpanded(group) and countIn(spec, entries) <= spec.cap then
    SkillGroup.CollapseOne(group)
  end
  local expanded = SkillGroup.IsExpanded(group)
  local folded = SkillGroup.IsFolded(group)
  local parent = content
  local count = 0
  local total = SkillList.GroupTotal(entries, group)
  for _, entry in ipairs(entries) do
    if belongs(spec, entry) then
      count = count + 1
      if count == 1 then
        parent = addHeading(spec, title, gap, expanded, total, money)
      end
      if not folded and (expanded or not spec.cap or count <= spec.cap) then
        if count > 1 then
          Layout.AddGap(parent, ROW_GAP)
        end
        addRow(entry, money, parent, spec.noDismiss)
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
    headings[group]:SetText(format(Text("%s (%d)"), title, count))
  end
  if spec.cap then
    fillToggle(spec, folded and 0 or count)
  end
  return count
end

-- Makes the group headings and the group widgets on `parent`, the window's
-- content frame, which every later call fills. `onDismiss(name)` runs on a
-- row's dismiss or restore click.
function SkillFill.Build(parent, onToggle, foldedGroups, onFold, onDismiss)
  content = parent
  dismissFn = onDismiss
  for _, spec in ipairs(ALL_SPECS) do
    headings[spec.group] = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  end
  SkillGroup.Build(content, ALL_SPECS, onToggle, foldedGroups, onFold)
end

-- The hint row, then the Next at N group (shown only when `nextEntries` has
-- entries). `gap` is the gap the skill groups left.
local function fillHintAndNext(hint, nextLevel, nextEntries, money, gap)
  if hint then
    Layout.AddGap(content, gap)
    local row = nextRow(content)
    SkillRow.SetHint(row)
    rowLines[rowsUsed] = false
    Layout.Add(row, content, 0, ROW_HEIGHT)
  end
  local nextGap = hint and GROUP_GAP or gap
  local title = nextLevel and format(Text(NEXT.title), nextLevel)
  fillGroup(NEXT, title, nextEntries or NO_ENTRIES, money, nextGap)
end

-- Adds the groups, the hint row and the Next at N group to the layout list;
-- `gainCount` gain lines above decide the first block's gap.
function SkillFill.Fill(entries, hint, nextLevel, nextEntries, gainCount)
  local money = _G.GetMoney()
  rowsUsed = 0
  _G.wipe(boxFirstRow)
  local gap = gainCount > 0 and GROUP_GAP or 0
  for _, spec in ipairs(GROUPS) do
    local count = fillGroup(spec, Text(spec.title), entries, money, gap)
    if count > 0 then
      gap = GROUP_GAP
    end
  end
  fillHintAndNext(hint, nextLevel, nextEntries, money, gap)
  for index = rowsUsed + 1, #rows do
    rows[index]:Hide()
  end
end

-- Each expanded group's scroll child is as tall as the rows placed in it.
function SkillFill.SizeBoxes(cursors)
  for _, spec in ipairs(ALL_SPECS) do
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
  local tallest = 0
  for _, spec in ipairs(ALL_SPECS) do
    local first = boxFirstRow[spec.group]
    if spec.cap and first and SkillGroup.IsExpanded(spec.group) then
      local last = min(first + spec.cap - 1, rowsUsed)
      local height = (last - first) * ROW_GAP
      for index = first, last do
        height = height + rows[index]:GetHeight()
      end
      SkillGroup.SetBoxHeight(spec.group, height)
      tallest = max(tallest, height)
    end
  end
  return tallest
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

-- Hides every group widget, the headings and the rows after a failed fill.
-- Runs only after Build.
function SkillFill.HideAll()
  SkillGroup.HideAll()
  for _, pool in ipairs(POOLS) do
    for _, region in pairs(pool) do
      region:Hide()
    end
  end
end

ns.SkillFill = SkillFill
return SkillFill
