local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local floor = math.floor
local format = string.format

local COLOR_SCALE = 255

-- Shared text pieces for the window's lines.
local Format = {}

-- The dropdown submenu arrow as an inline texture; height 0 = the line's font
-- height. The game font has no `→` glyph (seen in game).
Format.ARROW = "|TInterface\\ChatFrame\\ChatFrameExpandArrow:0|t"

local function to255(c)
  return floor(c * COLOR_SCALE + 0.5)
end

-- "|cffRRGGBB" from a Blizzard color object.
function Format.ColorCode(color)
  local r, g, b = color:GetRGB()
  return format("|cff%02x%02x%02x", to255(r), to255(g), to255(b))
end

ns.Format = Format
return Format
