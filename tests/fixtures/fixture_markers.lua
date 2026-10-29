-- ForeverGuide - TEST FIXTURE for raid-marker tests (tests/test_markers.lua). Never shipped.
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Replaces the TBC guides the original TBCGuide tests used (Durotar's Sarkoth, Elwynn, Dun Morogh)
-- with invented ids of the same shape: one named [mark=skull] target, one kill objective, and two kill
-- steps done in parallel (the first with two NPC variants of one objective).

FIXTURE.SARK, FIXTURE.OBJMOB, FIXTURE.TROGG, FIXTURE.TROGG2, FIXTURE.BOAR = 99000401, 99000402, 99000403, 99000404, 99000405
FIXTURE.MQ_SARK, FIXTURE.MQ_OBJ, FIXTURE.MQ_A, FIXTURE.MQ_B = 99000031, 99000032, 99000033, 99000034

function FIXTURE.installMarkers(ns)
    local Q, N = ns.QDB.QUEST, ns.QDB.NPC
    local function mob(id, name)
        local r = {}
        r[N.NAME], r[N.MIN_LEVEL], r[N.MAX_LEVEL], r[N.RANK], r[N.ZONE] = name, 1, 2, 0, FIXTURE.ZONE
        r[N.SPAWNS] = { [FIXTURE.ZONE] = { { 30, 30 } } }
        ns.QDB.npcs[id] = r
    end
    mob(FIXTURE.SARK, "FIXTURE Named Target")
    mob(FIXTURE.OBJMOB, "FIXTURE Objective Mob")
    mob(FIXTURE.TROGG, "FIXTURE Trogg")
    mob(FIXTURE.TROGG2, "FIXTURE Trogg Variant")
    mob(FIXTURE.BOAR, "FIXTURE Boar")
    local function quest(id, name, creatures)
        local r = {}
        r[Q.NAME], r[Q.REQ_LEVEL], r[Q.LEVEL], r[Q.RACES], r[Q.CLASSES] = name, 1, 1, 0, 0
        r[Q.START_NPCS], r[Q.END_NPCS], r[Q.ZONE] = { FIXTURE.NPC }, { FIXTURE.NPC }, FIXTURE.ZONE
        r[Q.OBJECTIVES] = { c = creatures }
        ns.QDB.quests[id] = r
    end
    quest(FIXTURE.MQ_SARK, "FIXTURE Slay the Named Target", { FIXTURE.SARK })
    quest(FIXTURE.MQ_OBJ, "FIXTURE Kill Objective", { FIXTURE.OBJMOB })
    quest(FIXTURE.MQ_A, "FIXTURE Troggs", { FIXTURE.TROGG, FIXTURE.TROGG2 })
    quest(FIXTURE.MQ_B, "FIXTURE Boars", { FIXTURE.BOAR })

    local function guide(id, faction, steps)
        ns.Guides:Register({ id = id, name = id .. " (FIXTURE)", faction = faction, chapter = "Azeroth", status = "verified",
            minLevel = 1, maxLevel = 5, zone = FIXTURE.ZONE, zoneName = "FIXTURE Zone", next = {}, steps = steps })
    end
    guide("FX_MarkSkull", "Horde", {
        { "note", sid = "ms.before", text = "FIXTURE before" },
        { "complete", sid = "ms.sark", q = FIXTURE.MQ_SARK, title = "FIXTURE Slay the Named Target", mark = { i = 8, npcs = { FIXTURE.SARK } }, v = 1 },
        { "note", sid = "ms.after", text = "FIXTURE after" },
    })
    guide("FX_MarkObj", "Alliance", {
        { "note", sid = "mo.before", text = "FIXTURE before" },
        { "complete", sid = "mo.obj", q = FIXTURE.MQ_OBJ, title = "FIXTURE Kill Objective", v = 1 },
        { "note", sid = "mo.after", text = "FIXTURE after" },
    })
    guide("FX_MarkMulti", "Alliance", {
        { "complete", sid = "mm.a", q = FIXTURE.MQ_A, title = "FIXTURE Troggs", v = 1 },
        { "complete", sid = "mm.b", q = FIXTURE.MQ_B, title = "FIXTURE Boars", v = 1 },
        { "note", sid = "mm.after", text = "FIXTURE after" },
    })
end
