-- ForeverGuide - headless tests: "Include Dungeon Quests" (steps tagged [dungeon=...])
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
-- Loaded by tests/run_tests.lua after boot; uses TEST.check and TEST.ns.
-- ForeverGuide: TBCGuide ran these on Horde Ashenvale's "Amongst the Ruins" (Blackfathom Deeps). With
-- no Forever data, the same checks run on the fixture guide FX_Auto (tests/fixtures/fixture_data.lua).

local check, ns = TEST.check, TEST.ns
local E, G = ns.Engine, ns.Guides
local function prof() return ns.db.profile end
local DQ, AFTER = FIXTURE.DUNGEONQ, FIXTURE.AFTERDUNGEON

check(prof().showDungeonSteps == true, "Include Dungeon Quests is on by default")

MOCK.player.race, MOCK.player.class, MOCK.player.faction, MOCK.player.level = "Human", "WARRIOR", "Alliance", 2
MOCK.questLog, MOCK.completed = {}, {}
ns.Tracker.turnedIn = {}
ns.Tracker:Scan()

local g = G.byId["FX_Auto"]
local acc, comp, tin, outdoor
for i, s in ipairs(g.steps) do
    if s.q == DQ then
        check(s.dungeon == "FIXTURE Dungeon", "step " .. i .. " of the dungeon quest is tagged as a dungeon step")
        if s[1] == "accept" then acc = i elseif s[1] == "complete" then comp = i else tin = i end
    end
    if s.q == FIXTURE.T2 and s[1] == "turnin" then outdoor = i end
end
check(acc and comp and tin and acc < comp and comp < tin, "dungeon quest has accept, complete and turn-in steps")
local tagged = 0
for _, gg in ipairs(G.list) do for _, s in ipairs(gg.steps) do if s.dungeon then tagged = tagged + 1 end end end
check(tagged == 3, "only the 3 fixture dungeon steps are tagged; shipped guides tag none (" .. tagged .. ")")

local function loadAt(idx)
    E:Load("FX_Auto", { reset = true })
    for i = 1, idx - 1 do E.progress.done[g.steps[i].sid] = 1 end
    E:Refresh()
end

-- enabled: the dungeon quest is part of the route
loadAt(acc)
check(E.current == acc and E.status[comp] == "pending" and E.status[tin] == "pending", "enabled: the dungeon quest is offered")

-- disabled from the settings window: pickup, objective and turn-in leave the route at once
local CF = ns.Config
CF:Show("guide")
local w
for _, x in ipairs(CF.built.guide.widgets) do if x.item and x.item.label == "Include Dungeon Quests" then w = x end end
check(w ~= nil and string.find(w.item.tip, "skips dungeon quests", 1, true), "settings window has 'Include Dungeon Quests' with its description")
w.frame:SetChecked(false)
w.frame.scripts.OnClick(w.frame)
check(prof().showDungeonSteps == false, "unticking saves the setting")
check(E.status[acc] == "na" and E.status[comp] == "na" and E.status[tin] == "na", "disabled: pickup, objective and turn-in are excluded")
check(E.current and E.current > acc and g.steps[E.current].dungeon == nil, "the guide moves on to the next outdoor step")
check(E.progress.done[g.steps[acc - 1].sid] == 1, "earlier progress is kept")
local cur = E.current
E:Refresh()
E:Refresh()
check(E.current == cur, "excluded steps do not come back on refresh")
check(outdoor and E.status[outdoor] ~= "na", "the outdoor quest at the same NPC stays in the route")
CF.frame:Hide()

-- persists over a reload
ns:InitSavedVariables()
check(ns.db.profile.showDungeonSteps == false, "the setting survives a reload")

-- a dungeon quest already in the log is never dropped (ForeverGuide does not abandon quests)
table.insert(MOCK.questLog, { id = DQ, title = "FIXTURE Dungeon Quest", complete = false, objectives = {} })
ns.Tracker:Scan()
E:Refresh()
check(E.status[comp] ~= "na" and E.status[tin] ~= "na", "accepted dungeon quest: its objective and turn-in stay")
MOCK.questLog = {}
ns.Tracker:Scan()
E:Refresh()

-- enabling again brings the steps back, without duplicates or lost progress
local doneBefore = 0
for _ in pairs(E.progress.done) do doneBefore = doneBefore + 1 end
prof().showDungeonSteps = true
CF:Changed()
check(E.status[acc] ~= "na" and E.status[comp] ~= "na" and E.status[tin] ~= "na", "enabled again: the dungeon steps return")
local doneAfter = 0
for _ in pairs(E.progress.done) do doneAfter = doneAfter + 1 end
check(doneAfter == doneBefore and #g.steps == #G.byId["FX_Auto"].steps, "no steps duplicated, progress unchanged")

-- a turned-in dungeon quest is never offered again, whichever way the setting is
MOCK.completed[DQ] = true
ns.Tracker:Scan()
E:Refresh()
check(E.status[acc] == "done" and E.status[tin] == "done", "completed dungeon quest counts as done")
prof().showDungeonSteps = false
E:Refresh()
check(E.status[acc] ~= "pending" and E.status[acc] ~= "active" and E.status[tin] ~= "pending" and E.status[tin] ~= "active", "completed dungeon quest is not reintroduced")
MOCK.completed[DQ] = nil
ns.Tracker:Scan()

-- Only tagged steps (and their follow-ups) change; everything else is untouched -------------------------
local function statuses(id)
    E:Load(id, { reset = true })
    local out = {}
    for i = 1, #E.guide.steps do out[i] = E.status[i] end
    return out
end
for _, id in ipairs({ "A_Start_Pending", "FX_Auto", "FX_Auto2" }) do
    prof().showDungeonSteps = true
    local on = statuses(id)
    prof().showDungeonSteps = false
    local off = statuses(id)
    local diff = 0
    for i, s in ipairs(G.byId[id].steps) do
        if on[i] ~= off[i] and not s.dungeon and s.q ~= AFTER then diff = diff + 1 end
    end
    check(diff == 0, id .. ": only dungeon-tagged steps change (" .. diff .. " others did)")
end

-- Quest chains: a follow-up that needs an excluded dungeon quest is skipped, not stuck ------------------
G:Register({ id = "T_DungeonChain", name = "Dungeon chain test", faction = "Alliance", status = "verified", minLevel = 1, maxLevel = 5, steps = {
    { "accept", sid = "c1", q = DQ, dungeon = "FIXTURE Dungeon" },
    { "accept", sid = "c2", q = AFTER },
    { "complete", sid = "c3", q = AFTER },
    { "turnin", sid = "c4", q = AFTER },
    { "note", sid = "c5", text = "outdoor step" },
} })
prof().showDungeonSteps = false
E:Load("T_DungeonChain", { reset = true })
check(E.status[1] == "na", "chain: excluded pickup")
check(E.status[2] == "skipped" and string.find(E.autoReason[2], "dungeon", 1, true), "chain: the follow-up that needs it is skipped with a reason")
check(E.status[3] == "skipped" and E.status[4] == "skipped", "chain: its objective and turn-in are skipped too")
check(E.current == 5, "chain: the guide continues with the next valid step")
MOCK.completed[DQ] = true
ns.Tracker:Scan()
E:Refresh()
check(E.status[2] ~= "skipped", "chain: once the dungeon quest is done the follow-up is offered")
MOCK.completed[DQ] = nil
ns.Tracker:Scan()
prof().showDungeonSteps = true
E:Refresh()
check(E.status[1] ~= "na" and E.status[2] ~= "skipped", "chain: enabled again, everything is back")

-- Quest automation never auto-accepts an excluded dungeon quest -----------------------------------------
prof().showDungeonSteps = false
E:Load("FX_Auto", { reset = true })
local ok, why = ns.QuestAuto:CanAccept(DQ)
check(not ok, "automation does not accept an excluded dungeon quest: " .. tostring(why))
prof().showDungeonSteps = true

-- restore
MOCK.player.race, MOCK.player.class, MOCK.player.faction, MOCK.player.level = "Human", "WARRIOR", "Alliance", 1
E:Load("A_Start_Pending", { reset = true })
check(#ns.errors == 0, "no captured errors after dungeon tests: " .. table.concat(ns.errors, " | "))
