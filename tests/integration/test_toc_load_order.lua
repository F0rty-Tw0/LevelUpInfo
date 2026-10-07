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

local function test_toc_icon_points_at_the_shipped_tga()
  -- The game adds the extension; the path is relative to the AddOns folder.
  local iconPath
  for line in io.lines("LevelUpInfo.toc") do
    iconPath = iconPath or string.match(line, "^## IconTexture: (.+)$")
  end
  local prefix = "Interface\\AddOns\\LevelUpInfo\\"
  assert(iconPath and string.sub(iconPath, 1, #prefix) == prefix, tostring(iconPath))
  local file = string.gsub(string.sub(iconPath, #prefix + 1), "\\", "/") .. ".tga"
  assert(io.open(file, "rb"), "missing " .. file)
end

-- Slot order Era, Forever, TBC; release.sh rewrites the numbers, so only the shape is fixed.
local function test_toc_interface_lists_era_forever_and_tbc()
  local interface
  for line in io.lines("LevelUpInfo.toc") do
    interface = interface or string.match(line, "^## Interface: (.+)$")
  end
  assert(string.match(interface or "", "^1%d%d%d%d, 1%d%d%d%d, 2%d%d%d%d$"), tostring(interface))
end

return function()
  test_every_toc_file_loads_in_order_without_require()
  test_toc_lists_bootstrap_last()
  test_toc_icon_points_at_the_shipped_tga()
  test_toc_interface_lists_era_forever_and_tbc()
end
