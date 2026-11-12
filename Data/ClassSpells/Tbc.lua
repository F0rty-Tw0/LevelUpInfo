local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Priest class-trainer data, TBC Anniversary 2.5.x. Source: Wowhead teaches lists of npc 376 and npc 4606 (identical after racials removed).
-- cost is the base trainer price in copper (no reputation discount); race-only spells excluded.
ns.ClassSpellData = ns.ClassSpellData or {}
ns.ClassSpellData.tbc = function()
  return {
    PRIEST = {
      [1] = {
        [1243] = { cost = 10, rank = "Rank 1" }, -- Power Word: Fortitude
      },
      [4] = {
        [589] = { cost = 100, rank = "Rank 1" }, -- Shadow Word: Pain
        [2052] = { cost = 100, rank = "Rank 2" }, -- Lesser Heal
      },
      [6] = {
        [17] = { cost = 100, rank = "Rank 1" }, -- Power Word: Shield
        [591] = { cost = 100, rank = "Rank 2" }, -- Smite
      },
      [8] = {
        [139] = { cost = 200, rank = "Rank 1" }, -- Renew
        [586] = { cost = 200, rank = "Rank 1" }, -- Fade
      },
      [10] = {
        [594] = { cost = 300, rank = "Rank 2" }, -- Shadow Word: Pain
        [2006] = { cost = 300, rank = "Rank 1" }, -- Resurrection
        [2053] = { cost = 300, rank = "Rank 3" }, -- Lesser Heal
        [8092] = { cost = 300, rank = "Rank 1" }, -- Mind Blast
      },
      [12] = {
        [588] = { cost = 800, rank = "Rank 1" }, -- Inner Fire
        [592] = { cost = 800, rank = "Rank 2" }, -- Power Word: Shield
        [1244] = { cost = 800, rank = "Rank 2" }, -- Power Word: Fortitude
      },
      [14] = {
        [528] = { cost = 1200, rank = "" }, -- Cure Disease
        [598] = { cost = 1200, rank = "Rank 3" }, -- Smite
        [6074] = { cost = 1200, rank = "Rank 2" }, -- Renew
        [8122] = { cost = 1200, rank = "Rank 1" }, -- Psychic Scream
      },
      [16] = {
        [2054] = { cost = 1600, rank = "Rank 1" }, -- Heal
        [8102] = { cost = 1600, rank = "Rank 2" }, -- Mind Blast
      },
      [18] = {
        [527] = { cost = 2000, rank = "Rank 1" }, -- Dispel Magic
        [600] = { cost = 2000, rank = "Rank 3" }, -- Power Word: Shield
        [970] = { cost = 2000, rank = "Rank 3" }, -- Shadow Word: Pain
      },
      [20] = {
        [453] = { cost = 3000, rank = "Rank 1" }, -- Mind Soothe
        [2061] = { cost = 3000, rank = "Rank 1" }, -- Flash Heal
        [6075] = { cost = 3000, rank = "Rank 3" }, -- Renew
        [6346] = { cost = 800, rank = "" }, -- Fear Ward
        [7128] = { cost = 3000, rank = "Rank 2" }, -- Inner Fire
        [9484] = { cost = 3000, rank = "Rank 1" }, -- Shackle Undead
        [9578] = { cost = 3000, rank = "Rank 2" }, -- Fade
        [14914] = { cost = 3000, rank = "Rank 1" }, -- Holy Fire
      },
      [22] = {
        [984] = { cost = 4000, rank = "Rank 4" }, -- Smite
        [2010] = { cost = 4000, rank = "Rank 2" }, -- Resurrection
        [2055] = { cost = 4000, rank = "Rank 2" }, -- Heal
        [2096] = { cost = 4000, rank = "Rank 1" }, -- Mind Vision
        [8103] = { cost = 4000, rank = "Rank 3" }, -- Mind Blast
      },
      [24] = {
        [1245] = { cost = 5000, rank = "Rank 3" }, -- Power Word: Fortitude
        [3747] = { cost = 5000, rank = "Rank 4" }, -- Power Word: Shield
        [8129] = { cost = 5000, rank = "Rank 1" }, -- Mana Burn
        [15262] = { cost = 5000, rank = "Rank 2" }, -- Holy Fire
      },
      [26] = {
        [992] = { cost = 6000, rank = "Rank 4" }, -- Shadow Word: Pain
        [6076] = { cost = 6000, rank = "Rank 4" }, -- Renew
        [9472] = { cost = 6000, rank = "Rank 2" }, -- Flash Heal
      },
      [28] = {
        [6063] = { cost = 8000, rank = "Rank 3" }, -- Heal
        [8104] = { cost = 8000, rank = "Rank 4" }, -- Mind Blast
        [8124] = { cost = 8000, rank = "Rank 2" }, -- Psychic Scream
        [15430] = { cost = 400, rank = "Rank 2" }, -- Holy Nova
        [17311] = { cost = 400, rank = "Rank 2" }, -- Mind Flay
      },
      [30] = {
        [596] = { cost = 10000, rank = "Rank 1" }, -- Prayer of Healing
        [602] = { cost = 10000, rank = "Rank 3" }, -- Inner Fire
        [605] = { cost = 10000, rank = "Rank 1" }, -- Mind Control
        [976] = { cost = 10000, rank = "Rank 1" }, -- Shadow Protection
        [1004] = { cost = 10000, rank = "Rank 5" }, -- Smite
        [6065] = { cost = 10000, rank = "Rank 5" }, -- Power Word: Shield
        [9579] = { cost = 10000, rank = "Rank 3" }, -- Fade
        [15263] = { cost = 10000, rank = "Rank 3" }, -- Holy Fire
      },
      [32] = {
        [552] = { cost = 11000, rank = "" }, -- Abolish Disease
        [6077] = { cost = 11000, rank = "Rank 5" }, -- Renew
        [8131] = { cost = 11000, rank = "Rank 2" }, -- Mana Burn
        [9473] = { cost = 11000, rank = "Rank 3" }, -- Flash Heal
      },
      [34] = {
        [1706] = { cost = 12000, rank = "" }, -- Levitate
        [2767] = { cost = 12000, rank = "Rank 5" }, -- Shadow Word: Pain
        [6064] = { cost = 12000, rank = "Rank 4" }, -- Heal
        [8105] = { cost = 12000, rank = "Rank 5" }, -- Mind Blast
        [10880] = { cost = 12000, rank = "Rank 3" }, -- Resurrection
      },
      [36] = {
        [988] = { cost = 14000, rank = "Rank 2" }, -- Dispel Magic
        [2791] = { cost = 14000, rank = "Rank 4" }, -- Power Word: Fortitude
        [6066] = { cost = 14000, rank = "Rank 6" }, -- Power Word: Shield
        [8192] = { cost = 14000, rank = "Rank 2" }, -- Mind Soothe
        [15264] = { cost = 14000, rank = "Rank 4" }, -- Holy Fire
        [15431] = { cost = 700, rank = "Rank 3" }, -- Holy Nova
        [17312] = { cost = 700, rank = "Rank 3" }, -- Mind Flay
      },
      [38] = {
        [6060] = { cost = 16000, rank = "Rank 6" }, -- Smite
        [6078] = { cost = 16000, rank = "Rank 6" }, -- Renew
        [9474] = { cost = 16000, rank = "Rank 4" }, -- Flash Heal
      },
      [40] = {
        [996] = { cost = 18000, rank = "Rank 2" }, -- Prayer of Healing
        [1006] = { cost = 18000, rank = "Rank 4" }, -- Inner Fire
        [2060] = { cost = 18000, rank = "Rank 1" }, -- Greater Heal
        [8106] = { cost = 18000, rank = "Rank 6" }, -- Mind Blast
        [9485] = { cost = 18000, rank = "Rank 2" }, -- Shackle Undead
        [9592] = { cost = 18000, rank = "Rank 4" }, -- Fade
        [10874] = { cost = 18000, rank = "Rank 3" }, -- Mana Burn
        [14818] = { cost = 900, rank = "Rank 2" }, -- Divine Spirit
      },
      [42] = {
        [10888] = { cost = 22000, rank = "Rank 3" }, -- Psychic Scream
        [10892] = { cost = 22000, rank = "Rank 6" }, -- Shadow Word: Pain
        [10898] = { cost = 22000, rank = "Rank 7" }, -- Power Word: Shield
        [10957] = { cost = 22000, rank = "Rank 2" }, -- Shadow Protection
        [15265] = { cost = 22000, rank = "Rank 5" }, -- Holy Fire
      },
      [44] = {
        [10909] = { cost = 24000, rank = "Rank 2" }, -- Mind Vision
        [10911] = { cost = 24000, rank = "Rank 2" }, -- Mind Control
        [10915] = { cost = 24000, rank = "Rank 5" }, -- Flash Heal
        [10927] = { cost = 24000, rank = "Rank 7" }, -- Renew
        [17313] = { cost = 1200, rank = "Rank 4" }, -- Mind Flay
        [27799] = { cost = 1200, rank = "Rank 4" }, -- Holy Nova
      },
      [46] = {
        [10881] = { cost = 26000, rank = "Rank 4" }, -- Resurrection
        [10933] = { cost = 26000, rank = "Rank 7" }, -- Smite
        [10945] = { cost = 26000, rank = "Rank 7" }, -- Mind Blast
        [10963] = { cost = 26000, rank = "Rank 2" }, -- Greater Heal
      },
      [48] = {
        [10875] = { cost = 28000, rank = "Rank 4" }, -- Mana Burn
        [10899] = { cost = 28000, rank = "Rank 8" }, -- Power Word: Shield
        [10937] = { cost = 28000, rank = "Rank 5" }, -- Power Word: Fortitude
        [15266] = { cost = 28000, rank = "Rank 6" }, -- Holy Fire
        [21562] = { cost = 28000, rank = "Rank 1" }, -- Prayer of Fortitude
      },
      [50] = {
        [10893] = { cost = 30000, rank = "Rank 7" }, -- Shadow Word: Pain
        [10916] = { cost = 30000, rank = "Rank 6" }, -- Flash Heal
        [10928] = { cost = 30000, rank = "Rank 8" }, -- Renew
        [10941] = { cost = 30000, rank = "Rank 5" }, -- Fade
        [10951] = { cost = 30000, rank = "Rank 5" }, -- Inner Fire
        [10960] = { cost = 30000, rank = "Rank 3" }, -- Prayer of Healing
        [14819] = { cost = 1500, rank = "Rank 3" }, -- Divine Spirit
        [27870] = { cost = 1200, rank = "Rank 2" }, -- Lightwell
      },
      [52] = {
        [10946] = { cost = 38000, rank = "Rank 8" }, -- Mind Blast
        [10953] = { cost = 38000, rank = "Rank 3" }, -- Mind Soothe
        [10964] = { cost = 38000, rank = "Rank 3" }, -- Greater Heal
        [17314] = { cost = 1900, rank = "Rank 5" }, -- Mind Flay
        [27800] = { cost = 1900, rank = "Rank 5" }, -- Holy Nova
      },
      [54] = {
        [10900] = { cost = 40000, rank = "Rank 9" }, -- Power Word: Shield
        [10934] = { cost = 40000, rank = "Rank 8" }, -- Smite
        [15267] = { cost = 40000, rank = "Rank 7" }, -- Holy Fire
      },
      [56] = {
        [10876] = { cost = 42000, rank = "Rank 5" }, -- Mana Burn
        [10890] = { cost = 42000, rank = "Rank 4" }, -- Psychic Scream
        [10917] = { cost = 42000, rank = "Rank 7" }, -- Flash Heal
        [10929] = { cost = 42000, rank = "Rank 9" }, -- Renew
        [10958] = { cost = 42000, rank = "Rank 3" }, -- Shadow Protection
        [27683] = { cost = 42000, rank = "Rank 1" }, -- Prayer of Shadow Protection
        [34863] = { cost = 2100, rank = "Rank 2" }, -- Circle of Healing
      },
      [58] = {
        [10894] = { cost = 44000, rank = "Rank 8" }, -- Shadow Word: Pain
        [10912] = { cost = 44000, rank = "Rank 3" }, -- Mind Control
        [10947] = { cost = 44000, rank = "Rank 9" }, -- Mind Blast
        [10965] = { cost = 44000, rank = "Rank 4" }, -- Greater Heal
        [20770] = { cost = 44000, rank = "Rank 5" }, -- Resurrection
      },
      [60] = {
        [10901] = { cost = 46000, rank = "Rank 10" }, -- Power Word: Shield
        [10938] = { cost = 46000, rank = "Rank 6" }, -- Power Word: Fortitude
        [10942] = { cost = 46000, rank = "Rank 6" }, -- Fade
        [10952] = { cost = 46000, rank = "Rank 6" }, -- Inner Fire
        [10955] = { cost = 46000, rank = "Rank 3" }, -- Shackle Undead
        [10961] = { cost = 46000, rank = "Rank 4" }, -- Prayer of Healing
        [15261] = { cost = 46000, rank = "Rank 8" }, -- Holy Fire
        [18807] = { cost = 2300, rank = "Rank 6" }, -- Mind Flay
        [21564] = { cost = 46000, rank = "Rank 2" }, -- Prayer of Fortitude
        [25314] = { cost = 65000, rank = "Rank 5" }, -- Greater Heal
        [25315] = { cost = 6500, rank = "Rank 10" }, -- Renew
        [25316] = { cost = 6500, rank = "Rank 5" }, -- Prayer of Healing
        [27681] = { cost = 2300, rank = "Rank 1" }, -- Prayer of Spirit
        [27801] = { cost = 2300, rank = "Rank 6" }, -- Holy Nova
        [27841] = { cost = 2300, rank = "Rank 4" }, -- Divine Spirit
        [27871] = { cost = 1500, rank = "Rank 3" }, -- Lightwell
        [34864] = { cost = 2300, rank = "Rank 3" }, -- Circle of Healing
        [34916] = { cost = 2300, rank = "Rank 2" }, -- Vampiric Touch
      },
      [61] = {
        [25233] = { cost = 53000, rank = "Rank 8" }, -- Flash Heal
        [25363] = { cost = 53000, rank = "Rank 9" }, -- Smite
      },
      [62] = {
        [32379] = { cost = 59000, rank = "Rank 1" }, -- Shadow Word: Death
      },
      [63] = {
        [25210] = { cost = 65000, rank = "Rank 6" }, -- Greater Heal
        [25372] = { cost = 65000, rank = "Rank 10" }, -- Mind Blast
        [25379] = { cost = 65000, rank = "Rank 6" }, -- Mana Burn
      },
      [64] = {
        [32546] = { cost = 72000, rank = "Rank 1" }, -- Binding Heal
      },
      [65] = {
        [25217] = { cost = 80000, rank = "Rank 11" }, -- Power Word: Shield
        [25221] = { cost = 80000, rank = "Rank 11" }, -- Renew
        [25367] = { cost = 80000, rank = "Rank 9" }, -- Shadow Word: Pain
        [34865] = { cost = 2300, rank = "Rank 4" }, -- Circle of Healing
      },
      [66] = {
        [25384] = { cost = 65000, rank = "Rank 9" }, -- Holy Fire
        [25429] = { cost = 89000, rank = "Rank 7" }, -- Fade
        [34433] = { cost = 89000, rank = "Rank 1" }, -- Shadowfiend
      },
      [67] = {
        [25235] = { cost = 99000, rank = "Rank 9" }, -- Flash Heal
        [25596] = { cost = 99000, rank = "Rank 4" }, -- Mind Soothe
      },
      [68] = {
        [25213] = { cost = 110000, rank = "Rank 7" }, -- Greater Heal
        [25308] = { cost = 110000, rank = "Rank 6" }, -- Prayer of Healing
        [25331] = { cost = 3250, rank = "Rank 7" }, -- Holy Nova
        [25387] = { cost = 6500, rank = "Rank 7" }, -- Mind Flay
        [25433] = { cost = 110000, rank = "Rank 4" }, -- Shadow Protection
        [25435] = { cost = 110000, rank = "Rank 6" }, -- Resurrection
        [33076] = { cost = 110000, rank = "Rank 1" }, -- Prayer of Mending
      },
      [69] = {
        [25364] = { cost = 65000, rank = "Rank 10" }, -- Smite
        [25375] = { cost = 65000, rank = "Rank 11" }, -- Mind Blast
        [25431] = { cost = 65000, rank = "Rank 7" }, -- Inner Fire
      },
      [70] = {
        [25218] = { cost = 140000, rank = "Rank 12" }, -- Power Word: Shield
        [25222] = { cost = 140000, rank = "Rank 12" }, -- Renew
        [25312] = { cost = 2300, rank = "Rank 5" }, -- Divine Spirit
        [25368] = { cost = 140000, rank = "Rank 10" }, -- Shadow Word: Pain
        [25380] = { cost = 110000, rank = "Rank 7" }, -- Mana Burn
        [25389] = { cost = 65000, rank = "Rank 7" }, -- Power Word: Fortitude
        [28275] = { cost = 1500, rank = "Rank 4" }, -- Lightwell
        [32375] = { cost = 110000, rank = "" }, -- Mass Dispel
        [32996] = { cost = 110000, rank = "Rank 2" }, -- Shadow Word: Death
        [32999] = { cost = 3400, rank = "Rank 2" }, -- Prayer of Spirit
        [34866] = { cost = 2300, rank = "Rank 5" }, -- Circle of Healing
        [34917] = { cost = 2300, rank = "Rank 3" }, -- Vampiric Touch
      },
    },
  }
end
