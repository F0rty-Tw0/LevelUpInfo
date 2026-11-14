local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")

local concat = table.concat
local format = string.format
local ipairs = ipairs

local Text = Localization.Text

local LINE_FONT = "GameFontHighlightSmall"
local LINE_WIDTH = 290
local LINE_HEIGHT = 16
local SEPARATOR = ", "

-- The window's last line: what the trainer teaches at the next level that
-- has something. One font string, made on first use and reused after.
local NextLevelLine = {}

local line

local function skillText(entry)
  return entry.rank ~= "" and format(Text("%s (%s)"), entry.name, entry.rank) or entry.name
end

local function createLine(parent)
  local made = parent:CreateFontString(nil, "ARTWORK", LINE_FONT)
  made:SetWidth(LINE_WIDTH)
  made:SetHeight(LINE_HEIGHT)
  made:SetJustifyH("LEFT")
  made:SetWordWrap(false)
  return made
end

-- Sets the line's text and returns it (the layout pass shows it); a nil level
-- hides a line made before and returns nil.
function NextLevelLine.Set(parent, level, entries)
  if level == nil then
    if line then
      line:Hide()
    end
    return nil
  end
  line = line or createLine(parent)
  local texts = {}
  for index, entry in ipairs(entries) do
    texts[index] = skillText(entry)
  end
  line:SetText(format(Text("Next at %d: %s"), level, concat(texts, SEPARATOR)))
  return line
end

ns.NextLevelLine = NextLevelLine
return NextLevelLine
