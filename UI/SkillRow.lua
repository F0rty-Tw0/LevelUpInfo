local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")

local Text = Localization.Text
local format = string.format
local ipairs = ipairs
local max = math.max

local TRAINER_TEXTURES = "Interface\\ClassTrainerFrame\\TrainerTextures"
local HINT_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local ROW_WIDTH = 298
local ROW_HEIGHT = 47
local ICON_SIZE = 36
local PAD = 6
local HINT_WIDTH = 230
local SOURCE_WIDTH = 190
local SOURCE_GAP = 2
local ICON_TOP = (ROW_HEIGHT - ICON_SIZE) / 2
local CHANGE_LINE_HEIGHT = 12
local NO_LINES = {}
local sourceLines = {}

-- One trainer-style row. Its fields (icon, name, rank, price) belong to our
-- own frame; Blizzard frames are never touched.
local SkillRow = {}

local function onEnter(row)
  if row.spellID then
    _G.GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    _G.GameTooltip:SetSpellByID(row.spellID)
    _G.GameTooltip:Show()
  end
  row.onEnter()
end

local function onLeave(row)
  if row.spellID then
    _G.GameTooltip:Hide()
  end
  row.onLeave()
end

local function newTexture(row, layer, firstCoord, lastCoord)
  local texture = row:CreateTexture(nil, layer)
  texture:SetAllPoints()
  texture:SetTexture(TRAINER_TEXTURES)
  texture:SetTexCoord(0.00195313, 0.57421875, firstCoord, lastCoord)
  return texture
end

-- Two lines under the name for quest and weapon-master spells (one line is
-- too narrow). NPC names and quest titles are proper names and stay
-- unlocalized; the place is a localized key. Fills a reused buffer.
local function sourceText(source)
  local place = Text(source.place)
  if source.kind == "quest" then
    sourceLines[1] = format(Text("Quest: %s"), source.quest)
    sourceLines[2] = format(Text("%s · %s"), source.npc, place)
  else
    sourceLines[1] = format(Text("Weapon master: %s"), source.npc)
    sourceLines[2] = place
  end
  return sourceLines
end

-- Change line i sits under the name; lines are spaced by exactly the row's
-- growth per line, so the price (anchored BOTTOMRIGHT) lines up with the last.
local function newChangeLine(row, i)
  local line = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  line:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -(SOURCE_GAP + (i - 1) * CHANGE_LINE_HEIGHT))
  line:SetSize(SOURCE_WIDTH, CHANGE_LINE_HEIGHT)
  line:SetJustifyH("LEFT")
  line:SetWordWrap(false)
  row.changeLines[i] = line
  return line
end

function SkillRow.Create(parent, enterFn, leaveFn)
  local row = _G.CreateFrame("Button", nil, parent)
  row:SetSize(ROW_WIDTH, ROW_HEIGHT)
  row.onEnter, row.onLeave = enterFn, leaveFn
  row.background = newTexture(row, "BACKGROUND", 0.65820313, 0.75)
  row.highlight = newTexture(row, "HIGHLIGHT", 0.75390625, 0.84570313)
  row.highlight:SetBlendMode("ADD")
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(ICON_SIZE, ICON_SIZE)
  row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", PAD, -ICON_TOP)
  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", PAD, -1)
  row.name:SetJustifyH("LEFT")
  row.rank = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  row.rank:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
  row.price = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.price:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -PAD, PAD)
  row.price:SetJustifyH("RIGHT")
  row.changeLines = {}
  row:SetScript("OnEnter", onEnter)
  row:SetScript("OnLeave", onLeave)
  return row
end

-- Shows one line per text (font strings created only past the row's highest
-- count so far), hides the rest and grows the row downward. Returns its height.
function SkillRow.SetChanges(row, lines)
  for i, text in ipairs(lines) do
    local line = row.changeLines[i] or newChangeLine(row, i)
    line:SetText(text)
    line:Show()
  end
  for i = #lines + 1, #row.changeLines do
    row.changeLines[i]:Hide()
  end
  local height = ROW_HEIGHT + max(0, #lines - 1) * CHANGE_LINE_HEIGHT
  row:SetHeight(height)
  return height
end

function SkillRow.SetSkill(row, entry, money)
  SkillRow.SetChanges(row, entry.source and sourceText(entry.source) or NO_LINES)
  row.spellID = entry.spellID
  row.icon:SetTexture(entry.icon)
  row.name:SetWidth(0)
  row.name:SetText(entry.name)
  row.rank:SetText(entry.rank)
  if entry.cost then
    row.price:SetText(_G.GetMoneyString(entry.cost))
    local color = money >= entry.cost and _G.HIGHLIGHT_FONT_COLOR or _G.RED_FONT_COLOR
    row.price:SetTextColor(color:GetRGB())
  else
    row.price:SetText("")
  end
end

function SkillRow.SetHint(row)
  SkillRow.SetChanges(row, NO_LINES)
  row.spellID = nil
  row.icon:SetTexture(HINT_ICON)
  row.name:SetWidth(HINT_WIDTH)
  row.name:SetText(Text("Visit your class trainer to see all new skills."))
  row.rank:SetText("")
  row.price:SetText("")
end

ns.SkillRow = SkillRow
return SkillRow
