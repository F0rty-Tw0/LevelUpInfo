<h1 align="center">Level Up Info</h1>

<p align="center"><b>When you level up, a small window in Blizzard's own trainer style shows what you gained and which class skills you can now buy, with their price.</b></p>

## Why players install it

- **See your gains at a glance.** Health, mana, talent points and stats you got from the new level.
- **Know what to train.** New class skills for your level, with icon, rank and price.
- **Blizzard look, no libraries.** Zero cost when idle, tiny cost when it works.

## What you see

A small window in Blizzard's own trainer style opens when you level up:

- **Gains.** One line per stat that changed, each stat name in its own color, shown as old value, a green up arrow, then the new value (for example `Stamina 25 ▲ 26`). Talent points show as `▲ +1 Talent points`.
- **Skills.** New class skills for your level under **New skills**, new ranks of skills you already have under **New ranks**. Each row shows the icon, name, rank and price. The price turns red when you cannot afford it. Hover a row for the spell tooltip.
- **What changed.** A new rank lists what changed from the rank before it, like patch notes: for example `Healing: 47-58 → 76-91` or `Mana cost: 30 → 45`. Missed ranks under **Not yet learned** show it too.
- **Long lists.** **Not yet learned** and **Weapon skills** show their first 5 rows; click `+N more` to scroll through the rest right in the window, and `Show less` to fold it back.
- **Learning from trainers.** The addon learns skills and prices from class trainers you visit. Until your race has visited its trainer for the new level, the window adds a line telling you to visit your class trainer.

The window closes by itself after a few seconds. Hover it to keep it open, drag it to move it, or press the X to close it. If you level up in combat, it waits until combat ends.

## Settings

Open them with `/lui` or under Options, AddOns, Level Up Info.

| Setting | What it does | Default |
| --- | --- | --- |
| Enabled | Show the window on level-up | On |
| Duration | Seconds before the window closes (3 to 30) | 10 |
| Wait for combat to end | Hold the window until you leave combat | On |
| Scale | Window size (0.5 to 1.5) | 1.0 |
| Reduced motion | Close the window at once instead of fading | Off |
| Reset position | Put the window back at its default spot | |
| Clear skill data | Forget the skills learned from trainers | |
| Test | Close the options and show a preview of the window | |

## Commands

- `/lui` opens the settings.
- `/lui test` shows a preview of the window right now.

## Game versions

- WoW: Forever
- Classic Era
- TBC Anniversary

## License

MIT
