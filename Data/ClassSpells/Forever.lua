local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Priest class-trainer data, WoW: Forever 16001. Source: the Undead priest scan (covered to 60, prices as scanned); race-only spells excluded.
ns.ClassSpellData = ns.ClassSpellData or {}
ns.ClassSpellData.forever = function()
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
        [528] = { cost = 900, rank = "" }, -- Cure Disease
        [598] = { cost = 900, rank = "Rank 3" }, -- Smite
        [6074] = { cost = 900, rank = "Rank 2" }, -- Renew
        [8122] = { cost = 900, rank = "Rank 1" }, -- Psychic Scream
      },
      [16] = {
        [2054] = { cost = 1400, rank = "Rank 1" }, -- Heal
        [8102] = { cost = 1400, rank = "Rank 2" }, -- Mind Blast
      },
      [18] = {
        [527] = { cost = 1500, rank = "Rank 1" }, -- Dispel Magic
        [600] = { cost = 1500, rank = "Rank 3" }, -- Power Word: Shield
        [970] = { cost = 1500, rank = "Rank 3" }, -- Shadow Word: Pain
      },
      [20] = {
        [453] = { cost = 1890, rank = "Rank 1" }, -- Mind Soothe
        [2061] = { cost = 1890, rank = "Rank 1" }, -- Flash Heal
        [2944] = { cost = 1890, rank = "Rank 1" }, -- Devouring Plague
        [6075] = { cost = 1890, rank = "Rank 3" }, -- Renew
        [6346] = { cost = 1890, rank = "" }, -- Fear Ward
        [7128] = { cost = 1890, rank = "Rank 2" }, -- Inner Fire
        [9484] = { cost = 1890, rank = "Rank 1" }, -- Shackle Undead
        [9578] = { cost = 1890, rank = "Rank 2" }, -- Fade
        [14914] = { cost = 1890, rank = "Rank 1" }, -- Holy Fire
      },
      [22] = {
        [984] = { cost = 2970, rank = "Rank 4" }, -- Smite
        [2010] = { cost = 2970, rank = "Rank 2" }, -- Resurrection
        [2055] = { cost = 2970, rank = "Rank 2" }, -- Heal
        [2096] = { cost = 2970, rank = "Rank 1" }, -- Mind Vision
        [8103] = { cost = 2970, rank = "Rank 3" }, -- Mind Blast
      },
      [24] = {
        [1245] = { cost = 4500, rank = "Rank 3" }, -- Power Word: Fortitude
        [3747] = { cost = 4500, rank = "Rank 4" }, -- Power Word: Shield
        [8129] = { cost = 4500, rank = "Rank 1" }, -- Mana Burn
        [15262] = { cost = 4500, rank = "Rank 2" }, -- Holy Fire
      },
      [26] = {
        [992] = { cost = 4680, rank = "Rank 4" }, -- Shadow Word: Pain
        [6076] = { cost = 4680, rank = "Rank 4" }, -- Renew
        [9472] = { cost = 4680, rank = "Rank 2" }, -- Flash Heal
      },
      [28] = {
        [6063] = { cost = 4770, rank = "Rank 3" }, -- Heal
        [8104] = { cost = 4770, rank = "Rank 4" }, -- Mind Blast
        [8124] = { cost = 4770, rank = "Rank 2" }, -- Psychic Scream
        [15430] = { cost = 4770, rank = "Rank 2" }, -- Holy Nova
        [17311] = { cost = 4770, rank = "Rank 2" }, -- Mind Flay
        [19276] = { cost = 4770, rank = "Rank 2" }, -- Devouring Plague
      },
      [30] = {
        [596] = { cost = 5040, rank = "Rank 1" }, -- Prayer of Healing
        [602] = { cost = 5040, rank = "Rank 3" }, -- Inner Fire
        [605] = { cost = 5040, rank = "Rank 1" }, -- Mind Control
        [976] = { cost = 5040, rank = "Rank 1" }, -- Shadow Protection
        [1004] = { cost = 5040, rank = "Rank 5" }, -- Smite
        [6065] = { cost = 5040, rank = "Rank 5" }, -- Power Word: Shield
        [9579] = { cost = 5040, rank = "Rank 3" }, -- Fade
        [14752] = { cost = 5040, rank = "Rank 1" }, -- Divine Spirit
        [15263] = { cost = 5040, rank = "Rank 3" }, -- Holy Fire
      },
      [32] = {
        [552] = { cost = 7200, rank = "" }, -- Abolish Disease
        [6077] = { cost = 7200, rank = "Rank 5" }, -- Renew
        [8131] = { cost = 7200, rank = "Rank 2" }, -- Mana Burn
        [9473] = { cost = 7200, rank = "Rank 3" }, -- Flash Heal
        [1240770] = { cost = 11000, rank = "" }, -- Binding Heal
        [1309595] = { cost = 7200, rank = "Rank 1" }, -- Shadow Word: Death
      },
      [34] = {
        [1706] = { cost = 8100, rank = "" }, -- Levitate
        [2767] = { cost = 8100, rank = "Rank 5" }, -- Shadow Word: Pain
        [6064] = { cost = 8100, rank = "Rank 4" }, -- Heal
        [8105] = { cost = 8100, rank = "Rank 5" }, -- Mind Blast
        [10880] = { cost = 8100, rank = "Rank 3" }, -- Resurrection
      },
      [36] = {
        [988] = { cost = 9000, rank = "Rank 2" }, -- Dispel Magic
        [2791] = { cost = 9000, rank = "Rank 4" }, -- Power Word: Fortitude
        [6066] = { cost = 9000, rank = "Rank 6" }, -- Power Word: Shield
        [8192] = { cost = 9000, rank = "Rank 2" }, -- Mind Soothe
        [15264] = { cost = 9000, rank = "Rank 4" }, -- Holy Fire
        [15431] = { cost = 9000, rank = "Rank 3" }, -- Holy Nova
        [17312] = { cost = 9000, rank = "Rank 3" }, -- Mind Flay
        [19277] = { cost = 9000, rank = "Rank 3" }, -- Devouring Plague
      },
      [38] = {
        [6060] = { cost = 10800, rank = "Rank 6" }, -- Smite
        [6078] = { cost = 10800, rank = "Rank 6" }, -- Renew
        [9474] = { cost = 10800, rank = "Rank 4" }, -- Flash Heal
        [1240771] = { cost = 16000, rank = "" }, -- Binding Heal
      },
      [40] = {
        [996] = { cost = 11700, rank = "Rank 2" }, -- Prayer of Healing
        [1006] = { cost = 11700, rank = "Rank 4" }, -- Inner Fire
        [2060] = { cost = 11700, rank = "Rank 1" }, -- Greater Heal
        [8106] = { cost = 11700, rank = "Rank 6" }, -- Mind Blast
        [9485] = { cost = 11700, rank = "Rank 2" }, -- Shackle Undead
        [9592] = { cost = 11700, rank = "Rank 4" }, -- Fade
        [10874] = { cost = 11700, rank = "Rank 3" }, -- Mana Burn
        [14818] = { cost = 11700, rank = "Rank 2" }, -- Divine Spirit
        [1240720] = { cost = 11700, rank = "Rank 2" }, -- Penance
        [1309633] = { cost = 11700, rank = "Rank 2" }, -- Shadow Word: Death
      },
      [42] = {
        [10888] = { cost = 12600, rank = "Rank 3" }, -- Psychic Scream
        [10892] = { cost = 12600, rank = "Rank 6" }, -- Shadow Word: Pain
        [10898] = { cost = 12600, rank = "Rank 7" }, -- Power Word: Shield
        [10957] = { cost = 12600, rank = "Rank 2" }, -- Shadow Protection
        [15265] = { cost = 12600, rank = "Rank 5" }, -- Holy Fire
      },
      [44] = {
        [10909] = { cost = 14400, rank = "Rank 2" }, -- Mind Vision
        [10911] = { cost = 14400, rank = "Rank 2" }, -- Mind Control
        [10915] = { cost = 14400, rank = "Rank 5" }, -- Flash Heal
        [10927] = { cost = 14400, rank = "Rank 7" }, -- Renew
        [17313] = { cost = 14400, rank = "Rank 4" }, -- Mind Flay
        [19278] = { cost = 14400, rank = "Rank 4" }, -- Devouring Plague
        [27799] = { cost = 14400, rank = "Rank 4" }, -- Holy Nova
        [1240772] = { cost = 24000, rank = "" }, -- Binding Heal
      },
      [46] = {
        [10881] = { cost = 15300, rank = "Rank 4" }, -- Resurrection
        [10933] = { cost = 15300, rank = "Rank 7" }, -- Smite
        [10945] = { cost = 15300, rank = "Rank 7" }, -- Mind Blast
        [10963] = { cost = 15300, rank = "Rank 2" }, -- Greater Heal
      },
      [48] = {
        [10875] = { cost = 16200, rank = "Rank 4" }, -- Mana Burn
        [10899] = { cost = 16200, rank = "Rank 8" }, -- Power Word: Shield
        [10937] = { cost = 16200, rank = "Rank 5" }, -- Power Word: Fortitude
        [15266] = { cost = 16200, rank = "Rank 6" }, -- Holy Fire
        [1309635] = { cost = 16200, rank = "Rank 3" }, -- Shadow Word: Death
      },
      [50] = {
        [10893] = { cost = 18000, rank = "Rank 7" }, -- Shadow Word: Pain
        [10916] = { cost = 18000, rank = "Rank 6" }, -- Flash Heal
        [10928] = { cost = 18000, rank = "Rank 8" }, -- Renew
        [10941] = { cost = 18000, rank = "Rank 5" }, -- Fade
        [10951] = { cost = 18000, rank = "Rank 5" }, -- Inner Fire
        [10960] = { cost = 18000, rank = "Rank 3" }, -- Prayer of Healing
        [14819] = { cost = 18000, rank = "Rank 3" }, -- Divine Spirit
        [1240721] = { cost = 18000, rank = "Rank 3" }, -- Penance
        [1240773] = { cost = 30000, rank = "" }, -- Binding Heal
        [1240826] = { cost = 18000, rank = "Rank 2" }, -- Prayer of Mending
      },
      [52] = {
        [10946] = { cost = 21600, rank = "Rank 8" }, -- Mind Blast
        [10953] = { cost = 21600, rank = "Rank 3" }, -- Mind Soothe
        [10964] = { cost = 21600, rank = "Rank 3" }, -- Greater Heal
        [17314] = { cost = 21600, rank = "Rank 5" }, -- Mind Flay
        [19279] = { cost = 21600, rank = "Rank 5" }, -- Devouring Plague
        [27800] = { cost = 21600, rank = "Rank 5" }, -- Holy Nova
      },
      [54] = {
        [10900] = { cost = 22500, rank = "Rank 9" }, -- Power Word: Shield
        [10934] = { cost = 22500, rank = "Rank 8" }, -- Smite
        [15267] = { cost = 22500, rank = "Rank 7" }, -- Holy Fire
      },
      [56] = {
        [10876] = { cost = 23400, rank = "Rank 5" }, -- Mana Burn
        [10890] = { cost = 23400, rank = "Rank 4" }, -- Psychic Scream
        [10917] = { cost = 23400, rank = "Rank 7" }, -- Flash Heal
        [10929] = { cost = 23400, rank = "Rank 9" }, -- Renew
        [10958] = { cost = 23400, rank = "Rank 3" }, -- Shadow Protection
        [1240774] = { cost = 42000, rank = "" }, -- Binding Heal
        [1309636] = { cost = 23400, rank = "Rank 4" }, -- Shadow Word: Death
      },
      [58] = {
        [10894] = { cost = 24300, rank = "Rank 8" }, -- Shadow Word: Pain
        [10912] = { cost = 24300, rank = "Rank 3" }, -- Mind Control
        [10947] = { cost = 24300, rank = "Rank 9" }, -- Mind Blast
        [10965] = { cost = 24300, rank = "Rank 4" }, -- Greater Heal
        [20770] = { cost = 24300, rank = "Rank 5" }, -- Resurrection
      },
      [60] = {
        [10901] = { cost = 25200, rank = "Rank 10" }, -- Power Word: Shield
        [10938] = { cost = 25200, rank = "Rank 6" }, -- Power Word: Fortitude
        [10942] = { cost = 25200, rank = "Rank 6" }, -- Fade
        [10952] = { cost = 25200, rank = "Rank 6" }, -- Inner Fire
        [10955] = { cost = 25200, rank = "Rank 3" }, -- Shackle Undead
        [10961] = { cost = 25200, rank = "Rank 4" }, -- Prayer of Healing
        [15261] = { cost = 25200, rank = "Rank 8" }, -- Holy Fire
        [18807] = { cost = 25200, rank = "Rank 6" }, -- Mind Flay
        [19280] = { cost = 25200, rank = "Rank 6" }, -- Devouring Plague
        [27681] = { cost = 25200, rank = "Rank 1" }, -- Prayer of Spirit
        [27801] = { cost = 25200, rank = "Rank 6" }, -- Holy Nova
        [27841] = { cost = 25200, rank = "Rank 4" }, -- Divine Spirit
        [1240827] = { cost = 25200, rank = "Rank 3" }, -- Prayer of Mending
        [1316995] = { cost = 25200, rank = "Rank 4" }, -- Penance
      },
    },
  }
end
