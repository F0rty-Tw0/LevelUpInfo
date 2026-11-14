-- The dismiss and restore buttons' textures are our own TGA files. The client reads the
-- header literally, so a wrong type, size, depth or origin shows nothing or a flipped glyph.
local Assert = require("tests.helpers.assert")

local FILES = { "Media/Dismiss.tga", "Media/Restore.tga" }
local HEADER_SIZE = 18
local SIZE = 32
local BYTES_PER_PIXEL = 4
local WHITE = 0xFF
local OPAQUE = 255
local TYPE_UNCOMPRESSED_TRUE_COLOR = 2
local DESCRIPTOR_ALPHA8_TOP_LEFT = 0x28
local BAR = { x1 = 6, x2 = 25, y1 = 14, y2 = 17 }
local STEM = { x1 = 14, x2 = 17, y1 = 6, y2 = 25 }

local function readAll(path)
  local handle = assert(io.open(path, "rb"), "missing " .. path)
  local data = handle:read("*a")
  handle:close()
  return data
end

local function word(data, index)
  return string.byte(data, index) + 256 * string.byte(data, index + 1)
end

local function inside(box, x, y)
  return x >= box.x1 and x <= box.x2 and y >= box.y1 and y <= box.y2
end

local function isMinus(x, y)
  return inside(BAR, x, y)
end

local function isPlus(x, y)
  return inside(BAR, x, y) or inside(STEM, x, y)
end

-- Reads every pixel: opaque ones must be exactly `shape` and pure white, all others alpha 0.
local function assertGlyph(path, shape)
  local data = readAll(path)
  for y = 0, SIZE - 1 do
    for x = 0, SIZE - 1 do
      local at = HEADER_SIZE + (y * SIZE + x) * BYTES_PER_PIXEL + 1
      local blue, green, red, alpha = string.byte(data, at, at + 3)
      local where = path .. " at " .. x .. "," .. y
      if shape(x, y) then
        Assert.equal(alpha, OPAQUE, where .. ": alpha")
        Assert.equal(red, WHITE, where .. ": red")
        Assert.equal(green, WHITE, where .. ": green")
        Assert.equal(blue, WHITE, where .. ": blue")
      else
        Assert.equal(alpha, 0, where .. ": alpha")
      end
    end
  end
end

local function test_header_is_uncompressed_32_by_32_32_bit_top_left()
  for _, path in ipairs(FILES) do
    local data = readAll(path)
    Assert.equal(string.byte(data, 1), 0, path .. ": id length")
    Assert.equal(string.byte(data, 2), 0, path .. ": colour map type")
    Assert.equal(string.byte(data, 3), TYPE_UNCOMPRESSED_TRUE_COLOR, path .. ": image type")
    Assert.equal(word(data, 4) + word(data, 6) + string.byte(data, 8), 0, path .. ": colour map spec")
    Assert.equal(word(data, 9) + word(data, 11), 0, path .. ": x and y origin")
    Assert.equal(word(data, 13), SIZE, path .. ": width")
    Assert.equal(word(data, 15), SIZE, path .. ": height")
    Assert.equal(string.byte(data, 17), 32, path .. ": bits per pixel")
    Assert.equal(string.byte(data, 18), DESCRIPTOR_ALPHA8_TOP_LEFT, path .. ": 8 alpha bits, top-left origin")
    Assert.equal(#data, HEADER_SIZE + SIZE * SIZE * BYTES_PER_PIXEL, path .. ": size")
  end
end

-- White so the button's vertex colour tints it red or green.
local function test_dismiss_is_a_white_minus_bar_on_transparent()
  assertGlyph("Media/Dismiss.tga", isMinus)
end

local function test_restore_is_a_white_plus_on_transparent()
  assertGlyph("Media/Restore.tga", isPlus)
end

-- The corner pixel (top-left) is empty: proves the origin is not read upside down
-- into a filled background, and the art has its margin.
local function test_corners_are_transparent()
  for _, path in ipairs(FILES) do
    local data = readAll(path)
    Assert.equal(string.byte(data, HEADER_SIZE + 4), 0, path .. ": top-left alpha")
    Assert.equal(string.byte(data, #data), 0, path .. ": bottom-right alpha")
  end
end

-- The packager ignores tests, scripts and docs; the textures must ship.
local function test_pkgmeta_does_not_ignore_the_media_folder()
  for line in io.lines(".pkgmeta") do
    Assert.equal(string.find(line, "Media", 1, true), nil, ".pkgmeta mentions Media: " .. line)
  end
end

return function()
  test_header_is_uncompressed_32_by_32_32_bit_top_left()
  test_dismiss_is_a_white_minus_bar_on_transparent()
  test_restore_is_a_white_plus_on_transparent()
  test_corners_are_transparent()
  test_pkgmeta_does_not_ignore_the_media_folder()
end
