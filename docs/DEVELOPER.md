# Developer guide

## Layout

```
ForeverGuide/                   the add-on (this folder is what players install)
  ForeverGuide.toc              manifest (interface 16001, BLOCKED for release) - load order lives here
  Core/Init.lua                 namespace, event bus, throttling, helpers
  Config/Target.lua             EVERYTHING client/ruleset specific, each value with its evidence class
  Config/Placeholders.lua       central registry of unknown WoW Forever data (source of docs/PLACEHOLDERS.md)
  Compat/Compat.lua             every game API call; Retail form first, Classic fallback; missing APIs degrade, never error
  Core/SavedVars.lua            ForeverGuideDB / ForeverGuideCharDB, schema + MIGRATIONS, field-by-field repair
  Database/Schema.lua           field layout of the (future) bundled data in Database/Data/
  Database/RaceClass.lua        original eight races (inherited_unverified)
  Database/QuestDB.lua          query API; returns nil while no data ships
  Database/EscortQuests.lua     never-auto-accept list (empty until verified data)
  Guides/Registry.lua           guide registration + safety validation (stable ids, statuses, no live data on placeholders)
  Guides/Compiled/              GENERATED guides + Guides.xml
  Classes/ClassAdvice.lua       class tips (TBC-era, labelled)
  Talents/Talents.lua           build engine (no data: PH-TALENTS-SYSTEM)
  Gear/                         gear scoring (TBC weights, off by default)
  Core/Engine.lua               step state machine keyed by step id; trust levels; deferral of pending steps
  Core/StepText.lua             step text + navigation target (verified steps only)
  Core/*.lua, UI/*.lua          tracker, selector, navigation, automation, markers, UI - as in TBCGuide
guides-src/                     guide SOURCES (edit these)
tools/                          build tooling (PowerShell + C#), API allowlist, upstream pins (disabled)
tests/                          headless Lua 5.1 tests, WoW mocks, fixtures/ (TEST ONLY data), tools self-test
docs/                           documentation; docs/generated/ holds build logs; docs/tbcguide-reference/ the TBC originals
```

## Build and test commands

```bash
powershell -ExecutionPolicy Bypass -File tools/build.ps1 all            # guides, lint, validate, routes, report
powershell -ExecutionPolicy Bypass -File tools/build.ps1 test           # headless Lua tests
powershell -ExecutionPolicy Bypass -File tests/tools-selftest.ps1       # build-tool self-test
powershell -ExecutionPolicy Bypass -File tools/build.ps1 package-test   # UNVERIFIED test zip for the client
powershell -ExecutionPolicy Bypass -File tools/build.ps1 package        # release zip; refuses while blockers are open
```

The tests need a Lua 5.1 interpreter on PATH (`lua5.1`) or Python with `lupa` (`python -m pip install lupa`; then
`python tests/run_with_lupa.py`).

## The lint gate

`tools/build.ps1 lint` parses every shipped `.lua` file as Lua 5.1 and fails on syntax errors, undeclared global writes,
and global reads that are not Lua builtins, our own globals, or listed in `tools/wow_api_allowlist.txt`. **Adding a WoW API
is a reviewed decision.** Forever is Retail-based, so a Classic "core" global may be missing: wrap it in `Compat.lua`
and nil-check it.

## Principles

- **Never block the player.** Every step can be marked done, skipped, or (when pending) moved past by hand.
- **Never guess.** Unknown values are nil plus a registry entry, never a plausible number, `0,0` or a sentinel string.
- **Only verified data acts on the game.** Auto-completion, quest automation, waypoints, raid markers and NPC automation all check `ns.Guides:IsTrusted(step)`.
- **Stable ids.** Saved progress is keyed by guide id and step id (plus revision), never by position.
- **Client specifics live in `Config/Target.lua` and `Compat/Compat.lua`.** Unknowns live in `Config/Placeholders.lua`.
- **Fixtures are not routes.** Test data lives only in `tests/fixtures/`, uses invented 99xxxxxx ids, and is never listed in the TOC.
