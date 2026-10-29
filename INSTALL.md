# Installing ForeverGuide

**There is no release.** Release packaging stays blocked until the WoW Forever release interface number is verified
(`docs/LAUNCH_CHECKLIST.md`, step 1). The steps below are for in-client **testing** only.

## Test build

1. Build: `powershell -ExecutionPolicy Bypass -File tools/build.ps1 package-test`. This writes `dist/ForeverGuide-<version>-UNVERIFIED-TEST.zip`, which contains `TEST-BUILD-NOT-A-RELEASE.txt`.
2. Close the game.
3. Copy the `ForeverGuide` folder (the one with `ForeverGuide.toc`) into the Forever client's AddOns folder. Third-party guides give `World of Warcraft\_forever_\Interface\AddOns\` (unconfirmed, PH-PLATFORM-ADDONFOLDER). The result must be `...\AddOns\ForeverGuide\ForeverGuide.toc`, with no extra folder level.
4. Start the game. Under **AddOns**, tick ForeverGuide. If it is marked out of date, tick **Load out of date AddOns**, and record that in the smoke test, because it means the interface number differs.
5. Work through `docs/SMOKE_TEST.md`.

ForeverGuide can be installed next to TBCGuide: the folders, globals, slash commands and SavedVariables differ.

## From source

- Requirements: Windows PowerShell 5.1+ (the build compiles its C# tools with `Add-Type`), plus a Lua 5.1 interpreter or Python with `lupa` for tests.
- `tools/build.ps1 all` runs guides, lint, validate, routes and report.
- `tools/build.ps1 test` runs the headless tests.
- `tools/build.ps1 package` builds a release zip. It refuses while blockers are open.

`tools/build.ps1 fetch`, `import-questie` and `import-client` are disabled. They pinned TBC data (`tools/upstream.json`).
