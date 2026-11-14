-- The eye buttons' textures are our own TGA files. The client reads the header
-- literally, so a wrong type, size, depth or origin shows nothing or a flipped eye.
local Assert = require("tests.helpers.assert")

local FILES = { "Media/EyeOpen.tga", "Media/EyeClosed.tga" }
local HEADER_SIZE = 18
local SIZE = 32
local BYTES_PER_PIXEL = 4
local GRAY = 0xD0
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

-- Light gray on transparent: every visible pixel is #d0d0d0, and the eye is
-- neither blank nor a filled square.
local function test_pixels_are_light_gray_on_transparent_and_the_eyes_differ()
  local drawn = {}
  for index, path in ipairs(FILES) do
    local data = readAll(path)
    local visible = 0
    for pixel = 0, SIZE * SIZE - 1 do
      local at = HEADER_SIZE + pixel * BYTES_PER_PIXEL + 1
      local blue, green, red, alpha = string.byte(data, at, at + 3)
      if alpha > 0 then
        visible = visible + 1
        Assert.equal(red, GRAY, path .. ": red")
        Assert.equal(green, GRAY, path .. ": green")
        Assert.equal(blue, GRAY, path .. ": blue")
      end
    end
    Assert.equal(visible > 40 and visible < 600, true, path .. ": " .. visible .. " visible pixels")
    drawn[index] = data
  end
  Assert.equal(drawn[1] ~= drawn[2], true)
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
  test_pixels_are_light_gray_on_transparent_and_the_eyes_differ()
  test_corners_are_transparent()
  test_pkgmeta_does_not_ignore_the_media_folder()
end
