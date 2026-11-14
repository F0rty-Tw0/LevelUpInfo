-- The hide and show buttons' textures are our own TGA files. The client reads the
-- header literally, so a wrong type, size, depth or origin shows nothing or a flipped glyph.
local Assert = require("tests.helpers.assert")

local OPEN = "Media/EyeOpen.tga"
local CROSSED = "Media/EyeCrossed.tga"
local FILES = { OPEN, CROSSED }
local HEADER_SIZE = 18
local SIZE = 32
local BYTES_PER_PIXEL = 4
local GRAY = 0xD0
local MIN_VISIBLE = 40
local MAX_VISIBLE = 600
local SLASH_FIRST_X = 4
local SLASH_LAST_X = 27
local SLASH_HALF_WIDTH = 1
local GAP_DISTANCE = 2
local TYPE_UNCOMPRESSED_TRUE_COLOR = 2
local DESCRIPTOR_ALPHA8_TOP_LEFT = 0x28

local function readAll(path)
  local handle = assert(io.open(path, "rb"), "missing " .. path)
  local data = handle:read("*a")
  handle:close()
  return data
end

local function word(data, index)
  return string.byte(data, index) + 256 * string.byte(data, index + 1)
end

local function pixelAt(data, x, y)
  local at = HEADER_SIZE + (y * SIZE + x) * BYTES_PER_PIXEL + 1
  local blue, green, red, alpha = string.byte(data, at, at + 3)
  return { blue = blue, green = green, red = red, alpha = alpha }
end

-- Calls visit(x, y, pixel) for every pixel, rows top to bottom.
local function eachPixel(data, visit)
  for y = 0, SIZE - 1 do
    for x = 0, SIZE - 1 do
      visit(x, y, pixelAt(data, x, y))
    end
  end
end

local function isOnSlashColumns(x)
  return x >= SLASH_FIRST_X and x <= SLASH_LAST_X
end

local function isSlash(x, y)
  return isOnSlashColumns(x) and math.abs(x - y) <= SLASH_HALF_WIDTH
end

local function isGap(x, y)
  return isOnSlashColumns(x) and math.abs(x - y) == GAP_DISTANCE
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

-- Light gray, not white: the buttons set no vertex colour, so the art is the colour.
-- (Soft edges keep a partial alpha; only the colour is pinned.)
local function test_every_visible_pixel_is_light_gray_and_the_count_is_plausible()
  for _, path in ipairs(FILES) do
    local visible = 0
    eachPixel(readAll(path), function(x, y, pixel)
      if pixel.alpha == 0 then
        return
      end
      visible = visible + 1
      local where = path .. " at " .. x .. "," .. y
      Assert.equal(pixel.red, GRAY, where .. ": red")
      Assert.equal(pixel.green, GRAY, where .. ": green")
      Assert.equal(pixel.blue, GRAY, where .. ": blue")
    end)
    local plausible = visible >= MIN_VISIBLE and visible <= MAX_VISIBLE
    Assert.equal(plausible, true, path .. ": visible pixels " .. visible)
  end
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

-- The crossed eye is the open eye with a slash from the top left to the bottom right,
-- and a transparent gap along each side of it so the slash reads apart from the eye.
local function test_crossed_eye_is_the_open_eye_with_a_slash_and_a_gap()
  local open = readAll(OPEN)
  local crossed = readAll(CROSSED)
  eachPixel(open, function(x, y, openPixel)
    local expectOpaque = openPixel.alpha ~= 0
    if isSlash(x, y) then
      expectOpaque = true
    elseif isGap(x, y) then
      expectOpaque = false
    end
    local actual = pixelAt(crossed, x, y).alpha ~= 0
    Assert.equal(actual, expectOpaque, CROSSED .. " at " .. x .. "," .. y .. ": opaque")
  end)
end

-- The packager ignores tests, scripts and docs; the textures must ship.
local function test_pkgmeta_does_not_ignore_the_media_folder()
  for line in io.lines(".pkgmeta") do
    Assert.equal(string.find(line, "Media", 1, true), nil, ".pkgmeta mentions Media: " .. line)
  end
end

return function()
  test_header_is_uncompressed_32_by_32_32_bit_top_left()
  test_every_visible_pixel_is_light_gray_and_the_count_is_plausible()
  test_corners_are_transparent()
  test_crossed_eye_is_the_open_eye_with_a_slash_and_a_gap()
  test_pkgmeta_does_not_ignore_the_media_folder()
end
