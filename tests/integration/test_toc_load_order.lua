-- The live client exposes a global `require` that throws for unknown modules,
-- so every file's `ns.X or require(...)` fallback must never be reached:
-- each dependency has to load earlier in the TOC.
local Wow = require("tests.helpers.wow")

local function tocFiles()
  local files = {}
  for line in io.lines("LevelUpInfo.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" then
      -- Drop load conditions such as " [AllowLoadGameType mainline]".
      files[#files + 1] = string.gsub(line, "%s*%[.*$", "")
    end
  end
  return files
end

local function test_every_toc_file_loads_in_order_without_require()
  Wow.Install()
  local savedRequire = require
  _G.require = function(moduleName)
    error("Invalid import: No module with that name exists (" .. tostring(moduleName) .. ")")
  end

  local ns = {}
  local ok, err = pcall(function()
    for _, file in ipairs(tocFiles()) do
      local chunk = assert(loadfile(file))
      local loaded, loadErr = pcall(chunk, "LevelUpInfo", ns)
      assert(loaded, file .. ": " .. tostring(loadErr))
    end
  end)

  _G.require = savedRequire
  assert(ok, tostring(err))
end

local function test_toc_lists_bootstrap_last()
  local files = tocFiles()
  assert(files[#files] == "Bootstrap.lua", tostring(files[#files]))
end

local function test_toc_icon_is_a_blizzard_icon()
  -- IconTexture must exist and point at a Blizzard icon (no shipped .tga yet).
  local iconPath
  for line in io.lines("LevelUpInfo.toc") do
    iconPath = iconPath or string.match(line, "^## IconTexture: (.+)$")
  end
  assert(iconPath == "Interface\\Icons\\INV_Misc_Book_09", tostring(iconPath))
end

return function()
  test_every_toc_file_loads_in_order_without_require()
  test_toc_lists_bootstrap_last()
  test_toc_icon_is_a_blizzard_icon()
end
