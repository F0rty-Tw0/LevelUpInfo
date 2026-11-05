local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AutoHide = ns.AutoHide or require("LevelUpInfo.UI.AutoHide")

local ipairs = ipairs
local pairs = pairs
local max = math.max
local min = math.min

local BOX_HEIGHT = 235
local CONTENT_WIDTH = 298
local TOGGLE_HEIGHT = 16
local BAR_WIDTH = 8
local BAR_GAP = 4
local THUMB_HEIGHT = 24
local WHEEL_STEP = 47
local TRACK_ALPHA = 0.1
local TEXT_LEFT = 4
local THUMB_FILE = "Interface\\Buttons\\UI-ScrollBar-Knob"
local FONT_REST = "GameFontDisableSmall"
local FONT_HOVER = "GameFontHighlightSmall"
local FOLD_HEIGHT = 24 -- the window's heading line height
local FOLD_ICON_SIZE = 16
local ICON_OPEN = "Interface\\Buttons\\UI-MinusButton-Up"
local ICON_FOLDED = "Interface\\Buttons\\UI-PlusButton-Up"

-- Per group: the "+N more" / "Show less" toggle and scroll box of a capped
-- one (with its expanded flag and scroll position), and the fold button of a
-- foldable one. It never places anything: the window's layout does. Toggles
-- and fold buttons are built with the window, a group's box, child and bar on
-- its first Box call.
local SkillGroup = {}

local parent
local groups = {}
local foldedByGroup -- the saved fold flags: group → true

local function pause()
  AutoHide.Pause()
end

local function resume()
  AutoHide.Resume()
end

local function scrollTo(state, value)
  state.scroll = value
  if state.bar then
    state.bar:SetValue(value)
    state.box:SetVerticalScroll(value)
  end
end

local function collapse(state)
  state.expanded = false
  scrollTo(state, 0)
end

local function newToggle(group, onToggle)
  local toggle = _G.CreateFrame("Button", nil, parent)
  toggle:SetSize(CONTENT_WIDTH, TOGGLE_HEIGHT)
  local label = toggle:CreateFontString(nil, "ARTWORK", FONT_REST)
  label:SetPoint("TOPLEFT", TEXT_LEFT, 0)
  label:SetJustifyH("LEFT")
  toggle.label = label
  toggle:SetScript("OnClick", function()
    local state = groups[group]
    state.expanded = not state.expanded
    if not state.expanded then
      scrollTo(state, 0)
    end
    onToggle(group)
  end)
  toggle:SetScript("OnEnter", function()
    pause()
    label:SetFontObject(FONT_HOVER)
  end)
  toggle:SetScript("OnLeave", function()
    resume()
    label:SetFontObject(FONT_REST)
  end)
  toggle:Hide()
  return toggle
end

local function newFoldButton(group, onFold)
  local button = _G.CreateFrame("Button", nil, parent)
  button:SetSize(CONTENT_WIDTH, FOLD_HEIGHT)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(FOLD_ICON_SIZE, FOLD_ICON_SIZE)
  icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
  button.foldIcon = icon
  button:SetScript("OnClick", function()
    onFold(group)
  end)
  button:SetScript("OnEnter", pause)
  button:SetScript("OnLeave", resume)
  button:Hide()
  return button
end

local function newBar(box, state)
  local bar = _G.CreateFrame("Slider", nil, box)
  bar:SetOrientation("VERTICAL")
  bar:SetSize(BAR_WIDTH, BOX_HEIGHT)
  bar:SetPoint("TOPLEFT", box, "TOPRIGHT", BAR_GAP, 0)
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetColorTexture(1, 1, 1, TRACK_ALPHA)
  local thumb = bar:CreateTexture(nil, "ARTWORK")
  thumb:SetSize(BAR_WIDTH, THUMB_HEIGHT)
  thumb:SetTexture(THUMB_FILE)
  bar:SetThumbTexture(thumb)
  bar:SetValueStep(1)
  bar:SetObeyStepOnDrag(true)
  bar:EnableMouse(true)
  bar:SetScript("OnValueChanged", function(_, value)
    state.scroll = value
    box:SetVerticalScroll(value)
  end)
  bar:SetScript("OnEnter", pause)
  bar:SetScript("OnLeave", resume)
  bar:Hide()
  return bar
end

local function newBox(state)
  local box = _G.CreateFrame("ScrollFrame", nil, parent)
  box:SetSize(CONTENT_WIDTH, BOX_HEIGHT)
  box:EnableMouseWheel(true)
  box:EnableMouse(true)
  local child = _G.CreateFrame("Frame", nil, box)
  child:SetWidth(CONTENT_WIDTH)
  box:SetScrollChild(child)
  local bar = newBar(box, state)
  box:SetScript("OnMouseWheel", function(_, delta)
    bar:SetValue(bar:GetValue() - delta * WHEEL_STEP)
  end)
  box:SetScript("OnEnter", pause)
  box:SetScript("OnLeave", resume)
  state.box, state.child, state.bar = box, child, bar
end

function SkillGroup.Build(content, specs, onToggle, foldedGroups, onFold)
  parent = content
  foldedByGroup = foldedGroups
  for _, spec in ipairs(specs) do
    if spec.cap then
      groups[spec.group] = { expanded = false, scroll = 0 }
      groups[spec.group].toggle = newToggle(spec.group, onToggle)
    end
    if spec.fold then
      groups[spec.group].foldButton = newFoldButton(spec.group, onFold)
    end
  end
end

-- Only a group with a fold button can be folded.
function SkillGroup.IsFolded(group)
  local state = groups[group]
  return state ~= nil and state.foldButton ~= nil and foldedByGroup[group] == true
end

-- The group's fold button with the icon for its current state.
function SkillGroup.FoldButton(group)
  local button = groups[group].foldButton
  button.foldIcon:SetTexture(SkillGroup.IsFolded(group) and ICON_FOLDED or ICON_OPEN)
  return button
end

function SkillGroup.HideFoldButton(group)
  local state = groups[group]
  if state and state.foldButton then
    state.foldButton:Hide()
  end
end

function SkillGroup.IsExpanded(group)
  local state = groups[group]
  return state ~= nil and state.expanded
end

function SkillGroup.Collapse()
  for _, state in pairs(groups) do
    collapse(state)
  end
end

-- Flips the group's saved fold flag and drops its expansion and scroll.
function SkillGroup.Flip(group)
  foldedByGroup[group] = not foldedByGroup[group] or nil
  collapse(groups[group])
end

function SkillGroup.Toggle(group, text)
  local toggle = groups[group].toggle
  toggle.label:SetText(text)
  return toggle
end

function SkillGroup.Box(group)
  local state = groups[group]
  if not state.box then
    newBox(state)
  end
  return state.box, state.child
end

function SkillGroup.HideToggle(group)
  local state = groups[group]
  if state then
    state.toggle:Hide()
  end
end

function SkillGroup.HideBox(group)
  local state = groups[group]
  if state and state.box then
    state.box:Hide()
  end
end

function SkillGroup.HideAll()
  for group in pairs(groups) do
    SkillGroup.HideToggle(group)
    SkillGroup.HideBox(group)
    SkillGroup.HideFoldButton(group)
  end
end

-- The box and bar are as tall as the rows a collapsed group shows.
function SkillGroup.SetBoxHeight(group, height)
  local state = groups[group]
  state.boxHeight = height
  state.box:SetHeight(height)
  state.bar:SetHeight(height)
end

-- The kept scroll position is clamped to the new range.
function SkillGroup.SetContentHeight(group, height)
  local state = groups[group]
  local range = max(0, height - (state.boxHeight or BOX_HEIGHT))
  local scroll = min(state.scroll, range)
  state.child:SetHeight(height)
  state.bar:SetMinMaxValues(0, range)
  state.bar:SetShown(range > 0)
  scrollTo(state, scroll)
end

ns.SkillGroup = SkillGroup
return SkillGroup
