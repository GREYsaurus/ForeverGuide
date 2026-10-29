# Source audit and parity checklist

## Source audit

| | |
|---|---|
| Repository | https://github.com/GREYsaurus/TBCGuide |
| Revision inspected | `536d86c27b3785b6de3ed4c041515d7ec130269f` ("TBCGuide 0.5.0: settings window, profiles, dungeon quest setting"), 2026-10-28. Imported verbatim as this repository's first commit, so `git diff` against it shows every adaptation. |
| Target of the original | TBC Classic Anniversary 2.5.6.70577, TOC 20506, Lua 5.1 |
| Licence | GPL-3.0-only (author GREYsaurus); verbatim GPLv3 `LICENSE` and `COPYING`. Third-party: QuestieDB-derived data (GPLv3 offer with residual uncertainty), Blizzard client tables (talents, race/class). Gear weights from wowsims/tbc (MIT) and Icy Veins were not listed in its notices. |

**Structure.** `TBCGuide/` is the add-on, with load order in `TBCGuide.toc`:

- `Core/Init.lua`: namespace, event bus, throttle, helpers.
- `Config/Target.lua`: client and ruleset values.
- `Compat/Compat.lua`: every game API, nil-guarded.
- `Core/SavedVars.lua`: `TBCGuideDB` (account, profiles), `TBCGuideCharDB` (character), schema 1, field-by-field repair.
- `Core/Profiles.lua`.
- `Database/*`: QuestieDB-derived TBC data plus the `QuestDB.lua` query API.
- `Guides/Registry.lua` plus `Guides/Compiled/*.lua`: 54 guides generated from `guides-src/*.guide`.
- `Classes/`, `Talents/` (trees from client DB2, 21 builds), `Gear/`.
- Engine: `QuestTracker`, `Selector`, `Engine`, `StepText`, `Navigation`, `Vendor`, `QuestAuto`, `Orphans`, `Marker`, `Assist`.
- `UI/*`: main window, browser, talent calculator, options, settings window, minimap button, automation options, orphan window, marker bar, gear UI.
- `Core/Commands.lua`, `Core/Diagnostics.lua`, `Core/Boot.lua` (pcall-guarded stages).
- `Bindings.xml`: delete-cheapest-junk key binding.

Outside the add-on: `tools/` holds the PowerShell and C# build (guide compiler, Lua 5.1 lint with an API allowlist, validator, route analyzer, packager). `tests/` holds a headless Lua 5.1 harness with WoW mocks (284+ checks) and a tools self-test. `.github/workflows/curseforge.yml` handles publishing.

**Guide loading and rendering.** `.guide` text is compiled by `GuideCompiler.cs` against the bundled database, which supplies titles, NPCs and coordinates. Compiled files call `ns.Guides:Register{...}`, and the registry validates and rejects malformed guides. `StepText` renders a title and details for each step. `MainFrame` shows the current step plus the upcoming ones; left-click marks a step done, right-click skips it.

**Step progression.** In `Engine:Refresh`, per-step `COMPLETERS` read reliable signals: quest log or completion flags, level, bind location, and the taxi, trainer and merchant windows. "Sticky" steps remember completion. Auto-skips cover race, class, exclusivity, grey quests and excluded dungeon chains. **Progress was saved by step position** (`done[stepIndex]`).

**Client and API assumptions.** Classic quest-log globals (`GetQuestLogTitle`), TBC talent API, a 25-quest log fallback, grey range 8, 61 talent points at 70, Outland at 58.

**TBC-specific content.** All 54 guides and the quest/NPC data, talent trees and builds, the escort list, class advice, gear weights, Outland chapter, level 70, Draenei and Blood Elf.

## Parity checklist

PRESERVE = carried over unchanged in behaviour. ADAPT = changed for Forever or for safety. BLOCKED_PENDING_VERIFICATION = the
code is kept, but its data or API is unavailable.

| Feature | Implementation | Treatment | Notes |
|---|---|---|---|
| Guide window (layout, sizing, colours, textures, step rows, progress bar, minimise, lock, scale) | `UI/MainFrame.lua`, `UI/Widgets.lua` | PRESERVE | Pending steps get a question-mark icon and the "Pending WoW Forever data" label. The level line shows "levels: pending" when no range is known. |
| Left-click done / right-click skip | `UI/MainFrame.lua`, `Core/Engine.lua` | ADAPT | On a pending step both *defer* it ("move past"), which is never stored as done. |
| `/fguide next/prev/skip/reset` | `Core/Commands.lua`, `Engine` | ADAPT | Renamed from `/tbcg`. `reset all` added (progress only, settings kept). `prev` also reopens deferred steps. |
| Automatic progression | `Core/Engine.lua` (COMPLETERS) | ADAPT | Only `verified` steps complete automatically. `inherited_unverified` steps need a click. |
| Saved progress | `Core/SavedVars.lua` | ADAPT | Keyed by stable step id plus revision, not position. Schema migrations, deferred set. See `docs/SAVED_DATA.md`. |
| Settings profiles, settings window, options panel | `Core/Profiles.lua`, `UI/Config.lua`, `UI/ConfigOptions.lua`, `UI/Options.lua` | PRESERVE | Text about 1-70 and Outland replaced. Gear scoring default changed to off. |
| Guide browser (faction/race/class/level/chapter filters, load/restart) | `UI/Browser.lua`, `Guides/Registry.lua` | ADAPT | Outland chapter removed. Shows content status and a pending tag; unknown level range shown as `?-?`. |
| Guide auto-selection and `@next` routes | `Core/Selector.lua` | PRESERVE | Shipped guides are placeholder starts for each faction. |
| Guide format and compiler | `guides-src/`, `tools/src/GuideCompiler.cs` | ADAPT | `[id=]` required, plus `@status`, `pending` steps, `[ph=]`, `[rev=]`, `[supersedes=]`, `@levels ?`, `@zone ?`. Races limited to the original eight. Level cap 60. |
| Bundled quest database and query API | `Database/QuestDB.lua`, `Database/Schema.lua` | BLOCKED_PENDING_VERIFICATION | API kept and returns nil. No data ships (PH-DATA-QUESTDB). |
| Navigation arrow, world-map pin, TomTom | `Core/Navigation.lua`, `Core/StepText.lua` | ADAPT | Waypoints only for verified steps. No shipped step has coordinates (PH-API-MAPIDS, PH-INT-TOMTOM). |
| Quest automation (accept/turn-in, escort guard, reward rule, Shift override) | `Core/QuestAuto.lua`, `Database/EscortQuests.lua` | ADAPT | Verified steps only. TBC escort ids removed. Unknown log capacity means no log-full check. |
| Junk selling, protection list, junk list, delete-cheapest binding | `Core/Vendor.lua`, `Core/Assist.lua`, `Bindings.xml` | PRESERVE | Binding header renamed `FOREVERGUIDE`. |
| Orphaned quests window | `Core/Orphans.lua`, `UI/OrphanFrame.lua` | PRESERVE | Quest-log button needs `QuestLogFrame` (likely absent on a Retail-based UI); `/fguide orphans` works regardless. |
| Raid markers (command, marker bar, guide `[mark]`, objective marking) | `Core/Marker.lua`, `UI/MarkerBar.lua` | PRESERVE (runtime BLOCKED_PENDING_VERIFICATION) | Guide marking only on verified steps. Insecure `SetRaidTarget` is likely blocked on 12.1.5 (PH-API-RAIDTARGET); the existing fallback is the secure marker bar. |
| NPC automation (flights, binds, gossip skip, trainer, targeting macro, rares, warnings, level announcements) | `Core/Assist.lua` | ADAPT | Step-driven parts act on verified steps only. |
| Minimap button | `UI/MinimapButton.lua` | PRESERVE | |
| Talent guide and calculator | `Talents/Talents.lua`, `UI/TalentFrame.lua` | BLOCKED_PENDING_VERIFICATION | TBC trees and builds removed. The window shows "Talents: Pending WoW Forever data" (PH-TALENTS-SYSTEM, PH-API-TALENTS). |
| Gear scoring (tooltips, reward ranking, `/fgear`) | `Gear/*`, `UI/GearUI.lua` | ADAPT | Kept, off by default, every score labelled "TBC weights, unverified for WoW Forever" (PH-GEAR-WEIGHTS). |
| Class leveling tips | `Classes/ClassAdvice.lua` | ADAPT | Text unchanged, labelled "TBC-era tips" (PH-CLASS-ADVICE). |
| Diagnostics (`debug`, `api`, `quest`, `escort`, `marks`, `errors`) | `Core/Diagnostics.lua` | ADAPT | Retail API probes added, plus `debug placeholders`, and schema and placeholder counts in the summary. |
| Boot (pcall stages, interface warning) | `Core/Boot.lua` | ADAPT | Warns on any interface other than 16001 and on a newer saved-data schema. |
| Identity and namespace | TOC, `ForeverGuide` global, `ForeverGuideDB`/`ForeverGuideCharDB`, `/fguide` `/foreverguide` `/fgear`, frame names, `FG_*` events, macro name | ADAPT | Never reads or writes TBCGuide's globals or SavedVariables. The two add-ons can be installed side by side. |
| Lint gate and API allowlist | `tools/src/Linter.cs`, `tools/wow_api_allowlist.txt` | ADAPT | Allowlist annotated for the Retail base; `C_QuestLog` entries added. |
| Validator, coverage and route reports | `tools/src/Validator.cs`, `RouteAnalyzer.cs` | ADAPT | Placeholder-safety and manifest checks, release blockers, `docs/PLACEHOLDERS.md` generation. Log-cap check disabled until known. |
| Packaging and CurseForge workflow | `tools/build.ps1`, `.github/workflows/curseforge.yml` | ADAPT | `package` refuses while blockers are open; `package-test` builds an UNVERIFIED test zip. CurseForge needs a new project and game version. |
| Data import pipeline (QuestieDB, client tables) | `tools/build.ps1 fetch/import-*`, `tools/upstream.json` | BLOCKED_PENDING_VERIFICATION | Disabled: the pinned upstreams are TBC. |
| Headless tests | `tests/*` | ADAPT | Retail-style quest-log mocks. TBC data replaced by labelled fixtures in `tests/fixtures/`. New placeholder, migration and isolation tests. |
