local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Format = require("LevelUpInfo.Core.Format")

local BACKSLASH = string.char(92)

local function test_arrow_is_the_expand_arrow_texture_at_font_height()
  local path = table.concat({ "Interface", "ChatFrame", "ChatFrameExpandArrow" }, BACKSLASH)
  Assert.equal(Format.ARROW, "|T" .. path .. ":0|t")
end

local function test_color_code_is_hex_of_rounded_rgb()
  Wow.Install()
  Assert.equal(Format.ColorCode(_G.GREEN_FONT_COLOR), "|cff1aff1a")
  Assert.equal(Format.ColorCode(_G.RED_FONT_COLOR), "|cffff1a1a")
end

return function()
  test_arrow_is_the_expand_arrow_texture_at_font_height()
  test_color_code_is_hex_of_rounded_rgb()
end
