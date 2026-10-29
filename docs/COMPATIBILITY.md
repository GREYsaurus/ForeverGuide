# Client compatibility and evidence log

Every consequential platform decision, with its evidence class:

- **verified_source**: read in ForeverGuide/TBCGuide source code.
- **verified_docs**: stated by documentation that was read (date given).
- **verified_runtime**: observed in a running WoW Forever client. **Nothing is in this class yet.**
- **unverified**: an assumption, kept behind a capability check.
- **blocked**: cannot be decided until the information exists.

Headless tests use mocks modelled on the documentation below. Passing tests do **not** prove in-client behaviour.

## Target

| Item | Value | Evidence | Class |
|---|---|---|---|
| Product | World of Warcraft: Forever, a separate permanent branch alongside Retail and Classic. Launch 2026-11-04 00:00 UTC, beta ended 2026-09-17. | warcraft.wiki.gg "World of Warcraft: Forever" (read 2026-10-29) | verified_docs |
| Client base | Retail **12.1.5** (build 69952). Forever 1.60.1 build 70205 is diffed against it: 176 global API functions added, 10 removed. | warcraft.wiki.gg "Patch 1.60.1/API changes" (read 2026-10-29) | verified_docs |
| TOC game type | `forever` (equivalent to `camelot`). TOC suffixes `_Forever.toc` and `_Camelot.toc`. Family suffix `_Mainline.toc`. | same page; warcraft.wiki.gg "TOC format" | verified_docs |
| TOC interface | **16001** for Forever Beta/Test. **Release value not listed.** | warcraft.wiki.gg "TOC format" | **blocked** (PH-PLATFORM-INTERFACE) |
| Release build number | unknown (beta builds 1.60.1.70205 / 70291; a fan site names 70450) | — | placeholder (PH-PLATFORM-BUILD) |
| Lua | 5.1 (every WoW client embeds Lua 5.1) | general WoW add-on knowledge; nothing Forever-specific contradicts it | unverified |
| Level cap | 60, "no planned increases" | warcraft.wiki.gg "World of Warcraft: Forever" | verified_docs, not runtime (PH-RULES-LEVELCAP) |
| Races | Alliance Human, Dwarf, Gnome, Night Elf; Horde Orc, Tauren, Troll, Undead; Skyborne (new, both factions). Races from TBC or later are not playable. | same page | verified_docs. Race/class combinations: inherited_unverified (PH-RACECLASS-COMBOS). Skyborne token: placeholder (PH-RACE-SKYBORNE). |
| Classes | the nine original classes | same page | verified_docs |
| Install folder | `_forever_\Interface\AddOns` | third-party guides only | placeholder (PH-PLATFORM-ADDONFOLDER) |
| SavedVariables reload | One third-party beta report says SavedVariables were written but not read back. | timesaver.gg blog (single report, not acknowledged by Blizzard) | placeholder (PH-PLATFORM-SAVEDVARS) |

**Decision: ship `ForeverGuide.toc` with `## Interface: 16001`, marked `## X-Interface-Status: BLOCKED`.** A TOC is
needed for in-client testing. The release value is unknown, so `tools/build.ps1 package` refuses to build while the
flag is set. `Config/Target.lua` warns in chat when the client reports any other interface number. The plain
`ForeverGuide.toc` name loads on every flavor. Once the release value is known, a `_Forever.toc` can be added if
other flavors need to be excluded.

## API decisions (all behind `ForeverGuide/Compat/Compat.lua`)

Retail 12.1.5 removed the Classic quest-log globals. So for each feature, ForeverGuide prefers the documented Retail
form and keeps TBCGuide's Classic form as a fallback. Every call is nil-checked, and a missing API leaves
`ns.Compat.missing` set (`/fguide debug api`).

| Feature | Preferred (Retail form) | Fallback (TBCGuide form) | If both missing | Class |
|---|---|---|---|---|
| Quest log scan | `C_QuestLog.GetNumQuestLogEntries`, `GetInfo`, `GetQuestObjectives`, `IsComplete`, `IsFailed` | `GetQuestLogTitle`, `GetQuestLogLeaderBoard` | empty log; steps stay manual | unverified (PH-API-QUESTLOG) |
| Quest completion | `C_QuestLog.IsQuestFlaggedCompleted` | `IsQuestFlaggedCompleted`, `GetQuestsCompleted` | false (manual) | unverified |
| Quest log capacity | `C_QuestLog.GetMaxNumQuestsCanAccept` | `MAX_QUESTLOG_QUESTS`, then `Target.questLogMax` (nil) | **no log-full check** (no TBC default of 25) | unverified (PH-RULES-QUESTLOG) |
| Abandon | `C_QuestLog.SetSelectedQuest/SetAbandonQuest/AbandonQuest` (quest ID re-checked) | `SelectQuestLogEntry/SetAbandonQuest/AbandonQuest` | refused | unverified |
| Grey-quest check | `GetQuestGreenRange` | — | no grey decision (TBC default 8 removed) | unverified (PH-RULES-GREYRANGE) |
| Gossip / greeting / quest panels | `C_GossipInfo.*` (quest IDs), `GetQuestID`, `AcceptQuest`, `CompleteQuest`, `GetQuestReward` | legacy `Gossip*` globals | manual | unverified |
| Bags / items | `C_Container.*`, `C_Item.GetItemInfo` | legacy globals | junk selling inert | unverified |
| Map / arrow | `C_Map.*`, `CreateVector2D`, `GetPlayerFacing` | — | plain coordinates | unverified. Map IDs are a placeholder (PH-API-MAPIDS), so no shipped step has coordinates. |
| Raid markers | `SetRaidTarget` via pcall; `ADDON_ACTION_BLOCKED` detection | secure marker-bar buttons | marking off, bar remains | unverified. Retail 12.0 made `SetRaidTarget` secure-only and Forever is 12.1.5-based, so expect the fallback (PH-API-RAIDTARGET). |
| Talents | — | `GetTalentInfo` and friends (TBC) | calculator shows "Pending WoW Forever data" | **blocked** (PH-API-TALENTS, PH-TALENTS-SYSTEM) |
| Options panel | `Settings.RegisterCanvasLayoutCategory` | `InterfaceOptions_AddCategory` | `/fguide set` | unverified |
| Orphaned-quest button | `QuestLogFrame` (Classic frame) | — | button skipped; `/fguide orphans` still works | unverified. Retail uses `QuestMapFrame`, so the button is likely absent. |
| TomTom | `TomTom.AddWaypoint` | — | built-in arrow only | unverified (PH-INT-TOMTOM) |

No external automation, memory access, injection or restriction bypass is used. Only the documented in-game add-on API is called.

## In-game verification

See `docs/SMOKE_TEST.md`. None of it has been run: no WoW Forever client was available during the adaptation.
