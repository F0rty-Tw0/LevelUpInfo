# Changelog

Player-friendly release notes for Level Up Info. This file covers the current 0.x series; older series live in [archive/changelog/](archive/changelog/).

All releases: **0.1.x (current)**

## [Unreleased]

## [0.1.8] - 2026-11-10

- Fixed: The level-up window no longer runs off the screen when it has many skills; it scrolls instead.

## [0.1.7] - 2026-11-09

- Fixed: higher ranks of a talent you haven't taken (like Mind Flay Rank 2 without the talent) no longer show up as skills to buy.

## [0.1.6] - 2026-11-08

- Fixed: after training a higher rank of a skill (like Rend Rank 2), its lower ranks no longer show up as not yet learned.

## [0.1.5] - 2026-11-07

- Each skill group shows what training all of it costs, in red when you can't afford it.

## [0.1.4] - 2026-11-06

- Press Escape to close the level-up window, like any other game window.

## [0.1.3] - 2026-11-05

- Click the Not yet learned or Weapon skills heading to fold that group. It stays folded on later level-ups, for all your characters, and shows how many entries it holds.
- The preview now shows every stat, so Strength, Agility, Intellect and Spirit appear alongside Stamina.
- Fixed: the preview no longer shows a Mana line for Warriors and Rogues during combat.

## [0.1.2] - 2026-11-04

- TBC Anniversary: Draenei are sent to the weapon master in The Exodar and Blood Elves to the one in Silvermoon City, for the weapons those masters teach.
- Classic Era and TBC Anniversary: priest racial spells and weapon skills now match your game version (TBC priests buy their racials from the class trainer, so no quest is suggested).
- `/lui test 70` works on TBC Anniversary.
- Fixed: Polearms now show at level 20 for 1 gold, when weapon masters teach them.

## [0.1.1] - 2026-10-24

- Talent points now show first in the level-up window, with a thin line separating them from your other stats.
- `/lui test` now includes the talent point you get from level 10 on, so the preview matches a real level-up.

## [0.1.0] - 2026-10-08

- First release: level-up window with stat gains and new class skills.
- Settings page under Options, AddOns, Level Up Info (also `/lui`): turn it off, change how long it stays, wait for combat to end, size, and reduced motion.
- `/lui test` shows a preview of the window.
- `/lui test 40` previews the window as if you had just reached level 40.
- The level-up window now also lists skills you skipped at earlier levels, priest racial spells from quests (with the quest and where to hand it in), and weapon skills with the weapon master, city and price.
- Weapon skills show their weapon's icon.
- Test button in the options page shows a preview of the window.
- Added a minimap button: left-click shows a preview of the window, right-click opens the options. Drag it around the minimap, or turn it off in the options.
- Dragging the minimap button slides it around the edge of the minimap, and open windows now cover it instead of it showing on top.
- Clearer colors: each stat has its own color and secondary text is gray.
- Cleaner layout: stat gains sit under their own Stats heading like the skill groups, rows have a little space between them, and each block stands apart by spacing instead of divider lines.
- Stat gains read like "Stamina 27 to 28 (+1)", with a small arrow between the values: the old value is gray and the gain is green.
- A window shown during combat fills in the old stat values as soon as combat ends.
- The level-up window now congratulates you on the level you reached.
- New ranks list what changed from the previous rank — damage, healing, cost, cast time — like patch notes, with the difference in green when it's better and red when it's worse, e.g. "Mana cost 25 to 40 (+15)" in red.
- Click `+N more` to scroll through the rest of the list in place, at the same size as before; `Show less` folds it back.
- Skills above your level show their rank too, so new ranks and what they change appear for them.
- Every skill list shows its first 5 skills, so a big level jump stays short; `+N more` shows the rest.
- New addon icon in the AddOns list.
- Works on Classic Era and TBC Anniversary: the window lists your trainer's skills after a visit.

