# Known limitations

Stated plainly, so nobody mistakes "files exist" or "tests pass" for "works in WoW Forever".

## Testing

- **Nothing has run in a WoW Forever client.** The headless suite (`tests/run_tests.lua`, 1,073 checks) and the tools self-test (29 checks) run under real Lua 5.1 and .NET against mocks. The mocks model the *documented* Retail-12.1.5-based API (`docs/COMPATIBILITY.md`), which is not the client. In-client checklist: `docs/SMOKE_TEST.md`.
- TBCGuide 0.1.0 was played in the TBC client by the author. None of that experience transfers to Forever's Retail-based client.

## Platform (see docs/PLACEHOLDERS.md)

- **Release interface unknown.** The TOC carries the beta value 16001 and is marked BLOCKED; `tools/build.ps1 package` refuses to build.
- **Retail quest-log path untested.** If `C_QuestLog.GetInfo` behaves differently on Forever, the guide never completes quest steps automatically. Manual clicks still work.
- **Raid markers:** insecure `SetRaidTarget` is secure-only on Retail 12.x, so automatic and slash-command marking are probably blocked. The add-on detects this and keeps the click-driven marker bar.
- **Orphaned-quest button** hooks `QuestLogFrame`, a Classic frame that a Retail-based UI probably lacks. `/fguide orphans` works without it.
- **SavedVariables** persistence is unconfirmed (one beta report of reload loss).
- **No quest-log capacity and no grey range** are assumed. Until the client reports them, there is no "log full" refusal and no grey-quest skipping.

## Content

- **No leveling route.** Two placeholder guides, eight pending steps. There is no quest, NPC, object, item or zone data, and no map ids.
- **Skyborne** characters get no start guide: the race token is unknown. Every other feature still works for them.
- **Race/class combinations** for the original eight races are inherited from the 2004-era table, unverified for Forever.
- **Talent calculator** has no data. The window says so.
- **Gear scoring** uses TBC weights. It is off by default and labelled, and spec detection is unavailable without talent data.
- **Class tips** are TBCGuide's TBC-era text, labelled.

## Licensing

- Two items inherited from TBCGuide need a decision: the sources of the gear stat-weight numbers (wowsims MIT, Icy Veins) and the provenance of the old CurseForge logo. See `THIRD_PARTY_LICENSES.md` §2.

## Unchanged from TBCGuide

- Escort detection is conservative: any escort signal makes a quest manual. With no database, every quest counts as unknown and is manual.
- Turn-ins with two or more reward choices always wait for the player.
- Junk selling sells only Poor (grey) items and is off by default.
