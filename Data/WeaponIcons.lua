local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Weapon skill spellID -> icon path. Some weapon skill spells (swords, daggers)
-- use a generic ability icon; every weapon skill is listed so each row shows its weapon.
local WeaponIcons = {
  [196] = "Interface\\Icons\\INV_Axe_01",
  [197] = "Interface\\Icons\\INV_Axe_04",
  [198] = "Interface\\Icons\\INV_Mace_01",
  [199] = "Interface\\Icons\\INV_Mace_04",
  [200] = "Interface\\Icons\\INV_Spear_06",
  [201] = "Interface\\Icons\\INV_Sword_04",
  [202] = "Interface\\Icons\\INV_Sword_06",
  [227] = "Interface\\Icons\\INV_Staff_08",
  [264] = "Interface\\Icons\\INV_Weapon_Bow_05",
  [266] = "Interface\\Icons\\INV_Weapon_Rifle_01",
  [1180] = "Interface\\Icons\\INV_Weapon_ShortBlade_01",
  [2567] = "Interface\\Icons\\INV_ThrowingKnife_02",
  [5011] = "Interface\\Icons\\INV_Weapon_Crossbow_01",
  [15590] = "Interface\\Icons\\INV_Gauntlets_04",
}

ns.WeaponIcons = WeaponIcons
return WeaponIcons
