# TBCGuide reference material

These files describe **TBCGuide 0.5.0** (TBC Classic Anniversary, interface 20506) and are kept unchanged
for traceability of the ForeverGuide adaptation (docs/PARITY.md). Nothing in them is WoW Forever data.

| File | What it was |
|---|---|
| `RESEARCH.md` | TBCGuide research notes and decisions |
| `ROUTE_OPTIMIZATION.md` | TBC route optimisation model and audit history |
| `CLASS_QUEST_AUDIT.md` | Audit of TBC class quests in the start guides |
| `questie-import.log`, `route-audit-baseline.md`, `route-metrics-baseline.csv` | Build outputs of the TBC data and routes |
| `CURSEFORGE.md`, `curseforge/` | TBCGuide's CurseForge listing text and logo (project 1771321, which ForeverGuide must not reuse) |

The route tooling still reads `docs/generated/route-metrics-baseline.csv` if one exists; ForeverGuide has none yet,
so the route audit reports "No baseline file found" until a verified Forever route is recorded as the baseline.
