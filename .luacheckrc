-- .luacheckrc for LevelUpInfo (WoW addon, WoW: Forever)
-- Targets Lua 5.1 (WoW runtime)

std = "lua51"
max_line_length = false -- StyLua handles formatting; luacheck handles semantics
cache = true
jobs = 4

exclude_files = {
  ".luacheckrc",
  ".tools/",
}

ignore = {
  "212/self", -- unused 'self' in method definitions
  "211/addonName", -- unused first return from `local addonName, ns = ...`
  "212/addonName", -- same when treated as argument
  "331/ns", -- ns is set (mutated) then exported, not read directly
}

-- Globals the addon WRITES
globals = {
  -- SavedVariables (declared in .toc)
  "LevelUpInfoDB",
  -- Slash command
  "SLASH_LEVELUPINFO1",
  "SlashCmdList",
}

-- Globals the addon READS (WoW API surface used by this addon)
read_globals = {
  "CreateFrame",
  "UIParent",
  -- Trainer scan
  "C_Trainer",
  "C_TooltipInfo",
  "Enum",
  "GetNumTrainerServices",
  "GetTrainerServiceCost",
  "GetTrainerServiceInfo",
  "GetTrainerServiceLevelReq",
  "GetTrainerServiceTypeFilter",
  "IsTradeskillTrainer",
  "IsTrainerServiceLearnSpell",
  "SetTrainerServiceTypeFilter",
  "UnitClass",
  "UnitRace",
  "UnitFactionGroup",
  "WorldFrame",
  "debugstack",
  "geterrorhandler",
  -- Skill list
  "C_Spell",
  "ENERGY",
  "GetSpellBaseCooldown",
  "RAGE",
  "IsPlayerSpell",
  "C_SpellBook",
  -- Auto-hide
  "C_Timer",
  -- Window and skill rows
  "ButtonFrameTemplate_HideButtonBar",
  "GameTooltip",
  "GetMoney",
  "GetMoneyString",
  "GREEN_FONT_COLOR",
  "HEALTH",
  "HIGHLIGHT_FONT_COLOR",
  "MANA",
  "Minimap",
  "GetCursorPosition",
  "NORMAL_FONT_COLOR",
  "RED_FONT_COLOR",
  "SPELL_STAT1_NAME",
  "SPELL_STAT2_NAME",
  "SPELL_STAT3_NAME",
  "SPELL_STAT4_NAME",
  "SPELL_STAT5_NAME",
  "TALENT_POINTS",
  -- Options panel
  "CreateMinimalSliderFormatter",
  "HideUIPanel",
  "MinimalSliderWithSteppersMixin",
  "Settings",
  "SettingsPanel",
  "wipe",
  -- Level-up records
  "InCombatLockdown",
  "UnitHealthMax",
  "issecretvalue",
  "UnitLevel",
  "UnitPowerMax",
  "UnitStat",
}

-- Test files stub WoW globals freely
files["tests/**/*.lua"] = {
  globals = { "_G", "require" },
  ignore = {
    "111", -- setting undefined global (tests stub globals)
    "112", -- mutating undefined global
    "113", -- accessing undefined global
    "122", -- setting read-only field (tests stub read_globals)
    "142", -- setting undefined field of global
    "143", -- accessing undefined field of global
    "211", -- unused local variable
    "212", -- unused argument
    "421", -- shadowing local variable
    "431", -- shadowing upvalue
    "432", -- shadowing upvalue argument
  },
}
