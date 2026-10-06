local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")

local Text = Localization.Text
local format = string.format

local TRAINER_TEXTURES = "Interface\\ClassTrainerFrame\\TrainerTextures"
local HINT_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local ROW_WIDTH = 298
local ROW_HEIGHT = 47
local ICON_SIZE = 36
local PAD = 6
local HINT_WIDTH = 230
local SOURCE_WIDTH = 190
local SOURCE_GAP = 2

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

-- Second line for quest and weapon-master spells. NPC names and quest titles
-- are proper names and stay unlocalized; the place is a localized key.
local function sourceText(source)
  if source.kind == "quest" then
    return format(Text("Quest: %s · %s · %s"), source.quest, source.npc, Text(source.place))
  end
  return format(Text("Weapon master: %s · %s"), source.npc, Text(source.place))
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
  row.icon:SetPoint("LEFT", row, "LEFT", PAD, 0)
  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", PAD, -1)
  row.name:SetJustifyH("LEFT")
  row.rank = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  row.rank:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
  row.price = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.price:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -PAD, PAD)
  row.price:SetJustifyH("RIGHT")
  row.sourceLine = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  row.sourceLine:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -SOURCE_GAP)
  row.sourceLine:SetWidth(SOURCE_WIDTH)
  row.sourceLine:SetJustifyH("LEFT")
  row.sourceLine:SetWordWrap(false)
  row:SetScript("OnEnter", onEnter)
  row:SetScript("OnLeave", onLeave)
  return row
end

function SkillRow.SetSkill(row, entry, money)
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
  if entry.source then
    row.sourceLine:SetText(sourceText(entry.source))
    row.sourceLine:Show()
  else
    row.sourceLine:Hide()
  end
end

function SkillRow.SetHint(row)
  row.spellID = nil
  row.icon:SetTexture(HINT_ICON)
  row.name:SetWidth(HINT_WIDTH)
  row.name:SetText(Text("Visit your class trainer to see all new skills."))
  row.rank:SetText("")
  row.price:SetText("")
  row.sourceLine:Hide()
end

ns.SkillRow = SkillRow
return SkillRow
