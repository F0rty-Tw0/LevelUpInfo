-- Builds Data/OtherSources.lua for one client, with the real data modules.
local OtherSourcesHelper = {}

OtherSourcesHelper.CLIENTS = { "forever", "era", "tbc" }

function OtherSourcesHelper.buildFor(client)
  local ns = {
    Client = {
      Get = function()
        return client
      end,
    },
  }
  assert(loadfile("Data/WeaponMasters.lua"))("LevelUpInfo", ns)
  assert(loadfile("Data/QuestSpells.lua"))("LevelUpInfo", ns)
  return assert(loadfile("Data/OtherSources.lua"))("LevelUpInfo", ns), ns
end

return OtherSourcesHelper
