# LevelUpInfo — Feature Spec

When you level up, a small window in Blizzard's own trainer style shows what you gained and which class skills you can now buy, with their price.
Blizzard look, no libraries. Selling point: **zero cost when idle, tiny cost when it works.**

Idea credit: the level-up screen concept of GnomeLevelUp. No code or assets are reused.

## Scope

- Flavor: **WoW: Forever only** (`## Interface: 16001`). Classic Era comes later as its own change (different trainer API order, unverified at runtime).
- Class trainers only. Profession, pet and weapon trainers are ignored.
- English only. Every player-visible string goes through `Localization.Text("...")` (a `Core/Localization.lua` copied from RaidGroupWrap); Blizzard global strings (`HEALTH`, `MANA`, `SPELL_STAT1_NAME`…) are used where they exist, so those parts are already localized.
- Repo scaffolding copies RaidGroupWrap: `AGENTS.md`/`CLAUDE.md`, `.luacheckrc`, `stylua.toml`, `.editorconfig`, `.pkgmeta`, `scripts/` (lint, test runner, release, package), `tests/helpers/` and the GitHub CI + release workflows (lint, minify, re-run tests on the minified code).

## Verified Forever facts

In game on build 16001 (marked **game**) or in Blizzard's `forever` UI source (marked **src**).

- **game** `PLAYER_LEVEL_UP` payload: `level, healthDelta, powerDelta, numNewTalents, numNewPvpTalentSlots, strengthDelta, agilityDelta, staminaDelta, intellectDelta, spiritDelta`.
- **game** `GetTrainerServiceInfo(i)` returns `name, serviceType, texture, reqLevel, subText, category`. `serviceType` is `"available"`, `"unavailable"`, `"used"` or `"header"`. `subText` is the rank (`Rank 1`).
- **game** `GetTrainerServiceLevelReq(i)`, `GetTrainerServiceCost(i)` (returns `moneyCost, isProfession`) and `GetTrainerServiceIcon(i)` work.
- **game** `C_TooltipInfo.GetTrainerService(i)` returns tooltip data without a tooltip frame while the trainer window is open (nil during gossip): `type 1` (= `Enum.TooltipDataType.Spell`), `id 139` for Renew. (**game** fallback proven: an addon `GameTooltipTemplate` tooltip `:GetSpell()` returned `Renew 139`, but that path shows the tooltip and registers `TOOLTIP_DATA_UPDATE`, so it is not used.)
- **game** The trainer filter state is not reliably all on: one character had all three ticked (by the user), another had all three off. **src** Era's `Blizzard_TrainerUI.lua` defaults `used` to off. The scan cannot rely on it.
- **game** `SetTrainerServiceTypeFilter(type, bool)` changes the list synchronously (`GetNumTrainerServices` 0 → 5 inside one `/run`) and fires `TRAINER_UPDATE` synchronously once per call, even when the value does not change. Blizzard's selected service index stayed the same. **src** Blizzard's `TRAINER_UPDATE` handler keeps its scroll position unless its own dropdown made the change (`Blizzard_TrainerUI.lua` `ClassTrainerFrame_OnEvent`).
- **game** `GetTrainerServiceTypeFilter(type)`, `C_Trainer.GetTrainerType()` (`Enum.TrainerType`: `General`=0, `Tradeskills`=2, `Pet`=3) and `IsTradeskillTrainer` exist.
- **game** `IsPlayerSpell`, `C_Spell.GetSpellInfo`, `C_Spell.GetSpellSubtext`, `C_SpellBook.IsSpellKnown` exist. Global `GetSpellInfo` / `GetSpellSubtext` are **nil**.
- **game** The spellbook lists **no** future spells; `C_EventToastManager.GetLevelUpDisplayToastsFromLevel` returns only the "Level N / You've Reached" banner. The trainer window is the only source of skill data.
- **game** The trainer window does not list every future level; it shows a window of levels.
- **game** `ButtonFrameTemplate` and `Interface\ClassTrainerFrame\TrainerTextures` exist. **src** `PortraitFrameMixin:SetPortraitToUnit`, `TitledPanelMixin:SetTitle`, `ButtonFrameTemplate_HideButtonBar`.
- **src** `SmallMoneyFrameTemplate` defaults to the player-money type: it registers 7 money events and shows `GetMoney()` on every `OnShow`. It is **not** used.
- **game** `GetMoneyString(copper)` prints gold/silver/copper with coin icons (**src** `Blizzard_SharedXML/FormattingUtil.lua`, honours colorblind mode). Global `GetCoinTextureString` is **nil**.
- **game** Blizzard shows its own level-up banner through `EventToastManagerFrame`. `LevelUpDisplay` is nil.

### Still to confirm in game (non-blocking, before release)

- **Taint from forced filters:** the scan's `SetTrainerServiceTypeFilter` calls fire `TRAINER_UPDATE` synchronously, so Blizzard's trainer handler runs inside our call and may run tainted. The last Blizzard update of every scan comes from our restore, so what it writes stays tainted until the next Blizzard-driven update. **src** Concrete paths: `ClassTrainerFrame_SetTrainButtonEnabled(false)` gives `ClassTrainerTrainButton` new `OnEnter`/`OnLeave` closures (its `OnLeave` calls `GameTooltip_Hide()`), and a hovered row runs `GameTooltip:SetTrainerService`. Check on the real addon: `/console taintLog 11` (logs table fields too); at a trainer with a filter off, run a scan; hover a row, hover the disabled Train button, buy a spell, close the trainer; then enter combat, use the action bars and open the spellbook; exit the game fully (the log is buffered until exit and restarted on `/reload` or launch), then read `Logs\taint.log`. Proxy run passed (2026-10-04, `/run` toggle, `taintLog 2`, row and Train-button hover, combat, spellbook, then exit): no blocked actions and no entries touching the trainer or `GameTooltip`. A `/run` is not attributed like an addon, so the real-addon run is still required. **Fail** = any blocked action, or any LevelUpInfo-attributed taint on a global or field outside `ClassTrainerFrame` and its children (`GameTooltip` counts as outside). On fail, fall back to per-level coverage; that needs a spec revision (new SavedVariables shape, Skill list rule and hint rule), not a tweak of the single `covered` number.

- At a weapon master (if Forever has them): `C_Trainer.GetTrainerType()` / `IsTradeskillTrainer()`. If weapon masters report `General`, the scan also requires the trainer's services to include at least one spell whose `serviceType` is not `header` **and** that is not a weapon skill (rule decided after the check; until then weapon masters are a known gap).

## The window

Built the first time it is shown, never at login. Global name `LevelUpInfoFrame`, parented to `UIParent`.

- Frame: `ButtonFrameTemplate` with `ButtonFrameTemplate_HideButtonBar(frame)`. Portrait `frame:SetPortraitToUnit("player")`, title `frame:SetTitle("Level N")` (localized format).
- **Gains section**, one line per non-zero gain, in this order: Health, Mana, Talent points, Strength, Agility, Stamina, Intellect, Spirit. Format `+15 Health`. Names come from Blizzard globals (`HEALTH`, `MANA`, `TALENT_POINTS`, `SPELL_STAT1_NAME`…`SPELL_STAT5_NAME`) with an English fallback. Zero deltas are not shown. Font `GameFontHighlight`.
- **Skills section**, one row per skill, looking like a Forever trainer row:
  - Row background and highlight: `Interface\ClassTrainerFrame\TrainerTextures` with Blizzard's trainer-row tex coords (normal `0.00195313, 0.57421875, 0.65820313, 0.75`; highlight `0.00195313, 0.57421875, 0.75390625, 0.84570313`, `ADD` blend).
  - 36×36 spell icon, name in `GameFontNormal`, rank in `GameFontNormalSmall` right after the name.
  - Price: one `FontString` (`GameFontHighlightSmall`) set to `GetMoneyString(cost)`, right-aligned. Text white when `GetMoney() >= cost`, red (`RED_FONT_COLOR`) otherwise. Read once when the window is filled; not live-updated.
  - Hover: `GameTooltip:SetOwner(row, "ANCHOR_RIGHT")` + `GameTooltip:SetSpellByID(spellID)` + `Show()`. Leave hides it.
  - Rows are pooled and reused.
- **Hint row**, after the skill rows, same row style, icon `Interface\Icons\INV_Misc_Book_09`, no price: `Visit your class trainer to see all new skills.` When it shows: see Skill list.
- No skills and no hint → the skills section is hidden.
- Frame height fits its content.
- Blizzard's own level-up banner is left alone (never hidden, hooked or moved).
- Escape does not close it (that would need a write to Blizzard's `UISpecialFrames`); the close X and the countdown do.

### Show and hide

- **Countdown:** one `C_Timer.NewTimer(duration)`. When it fires, the window fades out over 0.5 s (native `AnimationGroup` alpha, `OnFinished` hides). Reduced motion: no fade, it hides at once.
- **Hover pause:** the window and every row share one `pause()` / `resume()` pair. `OnEnter` (window or row) cancels the timer; if the fade is playing it stops and alpha goes back to 1. `OnLeave` (window or row) calls `resume()`, which does nothing while the window is hidden and otherwise restarts the full countdown only if `not frame:IsMouseOver()`.
- **Re-show** (new level-up or `/lui test` while visible or fading): stop the fade, alpha 1, refill, call `resume()` (starts the countdown only if `not frame:IsMouseOver()`), so the window never fades under the cursor.
- **Close X:** hide at once, cancel the timer, stop the fade.
- **Drag:** left button on the window moves it; on stop the anchor is saved as `position`. With `position` nil (fresh install or after `Reset position`) the anchor is `CENTER`, `UIParent`, `CENTER`, `0`, `120`.
- **Scale** applies on every show and when the setting changes.

## Data flow

### Level-up

1. `PLAYER_LEVEL_UP(level, …)`: if there is no pending record and the window is not showing a live (non-test) record, start one with `fromLevel = level - 1` (from the payload, never `UnitLevel`). Set `toLevel = level`, add the deltas.
2. If the window is showing a live record (visible or fading), the ding merges into that record and the window refills **now**, even in combat (it is already on screen); `PLAYER_REGEN_ENABLED` is not registered.
3. Otherwise, if **Wait for combat** is on and `InCombatLockdown()` is true, register `PLAYER_REGEN_ENABLED`; on it, unregister and show. Otherwise show now.
4. Several dings before the show → one window: summed gains, title = `toLevel`, skills for every level in `(fromLevel, toLevel]`. Hiding the window ends the live record.
5. **Enabled off:** `PLAYER_LEVEL_UP` returns before any work. Trainer scans still run, so the cache is ready when the addon is turned back on.

### Trainer scan

1. `TRAINER_SHOW` (always registered). Skip unless `C_Trainer.GetTrainerType() == Enum.TrainerType.General` and `IsTradeskillTrainer()` is false.
2. Register `TRAINER_UPDATE` and `TRAINER_CLOSED`; scan now and on every `TRAINER_UPDATE`. `TRAINER_CLOSED` unregisters both.
3. **Forced-filter scan**, in this order:
   1. Return at once if the module-level `scanning` flag is set (this is also how the `TRAINER_UPDATE` handler ignores the scan's own toggles). Set `scanning = true` and `flipped = {}`.
   2. Inside `xpcall` (message handler returns the error plus `debugstack()`, so BugSack keeps the trace): for each of `"available"`, `"unavailable"`, `"used"` whose `GetTrainerServiceTypeFilter` reads false, call `SetTrainerServiceTypeFilter(type, true)` and add `type` to `flipped` right after the call. Every call fires a synchronous `TRAINER_UPDATE`, even a no-op. Then `allOn` = all three filters read true. Then steps 4–5 for every row.
   3. After `xpcall` returns, success or not: `SetTrainerServiceTypeFilter(type, false)` for every type in `flipped`, then `scanning = false`. The player's filters always end as they were and `scanning` never sticks.
   4. On error: skip coverage and pass the message to `geterrorhandler()`. Rows recorded before the error stay (each row is a true fact); only coverage needs a complete scan.
4. For each service row `i` in `1..GetNumTrainerServices()`: keep it only if `serviceType` is `available`, `unavailable` or `used`; `GetTrainerServiceLevelReq(i)` is a number above 0; `GetTrainerServiceCost(i)` says not a profession; and `C_TooltipInfo.GetTrainerService(i)` yields a spell type with a numeric `id`.
5. Record a kept row under the player's class token (`select(2, UnitClass("player"))`) at that level, keyed by spellID: `cost` = latest seen cost, `rank` = latest `subText` (string, may be empty), `races[R] = true` (`R` = `select(2, UnitRace("player"))`).
6. **Coverage** (only after a scan without error): `seen` = highest level among kept rows. If `allOn` (step 3.2, read while the filters are forced, before the restore) is true, `covered[C][R] = max(covered[C][R] or 0, seen)`. Otherwise (the client refused a filter change, or another addon flipped one back during the synchronous dispatch) rows are recorded but coverage does not move: with a filter off the cache would have holes below `seen`, and an alt of the same race would get neither the skills nor the hint.
7. No frames are created by a scan. Blizzard's trainer window redraws on the scan's `TRAINER_UPDATE`s inside the same frame, so the player sees no flicker and keeps their own filter view, scroll position and selection. Accepted cosmetic glitch: a row hovered during a scan can keep a tooltip from the expanded list until the next hover (Blizzard sets the tooltip before it reassigns the row).

Prices are the last price seen at a trainer (reputation discounts can make it differ slightly).

### Skill list (levels `(fromLevel, toLevel]`, class `C`, race `R`)

A missing `trainers[C]`, `covered` table or `covered[C][x]` counts as **0**.

An entry at level `L` is shown when `IsPlayerSpell(spellID)` is false **and**:

| Your race saw it (`races[R]`) | Your race covered `L` (`covered[C][R] >= L`) | Another covering race (`covered[C][S] >= L`) lacks it | Shown |
| --- | --- | --- | --- |
| yes | any | any | **yes** |
| no | yes | any | no (another race's racial) |
| no | no | yes | no (another race's racial) |
| no | no | no | **yes** |

Known trade-off (accepted): before your race's first trainer visit, a racial of the only other race that covered `L` can show (e.g. Touch of Weakness to a Dwarf priest).

**Hint row** shows when `covered[C][R] < toLevel` — your own race's trainer has not covered the new level, so the list may be incomplete or include another race's racial.

Rows sort by level, then name. Name and icon come from `C_Spell.GetSpellInfo(spellID)` at display time (an entry whose info is nil is skipped); rank is the stored `rank`.

## Settings

Canvas panel under Options → AddOns → LevelUpInfo, same pattern as MouseOverTooltip `Settings/Panel.lua` (empty container registered at load with `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`, controls built in `OnShow` once, `frame.OnDefault` restores defaults). Checkboxes `UICheckButtonTemplate`; sliders `MinimalSliderWithSteppersTemplate`.

| Setting | Range | Default |
| --- | --- | --- |
| Enabled | on / off | on |
| Duration | 3–30 whole seconds | 10 |
| Wait for combat to end | on / off | on |
| Scale | 0.5–1.5, step 0.05 | 1.0 |
| Reduced motion | on / off | off |
| Reset position | button | — |
| Clear skill data | button (empties `trainers`) | — |

Slash command `/lui`:

- `/lui` opens the settings.
- `/lui test` shows a preview now, ignoring **Enabled** and **Wait for combat**: title = current level, sample gains (`+15 Health`, `+20 Mana`, `+1 Stamina`), skills for `(currentLevel - 1, currentLevel]` from the cache (plus the hint row by its normal rule). A test is not a live record: a real ding replaces it.

## SavedVariables

Account-wide `LevelUpInfoDB`:

```lua
{
  enabled = true, duration = 10, waitForCombat = true, scale = 1.0, reducedMotion = false,
  position = nil,                                        -- { point = "CENTER", x = 0, y = 120 } once moved
  trainers = {
    PRIEST = {
      covered = { Scourge = 12, Dwarf = 20 },            -- race token -> highest level covered
      levels = {
        [10] = { [8092] = { cost = 300, rank = "Rank 1", races = { Scourge = true, Dwarf = true } } },
      },
    },
  },
}
```

Normalized on load (same shape as RaidGroupWrap `SavedState.Initialize`, but with per-key defaults):

- Number settings: non-numbers and NaN → default; else rounded to their step and clamped to their range.
- Boolean settings: kept if the saved value is a boolean, else the default (so `enabled` and `waitForCombat` stay on for a fresh install).
- `position`: kept only if `point` is a valid anchor string and `x`, `y` are numbers; else nil.
- `trainers`: walked entry by entry; anything not matching the shape above (non-string class/race keys, non-positive or non-integer levels/spellIDs, non-number cost, non-string rank, non-table races) is dropped.
- Unknown keys dropped at every level.

## Performance rules (non-negotiable)

1. **No `OnUpdate` handlers.** Fade uses a native `AnimationGroup`.
2. **One timer at most:** the auto-hide `C_Timer.NewTimer`, cancelled on close, hover and re-show. No other timers.
3. **No libraries.** No Blizzard templates that register events on their own (this is why there is no money frame and no scan tooltip).
4. **Idle events: `PLAYER_LEVEL_UP` and `TRAINER_SHOW` only.** `ADDON_LOADED` unregisters after load. `TRAINER_UPDATE` / `TRAINER_CLOSED` only while a class trainer is open. `PLAYER_REGEN_ENABLED` only while a level-up is waiting for combat to end.
5. **Lazy UI:** at login only the event frame and the empty settings container frame (needed to register the settings category) exist. The window is built on first show; the settings controls when the panel is first shown.
6. **No per-character data:** "already learned" is always read live (`IsPlayerSpell`).
7. Row and line pools are reused; no frames are created on a repeat show unless more rows are needed than ever before.
8. Release zip is minified by CI.

## Taint rules

- Never hook, hide, move or write fields on Blizzard frames or tables (including `EventToastManagerFrame`, `GameTooltip`, the trainer frame and `UISpecialFrames`).
- `GameTooltip:SetOwner` / `SetSpellByID` / `Show` / `Hide` for our own rows is the only `GameTooltip` use (`SetSpellByID` is a secure delegate in Forever; the others are plain C methods).
- `SetTrainerServiceTypeFilter` is called only inside a scan, only to turn on filters that are off, and every change is reverted before the scan returns (see Trainer scan step 3). Our code writes no other trainer state; Blizzard's own handler does update `ClassTrainerFrame` while running inside our call — covered by the taint check under "Still to confirm".

## Acceptance checks (in game, Forever)

1. `/lui test` at a fresh install shows the window with the hint row; Enabled and Wait for combat are on in settings.
2. Visit a class trainer, `/lui test` → this level's unlearned trainer spells appear with icon, rank and price; hover shows the spell tooltip; unaffordable prices are red.
3. Ding out of combat → window shows right away with the payload gains.
4. Ding twice in one fight → one window after combat, gains summed, skills for both levels.
5. Hover a row past the duration → no fade; leave → fades after the full duration.
6. Forced filters: press **Clear skill data**, untick all three trainer filters, close and reopen the trainer → Blizzard's list is still empty and the dropdown still shows all three unticked; `/dump LevelUpInfoDB.trainers.<CLASS>.covered` shows your race at the highest level the trainer lists with all filters on; `/dump LevelUpInfoDB.trainers.<CLASS>.levels[L]` for one `L` at or below your level holds a spell you already know (`/dump IsPlayerSpell(<id>)` → true), and for one `L` above your level holds a spell you cannot learn yet.
7. Second race of the same class at a trainer → the first race's racial is not shown to it.
8. Idle check: `/etrace` shows the addon's frame receiving only `PLAYER_LEVEL_UP` / `TRAINER_SHOW`; addon memory stays flat across 10 minutes of play.

## Out of scope (decided)

- Classic Era (later), Retail, other Classic flavors.
- Static skill data tables, weapon-skill lists, profession/pet/weapon trainers.
- Custom colors, fonts, background opacity, sound choice (the game already plays its level-up sound), strata, minimap button, portrait modes, Escape-to-close.
- Hiding or replacing Blizzard's level-up banner.
- Showing skills you skipped at earlier levels (only skills new at the gained levels are listed).
- Live price colour updates while the window is open.
