local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")
local SkillList = ns.SkillList or require("LevelUpInfo.Data.SkillList")
local NextLevel = ns.NextLevel or require("LevelUpInfo.Data.NextLevel")
local AutoHide = ns.AutoHide or require("LevelUpInfo.UI.AutoHide")
local ScrollBox = ns.ScrollBox or require("LevelUpInfo.UI.ScrollBox")
local SkillGroup = ns.SkillGroup or require("LevelUpInfo.UI.SkillGroup")
local SpellFacts = ns.SpellFacts or require("LevelUpInfo.Data.SpellFacts")
local Layout = ns.Layout or require("LevelUpInfo.UI.Layout")
local GainLines = ns.GainLines or require("LevelUpInfo.UI.GainLines")
local SkillFill = ns.SkillFill or require("LevelUpInfo.UI.SkillFill")

local format = string.format
local min = math.min
local select = select
local tinsert = table.insert
local tostring = tostring
local xpcall = xpcall

local Text = Localization.Text

local FRAME_NAME = "LevelUpInfoFrame"
local FRAME_WIDTH = 338
local CONTENT_WIDTH = 298
local CONTENT_LEFT = 19
local HEADER_HEIGHT = 68
local FOOTER_HEIGHT = 12
-- The view is wide enough for a group box's bar (box right + 4, 8 wide); a
-- view bar adds a column of the same size to the frame.
local VIEW_WIDTH = CONTENT_WIDTH + 12
local VIEW_BAR_COLUMN = 12
-- Room kept between the window and the top and bottom of the screen: the
-- height cap leaves it, and the clamp rect reaches this far past the frame.
local SCREEN_MARGIN = 16
-- Congratulation line in the header strip right of the portrait.
local HEADER_LEFT = 62
local HEADER_TOP = -35
local HEADER_WIDTH = 262

local Window = {}

local db
local frame
local view -- ScrollFrame around `content`; scrolls only when content is taller than the screen allows
local viewBar
local viewScroll = 0
local content
local reachedLine
local current
local skillEntries, skillHint -- skill list of `current`: built on Show, reused by Refresh
local nextLevel, nextEntries -- next level with trainer skills, built with skillEntries
-- Spells left out of `skillEntries` until their rank text loads; the last
-- one's load result builds the list again.
local waitingRanks = {}
-- Set while a fill runs, so a load result fired inside it starts no second fill.
local filling = false
-- Set by a failed fill or refresh: its layout list must not be replayed, so
-- the next refresh is a full fill.
local stale = false
local fill

-- A toggle click refills the shown record with the group's new state.
local function onToggle()
  if current and not filling then
    fill(current)
  end
end

-- A fold click changes the window's height: keep the top-left corner where it
-- is, so the window does not jump (unless the screen clamp has to move a
-- taller window back on screen). The anchor is not saved: the next show
-- applies the saved position again.
local function pinTop()
  local left, top = frame:GetLeft(), frame:GetTop() -- read before ClearAllPoints
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", left, top - _G.UIParent:GetTop() / frame:GetScale())
end

local function onFold(group)
  if current and not filling then
    SkillGroup.Flip(group)
    pinTop()
    fill(current)
  end
end

local function applyAnchor()
  frame:ClearAllPoints()
  local position = db.position
  if position then
    frame:SetPoint(position.point, _G.UIParent, position.point, position.x, position.y)
  else
    frame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 120)
  end
end

local function savePosition()
  frame:StopMovingOrSizing()
  local point, _, _, x, y = frame:GetPoint()
  db.position = { point = point, x = x, y = y }
end

local function errorHandler(err)
  return tostring(err) .. "\n" .. _G.debugstack()
end

local function buildHeader()
  frame:SetTitle(Text("Level Up!"))
  reachedLine = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  reachedLine:SetWidth(HEADER_WIDTH)
  reachedLine:SetJustifyH("LEFT")
  reachedLine:SetWordWrap(false)
  reachedLine:SetPoint("TOPLEFT", frame, "TOPLEFT", HEADER_LEFT, HEADER_TOP)
end

-- The mouse stays off so a drag on a gap or heading still moves the window;
-- the wheel is turned on only while the content overflows.
local function buildView()
  view = _G.CreateFrame("ScrollFrame", nil, frame)
  view:SetWidth(VIEW_WIDTH)
  view:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, -HEADER_HEIGHT)
  view:EnableMouseWheel(false)
  content = _G.CreateFrame("Frame", nil, view)
  content:SetSize(CONTENT_WIDTH, 1)
  view:SetScrollChild(content)
  viewBar = ScrollBox.Attach(view, 1, function(value)
    viewScroll = value
  end)
end

local function build()
  frame = _G.CreateFrame("Frame", FRAME_NAME, _G.UIParent, "ButtonFrameTemplate")
  frame:Hide()
  -- Escape closes it: Blizzard's CloseSpecialWindows hides every frame named here.
  tinsert(_G.UISpecialFrames, FRAME_NAME)
  _G.ButtonFrameTemplate_HideButtonBar(frame)
  frame:SetPortraitToUnit("player")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:SetClampRectInsets(0, 0, SCREEN_MARGIN, -SCREEN_MARGIN)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", savePosition)
  frame:HookScript("OnHide", function()
    current = nil
    SpellFacts.Stop()
    _G.wipe(waitingRanks)
  end)
  AutoHide.Attach(frame, db)
  frame.CloseButton:SetScript("OnClick", AutoHide.Close)
  buildHeader()
  buildView()
  GainLines.Build(content)
  SkillFill.Build(content, onToggle, db.foldedGroups, onFold)
end

local function isRankWaiting(spellID)
  local waiting = SpellFacts.Waiting(spellID)
  if waiting then
    waitingRanks[spellID] = true
  end
  return waiting
end

local function fillSkills(record, gainCount)
  if not skillEntries then
    local class = select(2, _G.UnitClass("player"))
    local race = select(2, _G.UnitRace("player"))
    local faction = _G.UnitFactionGroup("player")
    skillEntries, skillHint = SkillList.Build(db.trainers, class, race, faction, record.fromLevel, record.toLevel, isRankWaiting)
    nextLevel, nextEntries = NextLevel.Find(db.trainers, class, race, faction, record.toLevel)
  end
  SkillFill.Fill(skillEntries, skillHint, nextLevel, nextEntries, gainCount)
end

local function applyLayout()
  SkillFill.FitBoxes()
  local height, cursors = Layout.Run(content)
  SkillFill.SizeBoxes(cursors)
  content:SetHeight(height)
  -- The screen height in frame units, less the margins and the frame's chrome.
  local maxView = _G.UIParent:GetHeight() / frame:GetScale() - 2 * SCREEN_MARGIN - HEADER_HEIGHT - FOOTER_HEIGHT
  local viewHeight = min(height, maxView)
  view:SetHeight(viewHeight)
  viewBar:SetHeight(viewHeight)
  viewScroll = ScrollBox.SetRange(viewBar, viewHeight, height, viewScroll)
  view:SetVerticalScroll(viewScroll)
  local overflow = height > viewHeight
  view:EnableMouseWheel(overflow)
  frame:SetSize(FRAME_WIDTH + (overflow and VIEW_BAR_COLUMN or 0), HEADER_HEIGHT + viewHeight + FOOTER_HEIGHT)
end

-- Runs `work` under the `filling` guard; an error hides everything, marks
-- the window stale and reports it.
local function guarded(work)
  filling = true
  local ok, err = xpcall(work, errorHandler)
  filling = false
  if not ok then
    Layout.Reset()
    GainLines.HideAll()
    SkillFill.HideAll()
    viewBar:Hide()
    view:EnableMouseWheel(false)
    stale = true
    _G.geterrorhandler()(err)
  end
end

function fill(record)
  guarded(function()
    reachedLine:SetText(format(Text("Congratulations! You reached level %d."), record.toLevel))
    Layout.Reset()
    fillSkills(record, GainLines.Fill(content, record))
    applyLayout()
    stale = false
  end)
end

function Window.Install(savedDB)
  db = savedDB
end

function Window.Current()
  return current
end

function Window.Frame()
  return frame
end

-- A shown window is placed again: the height cap depends on the scale. Not
-- while stale (the layout list was reset) or inside a fill.
function Window.ApplyScale()
  if not frame then
    return
  end
  frame:SetScale(db.scale)
  if frame:IsShown() and not stale and not filling then
    guarded(applyLayout)
  end
end

function Window.ResetPosition()
  db.position = nil
  if frame then
    applyAnchor()
  end
end

-- The one show and re-show path: stop the countdown, refill, restart it
-- (Resume does nothing while the mouse is over the window).
function Window.Show(record)
  if not frame then
    build()
  end
  AutoHide.Pause()
  current = record
  skillEntries = nil
  nextLevel, nextEntries = nil, nil
  _G.wipe(waitingRanks)
  SkillGroup.Collapse()
  -- Scale first: the fill caps the height with it.
  frame:SetScale(db.scale)
  viewScroll = 0
  fill(record)
  applyAnchor()
  frame:Show()
  AutoHide.Resume()
end

-- Spell text for `spellID` arrived: updates only the rows using it (nil or
-- stale: a full refill; the last spell left out for its rank text: the list is
-- built again). Keeps countdown, anchor, scale, expanded state and scroll position.
function Window.Refresh(spellID)
  if filling or not current or not frame or not frame:IsShown() then
    return
  end
  if spellID ~= nil and waitingRanks[spellID] then
    waitingRanks[spellID] = nil
    if next(waitingRanks) == nil then
      skillEntries = nil
      nextLevel, nextEntries = nil, nil
      fill(current)
    end
  elseif spellID == nil or stale then
    fill(current)
  else
    -- Places the window again only when a shown row uses `spellID`.
    guarded(function()
      if SkillFill.RefreshRows(spellID) then
        applyLayout()
      end
    end)
  end
end

ns.Window = Window
return Window
