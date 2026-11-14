local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SlashCommand = {}

-- `/lui` opens the settings, `/lui test` shows the preview, `/lui test 40`
-- previews a ding to level 40, `/lui last` brings back the last level-up;
-- anything else opens the settings.
function SlashCommand.Register(openSettings, runTest, showLast)
  _G.SLASH_LEVELUPINFO1 = "/lui"
  _G.SlashCmdList["LEVELUPINFO"] = function(message)
    local argument = string.lower(string.match(message or "", "^%s*(.-)%s*$"))
    local level = string.match(argument, "^test%s+(%d+)$")
    if argument == "test" or level then
      runTest(tonumber(level))
    elseif argument == "last" then
      showLast()
    else
      openSettings()
    end
  end
end

ns.SlashCommand = SlashCommand
return SlashCommand
