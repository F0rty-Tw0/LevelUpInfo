local Assert = require("tests.helpers.assert")
local Localization = require("LevelUpInfo.Core.Localization")

local HINT = "Visit your class trainer to see all new skills."

local function test_english_text_is_its_own_key()
  Assert.equal(Localization.Text(HINT), HINT)
end

local function test_catalog_entry_replaces_english_text()
  Localization.catalog[HINT] = "Besuche deinen Klassenlehrer, um alle neuen Fertigkeiten zu sehen."
  Assert.equal(Localization.Text(HINT), "Besuche deinen Klassenlehrer, um alle neuen Fertigkeiten zu sehen.")
  Localization.catalog[HINT] = nil
end

return function()
  test_english_text_is_its_own_key()
  test_catalog_entry_replaces_english_text()
end
