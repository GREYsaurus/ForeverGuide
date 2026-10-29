# ForeverGuide

A **free** leveling guide add-on framework for **World of Warcraft: Forever** (working name). It is a faithful adaptation of
[TBCGuide](https://github.com/GREYsaurus/TBCGuide) by the same author: same window, interactions, settings and
automation, changed only where WoW Forever requires it.

> **Status: pre-release framework, not install-ready.**
> - **No leveling route yet.** WoW Forever launches on 2026-11-04 with expanded and new zones and over 1,000 new quests. No verified quest data exists, so the two shipped guides (Alliance and Horde starting zones) contain only steps marked **"Pending WoW Forever data"**.
> - **Release packaging is blocked.** The TOC uses the documented *beta* interface `16001`; the release value is unverified.
> - **Nothing has run in a WoW Forever client.** The headless tests (1,073 checks) and the build checks pass against mocks of the documented Retail-12.1.5-based API. That shows the logic is consistent, not that the add-on works in game.
>
> Open items are in [docs/PLACEHOLDERS.md](docs/PLACEHOLDERS.md) and [docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md).

## What works (implemented and tested headless)

- **Guide window, browser, settings window, profiles, minimap button and options panel**, carried over from TBCGuide.
- **Step engine with stable step ids.** Progress is saved by step id and revision, never by position, so launch-data updates cannot mark the wrong objective done. Steps with status `placeholder` can be moved past with a click, but are never counted as done.
- **Placeholder safety.** Unfinished steps carry no quest ids, coordinates or raid marks. They cannot create waypoints, match quests, trigger automation or block the guide.
- **Quest automation, junk selling, orphaned quests, raid markers, NPC automation and warnings**, carried over and restricted to `verified` guide steps.
- **Versioned saved data** (`ForeverGuideDB`, `ForeverGuideCharDB`) with tested migrations. TBCGuide's saved data is never read or changed.

## What is pending or blocked

| Area | State |
|---|---|
| Leveling routes, quest/NPC database, map ids, travel | pending WoW Forever data |
| Talent calculator | blocked: Forever talent system unverified; the window says so |
| Gear scoring | kept but **off by default**; its weights are TBC research, labelled as such |
| Class tips | TBC-era text, labelled as such |
| Release interface number, SavedVariables reliability, Retail quest-log path, raid-marker API | unverified in client |

## Install (testing only)

There is no release yet. To test in the client, build a test package (needs Windows PowerShell):

```bash
powershell -ExecutionPolicy Bypass -File tools/build.ps1 package-test
```

This writes `dist/ForeverGuide-<version>-UNVERIFIED-TEST.zip`. Copy its `ForeverGuide` folder into the Forever client's AddOns folder. Third-party guides say this is `World of Warcraft\_forever_\Interface\AddOns`, which is unconfirmed. If the game lists the add-on as out of date, tick **Load out of date AddOns**. Then follow [docs/SMOKE_TEST.md](docs/SMOKE_TEST.md). Details are in [INSTALL.md](INSTALL.md).

ForeverGuide and TBCGuide use different folders, globals, slash commands and SavedVariables, so they never collide.

## Use

| Command | Action |
|---|---|
| `/fguide` (or `/foreverguide`) | Show/hide the guide window |
| `/fguide guide` | Guide browser |
| `/fguide next` / `prev` / `skip` | Manual step control (on a pending step, next/skip move past it without marking it done) |
| `/fguide reset` / `reset all` | Reset this guide's / every guide's progress (settings are kept) |
| `/fguide auto` / `nextguide` / `load <id>` | Guide selection |
| `/fguide talents` | Talent window (shows "Pending WoW Forever data") |
| `/fguide class` | Class tips (TBC-era, labelled) |
| `/fguide options` / `minimap` / `automation` / `orphans` | Settings, minimap button, automation settings, orphaned quests |
| `/fguide mark [icon]` / `unmark` / `marker <icon>` / `markbar` / `markers` | Raid markers |
| `/fguide protect <item>` / `unprotect` / `protected`, `/fguide escort add\|remove <questID>` | Junk and escort lists |
| `/fguide gear` (or `/fgear`) | Gear comparison (off by default) |
| `/fguide set <option> on\|off` | Change any on/off setting |
| `/fguide debug` / `debug api` / `debug placeholders` / `debug quest <id>` / `debug errors` | Diagnostics |
| `/fguide help` | All commands |

In the guide window, **left-click** a step to mark it done and **right-click** to skip it. On a pending step, either click moves past it.

## Licence

ForeverGuide is free software under the **GNU General Public License v3.0 only** (`LICENSE`, `COPYING`). Copyright (C) 2026 GREYsaurus. It is adapted from TBCGuide (GPL-3.0-only, same author). The full corresponding source is this repository: add-on, guide sources, build tools, tests and docs.

TBCGuide's bundled third-party data (QuestieDB-derived TBC data, TBC client tables) is **not** included. Two inherited items still need attention (gear weight sources and the old logo). See [NOTICE.md](NOTICE.md) and [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

World of Warcraft and World of Warcraft: Forever are trademarks of Blizzard Entertainment, Inc. ForeverGuide is not affiliated with or endorsed by Blizzard Entertainment.

## For developers

- [docs/DEVELOPER.md](docs/DEVELOPER.md): architecture, build and test commands
- [docs/GUIDE_FORMAT.md](docs/GUIDE_FORMAT.md): guide authoring, statuses, placeholders, stable ids
- [docs/PLACEHOLDERS.md](docs/PLACEHOLDERS.md): central placeholder registry (generated)
- [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md): compatibility decisions and evidence log
- [docs/SAVED_DATA.md](docs/SAVED_DATA.md): saved-data schema, migrations, update rules
- [docs/LAUNCH_CHECKLIST.md](docs/LAUNCH_CHECKLIST.md): replacing placeholders with launch data
- [docs/SMOKE_TEST.md](docs/SMOKE_TEST.md): in-client test checklist
- [docs/PARITY.md](docs/PARITY.md): source audit and TBCGuide parity checklist
- [docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md), [CHANGELOG.md](CHANGELOG.md)
- Feature docs carried over from TBCGuide: [AUTOMATION](docs/AUTOMATION.md), [RAID_MARKERS](docs/RAID_MARKERS.md), [SETTINGS](docs/SETTINGS.md), [GEAR_SCORING](docs/GEAR_SCORING.md)
