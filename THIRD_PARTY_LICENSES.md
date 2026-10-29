# Third-party material in ForeverGuide

ForeverGuide's code, guide format, guide sources and documentation are original work by GREYsaurus, adapted from
TBCGuide (same author), licensed **GPL-3.0-only** (see `LICENSE`).

> **This is not legal advice.** It is the project's reading of the licences involved. Get your own advice before
> redistributing commercially.

## 1. Removed in the adaptation (no longer distributed)

| Material | Was in TBCGuide | Licence situation there | Why removed |
|---|---|---|---|
| QuestieDB-derived TBC data (`Database/QuestieTBC/*.lua`, and quest ids, NPC names and coordinates inside `Guides/Compiled/*.lua`) | yes | GPLv3 offered by the Questie team, with residual uncertainty for some historic contributors (see TBCGuide's `THIRD_PARTY_LICENSES.md`) | TBC data does not describe WoW Forever (PH-DATA-QUESTDB) |
| TBC client tables (`Talents/Data/TalentTrees.lua`, race/class table build 2.5.6.70577) | yes | factual game data read from Blizzard client exports | TBC talent trees are not Forever's (PH-TALENTS-SYSTEM) |
| TBC talent builds (`Talents/Builds/*.lua`) | yes | original TBCGuide work | depend on the removed trees |

`Database/RaceClass.lua` keeps the eight original race/class lists (a factual table; status inherited_unverified).

## 2. Still shipped and needing attention

| Material | Where | Source / licence | Status and proposed resolution |
|---|---|---|---|
| Gear stat weights (numbers) | `ForeverGuide/Gear/Profiles.lua`, research in `docs/GEAR_RESEARCH.md` | **S1** wowsims/tbc @ `3301fca`, **MIT** licence; **S2** Icy Veins TBC Classic stat pages, **proprietary website** (numbers for Rogue, Warlock and Restoration Shaman only) | **Open (inherited from TBCGuide, not listed in its notices).** Stat weights are arguably uncopyrightable facts, but this has not been confirmed. Proposed: (a) add the wowsims copyright and MIT permission notice here, copied verbatim from that commit's `LICENSE`, or confirm the handful of numbers is not a "substantial portion"; (b) replace the Icy Veins numbers with priority-only lists, or get permission. Gear scoring is off by default in ForeverGuide and labelled "TBC weights" (PH-GEAR-WEIGHTS). |
| Class leveling tips | `ForeverGuide/Classes/ClassAdvice.lua` | original TBCGuide text | GPL-3.0-only, no third-party content. Labelled inherited_unverified (PH-CLASS-ADVICE). |
| TBCGuide CurseForge logo | `docs/tbcguide-reference/curseforge/logo.png` (documentation only, not in the add-on) | not recorded in TBCGuide | **Unclear provenance.** It is TBCGuide's identity and is not used by ForeverGuide. Proposed: confirm who made it before redistributing, or remove it from the repository. |

No third-party code, libraries, fonts or images are bundled in the add-on folder. UI textures are referenced by
their client paths (for example `Interface\Icons\INV_Misc_QuestionMark`) and are not distributed.

## 3. Sources consulted but not copied

| Source | Used for |
|---|---|
| warcraft.wiki.gg: "World of Warcraft: Forever", "TOC format", "Patch 1.60.1/API changes" (read 2026-10-29; CC BY-SA 4.0) | Facts in `docs/COMPATIBILITY.md` (client base, beta interface, level cap, races). No text copied beyond short facts. |
| Third-party Forever guide sites (wowforeverguides.com, kami-labs.fr and others found by search) | Only as leads; nothing relies on them as evidence (see `docs/COMPATIBILITY.md`). |
| gnu.org | `LICENSE` / `COPYING` are the verbatim GPLv3 text (SHA-256 of the committed file `3972DC9744F6499F0F9B2DBF76696F2AE7AD8AF9B23DDE66D6AF86C9DFB36986`, same as TBCGuide's). |

## 4. Optional integrations (not bundled)

- **TomTom**: if a Forever build is installed, ForeverGuide sends waypoints to it (unverified: PH-INT-TOMTOM). Nothing from TomTom is distributed.
