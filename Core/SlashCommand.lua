local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SlashCommand = {}

-- `/lui` opens the settings, `/lui test` shows the preview, `/lui test 40`
-- previews a ding to level 40; anything else opens the settings.
function SlashCommand.Register(openSettings, runTest)
  _G.SLASH_LEVELUPINFO1 = "/lui"
  _G.SlashCmdList["LEVELUPINFO"] = function(message)
    local argument = string.lower(string.match(message or "", "^%s*(.-)%s*$"))
    local level = string.match(argument, "^test%s+(%d+)$")
    if argument == "test" or level then
      runTest(tonumber(level))
    else
      openSettings()
    end
  end
end

ns.SlashCommand = SlashCommand
return SlashCommand
