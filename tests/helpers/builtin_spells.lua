-- Loads Data/BuiltinSpells.lua for one client from the given per-client data functions.
local BuiltinHelper = {}

-- byClient: { forever = function() return { PRIEST = levels } end, ... } or nil.
function BuiltinHelper.load(client, byClient)
  local ns = {
    Client = {
      Get = function()
        return client
      end,
    },
    ClassSpellData = byClient,
  }
  return assert(loadfile("Data/BuiltinSpells.lua"))("LevelUpInfo", ns), ns
end

return BuiltinHelper
