# Writing guides (`guides-src/*.guide`)

Guides are plain text, one step per line. `tools/build.ps1 guides` compiles them into `ForeverGuide/Guides/Compiled/*.lua` and checks them against the bundled quest database. **Never edit the compiled files.**

This is TBCGuide's format with the smallest extensions needed for WoW Forever: stable step ids, content status, and placeholders. The extensions are marked **(ForeverGuide)**.

Files are compiled in path order (`alliance/`, `horde/`, then any other folder, then file name). That order matters for the route checks: a turn-in in a later file can match an accept in an earlier one.

## Header

```
@guide A_Westfall                  unique id (never reuse or rename a shipped id: saved progress is keyed by it)
@name Westfall                     display name
@faction Alliance                  Alliance | Horde | Both
@status verified                   (ForeverGuide) verified | inherited_unverified | placeholder | blocked - required
@races Human,Dwarf                 optional; Night Elf / NightElf, Undead / Scourge accepted. Only the eight original races.
@classes Warrior                   optional; usually omitted
@levels 10-16                      intended level range (max 60, PH-RULES-LEVELCAP); `?` = unknown, placeholder/blocked guides only
@zone Westfall                     zone name exactly as in the bundled zone table; `?` = unknown, placeholder/blocked guides only
@chapter Azeroth                   Azeroth
@start                             marks a racial starting guide (requires @races)
@desc Free text, can repeat to continue.
@next A_Redridge                   next guide; repeatable, first match wins
@next H_Feralas [faction=Horde]    conditions: [race=..] [class=..] [faction=..]
```

## Steps

```
<verb> <arguments> [flags] | <note text> [flags]
```

**Every step needs `[id=...]` (ForeverGuide).** Ids are 1-64 characters from letters, digits and `_ . : -`, unique within the guide. Saved progress is keyed by this id, never by position. Use readable, namespaced ids (`a.elwynn.wolves.accept`). `train`, and `fp`/`bind` in `Both` guides, expand into several steps; the compiler appends `:CLASS` or `:Faction` to the id.

| Verb | Arguments | Completes when |
|---|---|---|
| `accept` | quest | quest is in the log or already turned in |
| `turnin` | quest | quest-completed flag / `QUEST_TURNED_IN` |
| `complete` | quest (`[obj=N]` for one objective) | quest log reports complete |
| `goto` | `x,y` (zone = guide zone, or `[zone=...]`) | arrow arrives within 12 yards, or manual |
| `talk` | NPC name or id | manual |
| `train` | - (expands to one step per class, with that class's trainer from the database) | trainer window closed |
| `fp` | place name | "New flight path discovered" or taxi map opened |
| `fly` / `hs` / `travel` | destination zone/subzone name | zone change to the destination, or manual |
| `bind` | inn location name | `GetBindLocation()` matches |
| `level` | level | player level reached |
| `grind` | `<level> <Mob>[, <Mob>...] [@ location]` | player level reached (same as `level`). Each mob must exist in the database and spawn in the step's zone |
| `note` / `buy` / `use` / `collect` | text | manual (`buy` also completes on closing a vendor) |
| `guide` | guide id | manual |
| `pending` **(ForeverGuide)** | text describing what is missing | **never**. The player can only move past it (deferred, not done). |

Automatic completion applies only to steps whose status is `verified`. Other statuses always need a click.

### Content status (ForeverGuide)

| Status | Meaning | Allowed content | Runtime |
|---|---|---|---|
| `verified` | data confirmed for WoW Forever | anything | completes automatically; drives quest automation, waypoints and raid markers |
| `inherited_unverified` | carried over from TBCGuide or another source, not checked | anything | labelled "Unverified for WoW Forever"; manual completion only; no automation, waypoints or markers |
| `placeholder` | data not available yet | `pending` steps only, with `[ph=...]`; no quest ids, coordinates, zones, marks or levels | shown as "Pending WoW Forever data"; can be deferred, never done |
| `blocked` | cannot be written until a dependency is resolved | as `placeholder` | as `placeholder` |

Steps inherit the guide's `@status`; override it per step with `[status=...]`.

### Placeholders (ForeverGuide)

```
pending Starting zone and first quests for your race [id=a.start.route; ph=PH-ROUTE-ALLIANCE-START]
```

`ph` must name an entry in `ForeverGuide/Config/Placeholders.lua`, the central registry. The build fails on an unknown id. `docs/PLACEHOLDERS.md` is generated from that file.

Unknown values are **left out**, never guessed. Do not write `0,0`, `?`, or a sentinel string into a numeric field. The registry rejects these at load time, and the compiler rejects coordinates on pending steps.

### Replacing a placeholder

Either of these works. Choose by what the saved progress should mean.

1. **Keep the id, change the content.** Turn `pending ... [id=a.start.route; ph=...]` into a real step: `accept 12345 [id=a.start.route]` in a `verified` guide. A deferral recorded for the placeholder stops applying automatically, so players see the real step as open.
2. **New ids.** Replace the pending line with several real steps that have new ids. Old deferrals stay in saved data, are ignored, and do no harm.

### Revisions and renames

- `[rev=2]`: bump when a step keeps its id but its objective changes meaning. Saved done/skipped marks for the old revision stop counting.
- `[supersedes=old.id1,old.id2]`: a renamed step that is the *same* objective inherits a done or skipped mark from any listed id, once. Deferrals of placeholders are never carried over.
- Removing a step: just delete the line. Its saved mark is kept harmlessly in case the step comes back.

### Quest references

- `accept A Threat Within`: by name. The compiler finds the quest that fits the guide's faction and races, is not yet done on the route, and has its prerequisites met.
- `accept 783`: by id.
- `accept 783 A Threat Within`: id plus name. The compiler fails if they disagree, which catches typos.

All of these need verified Forever data in `ForeverGuide/Database/Data/`. Until it exists (PH-DATA-QUESTDB), every quest reference fails the build. That is intended.

### Flags

`[id=...]` (required), `[status=...]`, `[ph=PH-...]`, `[rev=N]`, `[supersedes=a,b]`, `[optional]`, `[elite]`, `[group]` or `[group=3]`, `[dungeon=<instance>]`, `[class=Warrior,Paladin]`, `[race=Human]`, `[zone=<zone>]`, `[at=x,y]` (explicit coordinates; marked unverified), `[obj=2]`, `[unverified]`, `[mark=skull]` / `[mark=cross:<NPC name>]` / `[mark=star:<npc id>]` (raid marker; see docs/RAID_MARKERS.md). Separate several flags with `;` inside one bracket: `[id=x.1; elite; group=3; optional]`.

**Dungeon quests:** tag every step (accept, complete, turn-in) of a quest that can only be done inside an instance with `[dungeon=<instance>]`. The *Include Dungeon Quests* setting leaves tagged steps out of the route. Follow-up quests that need an excluded dungeon quest are skipped automatically.

### What the compiler adds for you

- the quest title, giver/finisher NPC name and coordinates (the spawn nearest the previous step);
- trainers, flight masters and innkeepers, looked up by NPC flags in the zone;
- a coordinate flag: `v=1` for database-derived data, `v=0` for hand-written coordinates (separate from `status`).

### What the compiler checks

Errors (the build fails):

- missing or duplicate step ids, missing `@status`;
- pending/placeholder mismatches, unknown placeholder ids, live data on pending steps;
- unknown or ambiguous quests, quests not available to the guide's faction or races, class quests without `[class=]`;
- unknown zones or guides, races not playable in Forever, malformed lines.

Warnings (`docs/generated/guide-warnings.log`): prerequisites not turned in anywhere on the route, turn-ins without an accept, quests whose required level is above the guide's range, repeatable quests, and complete-steps with no objective location in the data.

## Route checks (`tools/build.ps1 routes`)

After compiling, every race/class route is walked step by step. The build fails if a quest is accepted before one of its prerequisites is turned in on that route, or if a complete-step comes before its accept. The quest-log cap check is off until the Forever capacity is known (PH-RULES-QUESTLOG). `tools/build.ps1 validate` reports a route that ends in placeholder guides as a warning ("content pending"), not as reaching the cap.
