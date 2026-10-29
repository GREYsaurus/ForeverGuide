-- ForeverGuide - TEST FIXTURE data (loaded by tests only; never listed in the TOC, never shipped)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- NOT A ROUTE. Every id here is invented for tests and deliberately outside any plausible game range
-- (99xxxxxx), and every name says FIXTURE, so nobody can mistake this for WoW Forever data.
-- Usage: FIXTURE.install(ns) after the add-on files are loaded.

FIXTURE = {}

FIXTURE.Q1, FIXTURE.Q2, FIXTURE.Q3 = 99000001, 99000002, 99000003
FIXTURE.NPC = 99000101
FIXTURE.MOB = 99000102
FIXTURE.ZONE = 99000201

function FIXTURE.install(ns)
    local Q = ns.QDB.QUEST
    local function quest(name, giver, mob)
        local r = {}
        r[Q.NAME], r[Q.REQ_LEVEL], r[Q.LEVEL], r[Q.RACES], r[Q.CLASSES] = name, 1, 1, 0, 0
        r[Q.START_NPCS], r[Q.END_NPCS], r[Q.ZONE] = { giver }, { giver }, FIXTURE.ZONE
        if mob then r[Q.OBJECTIVES] = { c = { mob } } end
        return r
    end
    ns.QDB.quests[FIXTURE.Q1] = quest("FIXTURE Quest One", FIXTURE.NPC, FIXTURE.MOB)
    ns.QDB.quests[FIXTURE.Q2] = quest("FIXTURE Quest Two", FIXTURE.NPC)
    ns.QDB.quests[FIXTURE.Q3] = quest("FIXTURE Quest Three", FIXTURE.NPC)
    local N = ns.QDB.NPC
    local npc = {}
    npc[N.NAME], npc[N.ZONE], npc[N.FRIENDLY], npc[N.SPAWNS] = "FIXTURE Quest Giver", FIXTURE.ZONE, "AH", { [FIXTURE.ZONE] = { { 40, 40 } } }
    ns.QDB.npcs[FIXTURE.NPC] = npc
    local mob = {}
    mob[N.NAME], mob[N.ZONE], mob[N.SPAWNS] = "FIXTURE Target", FIXTURE.ZONE, { [FIXTURE.ZONE] = { { 45, 45 } } }
    ns.QDB.npcs[FIXTURE.MOB] = mob

    ns.Guides:Register({
        id = "FX_Route", name = "FIXTURE route (test only)", faction = "Both", chapter = "Azeroth", status = "verified",
        minLevel = 1, maxLevel = 5, zone = FIXTURE.ZONE, zoneName = "FIXTURE Zone", fixture = true,
        next = {},
        steps = {
            { "accept", sid = "fx.q1.accept", q = FIXTURE.Q1, title = "FIXTURE Quest One", npc = "FIXTURE Quest Giver", z = FIXTURE.ZONE, x = 40, y = 40, v = 1 },
            { "complete", sid = "fx.q1.complete", q = FIXTURE.Q1, title = "FIXTURE Quest One", v = 1 },
            { "turnin", sid = "fx.q1.turnin", q = FIXTURE.Q1, title = "FIXTURE Quest One", npc = "FIXTURE Quest Giver", z = FIXTURE.ZONE, x = 40, y = 40, v = 1 },
            { "pending", sid = "fx.pending", status = "placeholder", ph = "PH-ROUTE-ALLIANCE-START", text = "FIXTURE pending step", v = 0 },
            { "accept", sid = "fx.q2.accept", q = FIXTURE.Q2, status = "inherited_unverified", title = "FIXTURE Quest Two", z = FIXTURE.ZONE, x = 41, y = 41, v = 0 },
            { "goto", sid = "fx.goto", z = FIXTURE.ZONE, x = 50, y = 50, text = "FIXTURE spot", v = 0 },
            { "level", sid = "fx.level3", level = 3, v = 1 },
        },
    })
end

-- The same guide after a "launch data update": the placeholder got real data (same sid, now verified),
-- a step was inserted at the front, fx.goto was renamed to fx.goto2 with supersedes, and the level
-- step was removed. Used to prove saved progress survives content updates safely.
function FIXTURE.updatedSteps()
    return {
        { "note", sid = "fx.new.first", text = "FIXTURE inserted step", v = 1 },
        { "accept", sid = "fx.q1.accept", q = FIXTURE.Q1, title = "FIXTURE Quest One", v = 1 },
        { "complete", sid = "fx.q1.complete", q = FIXTURE.Q1, title = "FIXTURE Quest One", v = 1 },
        { "turnin", sid = "fx.q1.turnin", q = FIXTURE.Q1, title = "FIXTURE Quest One", v = 1 },
        { "accept", sid = "fx.pending", q = FIXTURE.Q3, title = "FIXTURE Quest Three", v = 1 },
        { "accept", sid = "fx.q2.accept", q = FIXTURE.Q2, status = "inherited_unverified", title = "FIXTURE Quest Two", v = 0 },
        { "goto", sid = "fx.goto2", supersedes = { "fx.goto" }, z = FIXTURE.ZONE, x = 50, y = 50, text = "FIXTURE spot", v = 0 },
    }
end

-- Automation fixture (tests/test_automation.lua, test_dungeons.lua): a verified two-guide chain with
-- ordinary, optional, escort, repeatable and class quests, plus quest items. All invented.
FIXTURE.A1, FIXTURE.A2, FIXTURE.T2, FIXTURE.OTHER = 99000011, 99000012, 99000013, 99000014
FIXTURE.ESC_FLAG, FIXTURE.ESC_LIST, FIXTURE.ESC_TEXT = 99000015, 99000016, 99000017
FIXTURE.REP, FIXTURE.CLASSQ, FIXTURE.ITEMQ, FIXTURE.STARTQ, FIXTURE.OPT = 99000018, 99000019, 99000020, 99000021, 99000022
FIXTURE.DUNGEONQ, FIXTURE.AFTERDUNGEON = 99000023, 99000024
FIXTURE.ITEM_OBJ, FIXTURE.ITEM_START = 99000301, 99000302

function FIXTURE.installAutomation(ns)
    local Q = ns.QDB.QUEST
    local function quest(id, name, extra)
        local r = {}
        r[Q.NAME], r[Q.REQ_LEVEL], r[Q.LEVEL], r[Q.RACES], r[Q.CLASSES] = name, 1, 1, 0, 0
        r[Q.START_NPCS], r[Q.END_NPCS], r[Q.ZONE] = { FIXTURE.NPC }, { FIXTURE.NPC }, FIXTURE.ZONE
        r[Q.OBJECTIVES_TEXT] = "FIXTURE objective."
        for k, v in pairs(extra or {}) do r[Q[k]] = v end
        ns.QDB.quests[id] = r
    end
    quest(FIXTURE.A1, "FIXTURE Accept One")
    quest(FIXTURE.A2, "FIXTURE Accept Two")
    quest(FIXTURE.T2, "FIXTURE Turn-in Two")
    quest(FIXTURE.OTHER, "FIXTURE Later Quest")
    quest(FIXTURE.ESC_FLAG, "FIXTURE Party Event", { FLAGS = ns.QDB.QUEST_FLAG_PARTY_ACCEPT })
    quest(FIXTURE.ESC_LIST, "FIXTURE Listed Escort")
    quest(FIXTURE.ESC_TEXT, "FIXTURE Worded Escort", { OBJECTIVES_TEXT = "Escort the FIXTURE caravan to safety." })
    quest(FIXTURE.REP, "FIXTURE Repeatable", { SPECIAL_FLAGS = ns.QDB.SPECIAL_FLAG_REPEATABLE })
    quest(FIXTURE.CLASSQ, "FIXTURE Class Quest", { CLASSES = 1 })
    quest(FIXTURE.ITEMQ, "FIXTURE Item Quest", { OBJECTIVES = { i = { FIXTURE.ITEM_OBJ } } })
    quest(FIXTURE.STARTQ, "FIXTURE Item Start", { START_ITEMS = { FIXTURE.ITEM_START } })
    quest(FIXTURE.OPT, "FIXTURE Optional")
    quest(FIXTURE.DUNGEONQ, "FIXTURE Dungeon Quest")
    quest(FIXTURE.AFTERDUNGEON, "FIXTURE After Dungeon", { PRE_GROUP = { FIXTURE.DUNGEONQ } })
    ns.EscortQuests[FIXTURE.ESC_LIST] = true

    local races = { "Human", "Dwarf", "NightElf", "Gnome" }
    ns.Guides:Register({
        id = "FX_Auto", name = "FIXTURE automation guide (test only)", faction = "Alliance", chapter = "Azeroth",
        status = "verified", minLevel = 1, maxLevel = 5, zone = FIXTURE.ZONE, zoneName = "FIXTURE Zone", races = races,
        next = { { id = "FX_Auto2" } },
        steps = {
            { "accept", sid = "a1.accept", q = FIXTURE.A1, title = "FIXTURE Accept One", v = 1 },
            { "turnin", sid = "a1.turnin", q = FIXTURE.A1, title = "FIXTURE Accept One", v = 1 },
            { "accept", sid = "a2.accept", q = FIXTURE.A2, title = "FIXTURE Accept Two", v = 1 },
            { "accept", sid = "t2.accept", q = FIXTURE.T2, title = "FIXTURE Turn-in Two", v = 1 },
            { "turnin", sid = "t2.turnin", q = FIXTURE.T2, title = "FIXTURE Turn-in Two", v = 1 },
            { "accept", sid = "opt.accept", q = FIXTURE.OPT, title = "FIXTURE Optional", optional = true, v = 1 },
            { "turnin", sid = "opt.turnin", q = FIXTURE.OPT, title = "FIXTURE Optional", optional = true, v = 1 },
            { "accept", sid = "dq.accept", q = FIXTURE.DUNGEONQ, title = "FIXTURE Dungeon Quest", dungeon = "FIXTURE Dungeon", v = 1 },
            { "complete", sid = "dq.complete", q = FIXTURE.DUNGEONQ, title = "FIXTURE Dungeon Quest", dungeon = "FIXTURE Dungeon", v = 1 },
            { "turnin", sid = "dq.turnin", q = FIXTURE.DUNGEONQ, title = "FIXTURE Dungeon Quest", dungeon = "FIXTURE Dungeon", v = 1 },
            { "accept", sid = "ad.accept", q = FIXTURE.AFTERDUNGEON, title = "FIXTURE After Dungeon", v = 1 },
            { "note", sid = "tail", text = "FIXTURE outdoor step", v = 1 },
        },
    })
    ns.Guides:Register({
        id = "FX_Auto2", name = "FIXTURE automation guide 2 (test only)", faction = "Alliance", chapter = "Azeroth",
        status = "verified", minLevel = 5, maxLevel = 8, zone = FIXTURE.ZONE, zoneName = "FIXTURE Zone", races = races,
        next = {},
        steps = {
            { "turnin", sid = "other.turnin", q = FIXTURE.OTHER, title = "FIXTURE Later Quest", v = 1 },
        },
    })
end
