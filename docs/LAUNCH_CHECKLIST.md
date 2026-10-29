# Launch-data replacement checklist

Work through this in order once WoW Forever is live. Record evidence for each decision in `docs/COMPATIBILITY.md`, and update each entry in `ForeverGuide/Config/Placeholders.lua` as you resolve it. Never resolve one by guessing.

## 1. Verify client metadata and APIs

- [ ] In the live client run `/run print(GetBuildInfo())`. Record the version, build and **interface number**.
- [ ] Set `## Interface:` in `ForeverGuide/ForeverGuide.toc` and `interface`, `minInterface`, `maxInterface`, `clientBuild` in `Config/Target.lua`. Change `interfaceStatus` to `"verified"` and remove the `## X-Interface-Status: BLOCKED` line. Mark PH-PLATFORM-INTERFACE and PH-PLATFORM-BUILD `verified`.
- [ ] Confirm the AddOns folder path (PH-PLATFORM-ADDONFOLDER) and update README/INSTALL.
- [ ] Install the add-on and run `/fguide debug api`. For every `no`, check that the fallback in `Compat/Compat.lua` is right, or add a wrapper. Add any new global to `tools/wow_api_allowlist.txt` with its status.
- [ ] Check the Retail quest-log path (PH-API-QUESTLOG): accept, progress and turn in a quest, then look at `/fguide debug quest <id>`.
- [ ] Check `SetRaidTarget` from add-on code (PH-API-RAIDTARGET), SavedVariables persistence (PH-PLATFORM-SAVEDVARS), TomTom (PH-INT-TOMTOM) and the options panel.
- [ ] Record `GetMaxPlayerLevel()`, `C_QuestLog.GetMaxNumQuestsCanAccept()` and `GetQuestGreenRange()` (PH-RULES-*). Set `Target.maxLevel` and `Target.questLogMax`, and in the tools `GuideCompiler.LevelCap` and `RouteAnalyzer.LogCap`.
- [ ] Record the Skyborne race token (`select(2, UnitRace("player"))`) and the class list from character creation (PH-RACE-SKYBORNE, PH-RACECLASS-COMBOS). Update `Database/RaceClass.lua` and the race tables in `tools/src/GuideCompiler.cs` together.

## 2. Collect and verify authoritative game data

- [ ] Pick a data source whose licence allows GPL-3.0 redistribution, or collect the data yourself in the client. Record the source, version and licence in `THIRD_PARTY_LICENSES.md` and `tools/upstream.json`, then set `disabled: false` only after the importer targets that source.
- [ ] Generate `ForeverGuide/Database/Data/{Quests,Npcs,Objects,Items,Zones}.lua` in the layout of `Database/Schema.lua`, and add them to the TOC before `Database/RaceClass.lua`.
- [ ] Collect uiMapIDs for each leveling zone (PH-API-MAPIDS) with `C_Map.GetBestMapForUnit("player")`.
- [ ] Rebuild the escort list from verified data (PH-DATA-ESCORTS).

## 3. Replace placeholders by stable identifier

- [ ] For each `pending` step (search `ph=PH-ROUTE-`), write real steps. Either keep the step id and change its type and status, or use new ids (`docs/GUIDE_FORMAT.md`, "Replacing a placeholder").
- [ ] Set each guide's `@status verified` only when every step in it is verified. Use `[status=inherited_unverified]` for anything not checked.
- [ ] Fill `@levels` and `@zone`, and add `@next` chains (PH-ROUTE-LEVELING) and travel steps (PH-ROUTE-TRAVEL).
- [ ] Never reuse an id for a different objective. Use `[rev=]` or a new id.

## 4. Validate guide references and progression

- [ ] Run `powershell -ExecutionPolicy Bypass -File tools/build.ps1 all` (guides, lint, validate, routes, report) and get 0 errors. Read every warning in `docs/generated/guide-warnings.log` and the "content pending" route warnings.
- [ ] Check that `docs/PLACEHOLDERS.md` lists only the entries you intend to leave open.

## 5. Test saved-data updates

- [ ] Run `powershell -ExecutionPolicy Bypass -File tools/build.ps1 test` (headless) and `tests/tools-selftest.ps1`.
- [ ] Add a fixture test for any new migration (`docs/SAVED_DATA.md`).
- [ ] In the client, keep a SavedVariables file from the placeholder build, install the new build, and confirm deferred placeholders now show as open real steps.

## 6. Run in-client tests

- [ ] Work through `docs/SMOKE_TEST.md` on at least one character per faction, and on Skyborne once supported.

## 7. Build a release and document remaining unknowns

- [ ] Create a new CurseForge project. Set `CURSEFORGE_PROJECT_ID`, `CURSEFORGE_GAME_VERSION` and `CF_API_KEY` (PH-PKG-CURSEFORGE). Never reuse TBCGuide's project 1771321.
- [ ] Resolve or document the licensing items in `THIRD_PARTY_LICENSES.md` §2.
- [ ] Bump `## Version:`, update `CHANGELOG.md`, and run `tools/build.ps1 package`. It refuses while any release blocker is open.
- [ ] List the remaining open placeholders in the release notes and `docs/KNOWN_LIMITATIONS.md`.
