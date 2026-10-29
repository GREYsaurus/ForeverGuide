# Saved data

ForeverGuide declares its own SavedVariables, `ForeverGuideDB` (account) and `ForeverGuideCharDB` (character).
It never reads or writes TBCGuide's `TBCGuideDB`/`TBCGuideCharDB`, so the two add-ons can be installed together.

## No import from TBCGuide

There is deliberately no TBCGuide import:

- TBCGuide progress refers to TBC guides and quests that do not exist in ForeverGuide.
- It is keyed by step **position**, which can't be mapped to stable step ids safely.
- WoW Forever runs from its own client folder, and per-add-on SavedVariables are only loaded for the add-on that declares them.

If someone copies a TBCGuide file under the ForeverGuide name by hand, the schema-0 migration below drops every position-keyed mark. It keeps settings and says so in chat.

## Layout (schema 1)

```
ForeverGuideDB = {
  schema = 1,
  profiles = { [name] = { ...settings... } }, profileKeys = { ["Char - Realm"] = name }, defaultProfile = "Default",
  junkList, protectedItems, protectedClasses, escortExtra, migrations, minimap, frames,
}
ForeverGuideCharDB = {
  schema = 1,
  activeGuide = "A_Start_Pending",
  progress = { [guideId] = { step = sid|nil, done = { [sid] = rev }, skipped = { [sid] = rev }, deferred = { [sid] = true } } },
  history, talentBuild, simTalents, junkStats, gearProfile, killedRares,
}
```

- `done`/`skipped` store the step's revision (`rev`, default 1). A mark counts only while the step still has that revision.
- `deferred` records placeholder steps the player moved past. A deferral counts only while the step is still a placeholder.
- `step` is informational: the current step is always recomputed from the marks.

## Update rules

| Situation | Behaviour | Test (`tests/run_tests.lua`) |
|---|---|---|
| A placeholder receives verified data, same id | deferral ignored; the real step is open | "a placeholder that received real data is open again" |
| Guide expanded or reordered | marks follow ids, so a new step at position 1 is not inherited as done | "a newly inserted first step is not inherited as done" |
| Step renamed, same objective | `[supersedes=old]` carries done/skipped once | "supersedes carries a done mark to the renamed step" |
| Step objective changed | bump `[rev=N]`; the old mark stops counting | "bumping rev reopens a step whose objective changed" |
| Step removed | mark kept, unused | "progress of a removed step is kept" |
| Saved data without a schema (schema 0) | position-keyed marks dropped, sid marks kept, records repaired, note printed | "migration drops position-keyed marks" |
| Saved data from a newer schema | not migrated and not stamped down; chat note | "data from a newer schema is not downgraded" |
| Malformed fields | repaired field by field, never wholesale | "malformed character data is repaired field by field" |
| Unknown guide id (active or in progress) | progress kept; selection falls back to a recommendation | "progress of an unknown guide id is kept" |
| Reset progress | `/fguide reset` (current guide), `/fguide reset all` (every guide); settings untouched | "/fguide reset all keeps settings" |

## Adding a migration

1. Bump `SCHEMA` in `ForeverGuide/Core/SavedVars.lua`.
2. Add `MIGRATIONS[n] = function(account, char) ... end`. It must be deterministic and idempotent on already-migrated data, and must never delete settings.
3. Add a test in `tests/run_tests.lua` with a saved table of the old shape.
4. Note it in `CHANGELOG.md`.
