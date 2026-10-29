-- ForeverGuide - headless test runner (Lua 5.1). Run from the repository root:
--     lua5.1 tests/run_tests.lua          (or: python tests/run_with_lupa.py)
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- Runs under any Lua 5.1 interpreter (verified with the Lua 5.1 runtime bundled in Python's
-- `lupa` package; see docs/DEVELOPER.md). The mocks in tests/mock_wow.lua model the documented
-- Retail-12.1.5-based Forever API; passing here does NOT prove the add-on works in the client.

dofile("tests/mock_wow.lua")
dofile("tests/fixtures/fixture_data.lua")

local ADDON = "ForeverGuide"
local root = "ForeverGuide/"
local ns = {}
local failures, passes = 0, 0

local function check(cond, msg)
    if cond then passes = passes + 1 else failures = failures + 1; print("FAIL: " .. msg) end
end

-- Load files in TOC order (expanding XML <Script file=...> includes). Every loaded path is recorded.
local loaded = {}
local function loadFile(path)
    local chunk, err = loadfile(path)
    if not chunk then error("load " .. path .. ": " .. tostring(err)) end
    loaded[#loaded + 1] = path
    chunk(ADDON, ns)
end

local function loadXml(path, dir)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    for file in string.gmatch(text, '<Script%s+file="([^"]+)"') do
        loadFile(dir .. file:gsub("\\", "/"))
    end
end

local tocMeta = {}
local toc = assert(io.open(root .. "ForeverGuide.toc", "r"))
for line in toc:lines() do
    line = line:gsub("\r", "")
    local k, v = line:match("^## ([%w%-]+):%s*(.-)%s*$")
    if k then tocMeta[k] = v end
    if line ~= "" and not line:match("^#") then
        local rel = line:gsub("\\", "/")
        if rel:match("%.xml$") then
            loadXml(root .. rel, root .. rel:match("^(.*/)"))
        else
            loadFile(root .. rel)
        end
    end
end
toc:close()

-- Manifest and namespace isolation -------------------------------------------------------------------
check(tocMeta["SavedVariables"] == "ForeverGuideDB", "TOC declares ForeverGuideDB")
check(tocMeta["SavedVariablesPerCharacter"] == "ForeverGuideCharDB", "TOC declares ForeverGuideCharDB")
check(tocMeta["Interface"] == tostring(ns.Target.interface), "TOC interface matches Config/Target.lua")
check(tocMeta["X-Interface-Status"] and tocMeta["X-Interface-Status"]:match("^BLOCKED"), "TOC flags the unverified interface as BLOCKED")
check(ns.Target.interfaceStatus == "blocked", "Target marks the interface as blocked")
for _, path in ipairs(loaded) do
    check(not path:find("QuestieTBC", 1, true) and not path:find("TalentTrees", 1, true), "no TBC data file is loaded: " .. path)
end

-- Boot ------------------------------------------------------------------------------------------
TBCGuideDB = { sentinel = "tbc" }       -- a coexisting TBCGuide install must never be touched
TBCGuideCharDB = { progress = { A_Human_Elwynn = { step = 3, done = { [1] = true } } } }
MOCK.fire("ADDON_LOADED", ADDON)
MOCK.fire("PLAYER_LOGIN")
MOCK.tick(0.5)

check(type(ns.db) == "table" and type(ns.char) == "table", "saved variables initialised")
check(ns.char == ForeverGuideCharDB and rawget(ns.db, "profile") ~= nil, "ns uses ForeverGuide's own SavedVariables")
check(TBCGuideDB.sentinel == "tbc" and TBCGuideDB.profiles == nil, "TBCGuideDB untouched")
check(TBCGuideCharDB.progress.A_Human_Elwynn.step == 3 and ForeverGuideCharDB.progress.A_Human_Elwynn == nil, "TBCGuideCharDB neither changed nor imported")
check(ForeverGuide == ns and TBCGuide == nil, "global handle is ForeverGuide only")
check(SlashCmdList["FOREVERGUIDE"] ~= nil and SLASH_FOREVERGUIDE1 == "/fguide" and SLASH_FOREVERGUIDE2 == "/foreverguide", "slash commands registered")
check(SlashCmdList["TBCGUIDE"] == nil, "no TBCGuide slash command registered")
check(#ns.errors == 0, "no captured errors after boot: " .. table.concat(ns.errors, " | "))
check(#ns.Guides.rejected == 0, "no rejected guides: " .. table.concat(ns.Guides.rejected, " | "))
check(ns.DB.HasData() == false, "no quest database ships (PH-DATA-QUESTDB)")
check(next(ns.TalentTrees or {}) == nil and #ns.Talents.buildList == 0, "no talent data ships (PH-TALENTS-SYSTEM)")
check(next(ns.EscortQuests) == nil, "escort list holds no inherited TBC quest ids")

-- Shipped guides are placeholders --------------------------------------------------------------------
check(#ns.Guides.list == 2, "two shipped guides (" .. #ns.Guides.list .. ")")
for _, g in ipairs(ns.Guides.list) do
    check(g.status == "placeholder" and ns.Guides:IsPlaceholderOnly(g), g.id .. " is placeholder-only")
    check(g.levelsKnown == false, g.id .. " has no invented level range")
    for _, s in ipairs(g.steps) do
        check(s.q == nil and s.x == nil and s.z == nil and s.mark == nil, g.id .. "/" .. s.sid .. " carries no live data")
        check(ns.PlaceholderById[s.ph] ~= nil, g.id .. "/" .. s.sid .. " names a registered placeholder")
    end
end
check(ns.Engine.guide and ns.Engine.guide.id == "A_Start_Pending", "human warrior gets the Alliance placeholder start guide")
local cur = ns.Engine:CurrentStep()
check(cur and cur[1] == "pending" and ns.StepText:Title(cur):find(ns.PENDING_LABEL, 1, true), "current step is shown as " .. ns.PENDING_LABEL)
check(ns.StepText:Target(cur) == nil, "a pending step produces no waypoint")
check(pcall(function() ns.MainFrame:Render() end), "main window renders a pending step")
-- Moving past placeholders: deferred, never done; the end is not reported as complete.
local mark = #MOCK.printed
for _ = 1, 4 do ns.Engine:MarkDone() end
check(ns.Engine.current == nil, "every pending step can be moved past (no deadlock)")
local done, total, deferred = ns.Engine:Counts()
check(done == 0 and deferred == 4 and total == 4, "deferred placeholders are not counted as done")
check(next(ns.Engine.progress.done) == nil and ns.Engine.progress.deferred["a.start.route"] == true, "saved as deferred, not done")
local claimedComplete = false
for i = mark + 1, #MOCK.printed do if MOCK.printed[i]:find("Guide complete", 1, true) then claimedComplete = true end end
check(not claimedComplete, "reaching the end of a placeholder guide is not announced as complete")
ns.Engine:Prev()
check(ns.Engine.status[4] == "active" and ns.Engine.progress.deferred["a.start.next"] == nil, "prev reopens a deferred step")
ns.Engine:Reset()

-- Registry rejects unsafe content ----------------------------------------------------------------------
local G = ns.Guides
local nRejected, nErrors = #G.rejected, #ns.errors
local function rejects(id, step, why)
    G:Register({ id = id, name = "t", faction = "Alliance", status = "verified", steps = { step } })
    check(G.byId[id] == nil, "registry rejects " .. why)
end
rejects("T_NoSid", { "note", text = "x" }, "a step without a stable id")
rejects("T_PhLive", { "pending", sid = "p", status = "placeholder", ph = "PH-ROUTE-LEVELING", q = 1 }, "a placeholder step with a quest id")
rejects("T_PhCoord", { "pending", sid = "p", status = "placeholder", ph = "PH-ROUTE-LEVELING", z = 1, x = 5, y = 5 }, "a placeholder step with coordinates")
rejects("T_PhUnknown", { "pending", sid = "p", status = "placeholder", ph = "PH-DOES-NOT-EXIST" }, "an unknown placeholder id")
rejects("T_PhMissing", { "pending", sid = "p", status = "placeholder" }, "a placeholder step without ph")
rejects("T_PendingVerified", { "pending", sid = "p" }, "a pending step claiming verified status")
rejects("T_ZeroZero", { "goto", sid = "g", z = 1, x = 0, y = 0 }, "0,0 used as a position")
rejects("T_SentinelQuest", { "accept", sid = "a", q = "UNKNOWN" }, "a sentinel string as a quest id")
rejects("T_BadStatus", { "note", sid = "n", status = "maybe", text = "x" }, "an unknown status")
G:Register({ id = "T_DupSid", name = "t", faction = "Alliance", status = "verified", steps = { { "note", sid = "x", text = "a" }, { "note", sid = "x", text = "b" } } })
check(G.byId["T_DupSid"] == nil, "registry rejects duplicate step ids")
G:Register({ id = "A_Start_Pending", name = "dup", faction = "Alliance", status = "placeholder", steps = { { "pending", sid = "p", status = "placeholder", ph = "PH-ROUTE-LEVELING" } } })
check(G.byId["A_Start_Pending"].name ~= "dup", "registry rejects duplicate guide ids")
while #G.rejected > nRejected do table.remove(G.rejected) end
while #ns.errors > nErrors do table.remove(ns.errors) end

-- Fixture route: completion, trust levels, stable ids ----------------------------------------------------
FIXTURE.install(ns)
check(G.byId["FX_Route"] ~= nil, "fixture guide registered")
local Q1, Q2 = FIXTURE.Q1, FIXTURE.Q2
ns.Engine:Load("FX_Route", { reset = true })
check(ns.Engine:CurrentStep().sid == "fx.q1.accept", "fixture starts at its first step")
table.insert(MOCK.questLog, { id = Q1, title = "FIXTURE Quest One", complete = false, objectives = { { text = "FIXTURE Target slain: 0/1", done = false } } })
MOCK.fire("QUEST_ACCEPTED", Q1)
MOCK.tick(0.5)
check(ns.Engine:CurrentStep().sid == "fx.q1.complete", "accepting (Retail quest log API) completes the accept step")
check(ns.Tracker:InLog(Q1) and #ns.Tracker:GetEntry(Q1).objectives == 1, "C_QuestLog scan reads the quest and its objectives")
MOCK.questLog[1].complete = true
MOCK.questLog[1].objectives[1].done = true
MOCK.fire("QUEST_LOG_UPDATE")
MOCK.tick(0.5)
check(ns.Engine:CurrentStep().sid == "fx.q1.turnin", "objectives done -> turn-in step")
table.remove(MOCK.questLog, 1)
MOCK.completed[Q1] = true
MOCK.fire("QUEST_TURNED_IN", Q1, 0, 0)
MOCK.tick(0.5)
check(ns.Engine:CurrentStep().sid == "fx.pending", "turn-in completes; the placeholder step is next")
check(ns.Engine.status[4] == "active" and ns.Engine.progress.done["fx.pending"] == nil, "placeholder is active, not done")
-- A placeholder's position must never be matched by quest events.
table.insert(MOCK.questLog, { id = FIXTURE.Q3, title = "FIXTURE Quest Three", complete = true, objectives = {} })
MOCK.fire("QUEST_ACCEPTED", FIXTURE.Q3)
MOCK.tick(0.5)
check(ns.Engine:CurrentStep().sid == "fx.pending", "an unrelated quest never completes a placeholder")
table.remove(MOCK.questLog)
ns.Engine:Skip()
check(ns.Engine.progress.deferred["fx.pending"] == true and ns.Engine.progress.skipped["fx.pending"] == nil, "skip on a placeholder defers it")
check(ns.Engine:CurrentStep().sid == "fx.q2.accept", "inherited_unverified step is next")
table.insert(MOCK.questLog, { id = Q2, title = "FIXTURE Quest Two", complete = true, objectives = {} })
MOCK.fire("QUEST_ACCEPTED", Q2)
MOCK.tick(0.5)
check(ns.Engine:CurrentStep().sid == "fx.q2.accept", "an inherited_unverified step never completes automatically")
check(ns.StepText:Target(ns.Engine:CurrentStep()) == nil, "an inherited_unverified step gives no waypoint")
check(table.concat(ns.StepText:Details(ns.Engine:CurrentStep()), "\n"):find("Unverified for WoW Forever", 1, true), "unverified step is labelled")
ns.QuestAuto:Rebuild()
check(ns.QuestAuto.acceptOpen[Q2] == nil, "quest automation ignores unverified steps")
ns.Engine:MarkDone()
check(ns.Engine.progress.done["fx.q2.accept"] == 1, "manual confirmation records sid -> rev")
table.remove(MOCK.questLog)
ns.Engine:MarkDone() -- goto
MOCK.player.level = 3
MOCK.fire("PLAYER_LEVEL_UP", 3)
MOCK.tick(1)
check(ns.Engine.current == nil, "level step completes from the player's level")
MOCK.player.level = 1

-- Content update: insertion, placeholder replaced by real data, rename with supersedes, removal.
local fx = G.byId["FX_Route"]
local savedProgress = ns.Copy(ns.char.progress["FX_Route"])
fx.steps = FIXTURE.updatedSteps()
for i, s in ipairs(fx.steps) do s.status = s.status or "verified"; s.index = i end
ns.Engine:Load("FX_Route")
check(ns.Engine.status[1] == "active", "a newly inserted first step is not inherited as done from position 1")
check(ns.Engine.status[2] == "done" and ns.Engine.status[4] == "done", "done steps keep their state after reordering")
check(ns.Engine.status[5] ~= "done" and ns.Engine.status[5] ~= "deferred", "a placeholder that received real data is open again (deferral not carried over)")
check(ns.Engine.status[6] == "done", "a manually confirmed step stays done after reordering")
check(ns.Engine.progress.done["fx.goto2"] ~= nil and ns.Engine.status[7] == "done", "supersedes carries a done mark to the renamed step")
check(ns.Engine.progress.done["fx.level3"] ~= nil, "progress of a removed step is kept (harmless if the step returns)")
-- Revision bump: an objective that changed meaning is open again.
fx.steps[6].rev = 2
ns.Engine:Load("FX_Route")
check(ns.Engine.status[6] ~= "done", "bumping rev reopens a step whose objective changed")
ns.char.progress["FX_Route"] = savedProgress

-- Saved data: schema, migrations, repair, unknown guides, reset -------------------------------------
check(ForeverGuideDB.schema == ns.SCHEMA and ForeverGuideCharDB.schema == ns.SCHEMA, "schema recorded")
ForeverGuideCharDB = { progress = { FX_Route = { step = 5, done = { [1] = true, [2] = true, ["fx.q1.accept"] = 1 }, skipped = { [3] = true } } },
                       activeGuide = "FX_Route" } -- position-keyed, no schema: TBCGuide layout
ns.migrationNote = nil
ns:InitSavedVariables()
local rec = ns.char.progress.FX_Route
check(rec.done[1] == nil and rec.done[2] == nil and rec.skipped[3] == nil, "migration drops position-keyed marks")
check(rec.done["fx.q1.accept"] == 1 and rec.step == nil and type(rec.deferred) == "table", "migration keeps sid-keyed marks and repairs the record")
check(ns.migrationNote and ns.migrationNote:find("3 position-based", 1, true), "migration explains what was dropped")
check(ForeverGuideCharDB.schema == ns.SCHEMA, "migrated data is stamped with the current schema")
ForeverGuideCharDB = { schema = ns.SCHEMA + 5, progress = { X = { done = { ["a"] = 1 } } } }
ns.newerSchema = nil
ns:InitSavedVariables()
check(ns.newerSchema == ns.SCHEMA + 5 and ForeverGuideCharDB.schema == ns.SCHEMA + 5, "data from a newer schema is not downgraded")
ForeverGuideCharDB = { progress = "garbage", activeGuide = 42, history = 7 }
ns:InitSavedVariables()
check(type(ns.char.progress) == "table" and ns.char.activeGuide == nil and type(ns.char.history) == "table", "malformed character data is repaired field by field")
ForeverGuideCharDB = { progress = {} }
ns:InitSavedVariables()
ns.db.profile.scale = 1.3
ns.char.progress.FX_Route = { done = { a = 1 }, skipped = {}, deferred = {} }
SlashCmdList["FOREVERGUIDE"]("reset all")
check(ns.char.progress.FX_Route == nil or next(ns.char.progress.FX_Route.done) == nil, "/fguide reset all clears progress")
check(ns.db.profile.scale == 1.3, "/fguide reset all keeps settings")
ns.db.profile.scale = 1

-- Compat: Classic fallback path and missing APIs -------------------------------------------------------
MOCK.useLegacyQuestLog()
local savedInfo = C_QuestLog.GetInfo
C_QuestLog.GetInfo = nil
table.insert(MOCK.questLog, { id = Q1, title = "FIXTURE Quest One", complete = false, objectives = { { text = "o", done = true } } })
local log = ns.Compat.ScanQuestLog()
check(log[Q1] and log[Q1].objectives[1].done == true, "legacy GetQuestLogTitle path still works")
MOCK.useModernQuestLog()
C_QuestLog.GetInfo = savedInfo
log = ns.Compat.ScanQuestLog()
check(log[Q1] and log[Q1].index == 1, "modern path after switching back")
local savedQL = C_QuestLog
C_QuestLog = { IsQuestFlaggedCompleted = savedQL.IsQuestFlaggedCompleted }
check(next(ns.Compat.ScanQuestLog()) == nil and ns.Compat.missing["C_QuestLog.GetInfo"], "no quest log API -> empty scan, recorded as missing, no error")
local count, max = ns.Compat.QuestLogSize()
check(max == nil, "unknown quest log capacity stays nil (no TBC default of 25)")
C_QuestLog = savedQL
table.remove(MOCK.questLog)
check(ns.Engine:IsGrey(Q1) == false, "no grey-quest decision without GetQuestGreenRange (PH-RULES-GREYRANGE)")

-- Commands do not error
for _, cmd in ipairs({ "", "help", "guide", "talents", "debug", "debug api", "debug placeholders", "debug ph route",
    "debug talents", "debug quest 99000001", "class", "bogus", "next", "prev", "skip" }) do
    local ok, err = pcall(SlashCmdList["FOREVERGUIDE"], cmd)
    check(ok, "/fguide " .. cmd .. " -> " .. tostring(err))
end
check(pcall(function() ns.TalentFrame:Render() end), "talent window renders without talent data")

-- Grind steps (in-memory guide; completion follows the player's LEVEL, never XP) ---------------------
nRejected, nErrors = #G.rejected, #ns.errors
G:Register({ id = "T_GrindNoLevel", name = "t", faction = "Alliance", status = "verified", steps = { { "grind", sid = "g", mobs = { "X" } } } })
check(G.byId["T_GrindNoLevel"] == nil and #G.rejected == nRejected + 1, "registry rejects a grind step without a level")
while #G.rejected > nRejected do table.remove(G.rejected) end
while #ns.errors > nErrors do table.remove(ns.errors) end
G:Register({ id = "T_Grind", name = "Grind test", faction = "Alliance", status = "verified", minLevel = 3, maxLevel = 5, steps = {
    { "note", sid = "before", text = "before" },
    { "grind", sid = "grind5", level = 5, mobs = { "FIXTURE Target" }, location = "FIXTURE spot",
      z = FIXTURE.ZONE, x = 27.8, y = 81.2, text = "Kill until 5." },
    { "note", sid = "after", text = "after" },
} })
MOCK.player.level = 3
ns.Engine:Load("T_Grind", { reset = true })
ns.Engine:MarkDone(1)
check(ns.Engine.current == 2 and ns.Engine.status[2] == "active", "grind step becomes the current step")
MOCK.fire("PLAYER_XP_UPDATE")
MOCK.tick(1)
check(ns.Engine.current == 2, "grind step stays active below the target level")
local gs = ns.Engine:CurrentStep()
check(string.find(ns.StepText:Title(gs), "Grind FIXTURE Target at FIXTURE spot until level 5", 1, true), "title names mobs, place, level")
local tz, tx, ty = ns.StepText:Target(gs)
check(tz == FIXTURE.ZONE and tx == 27.8 and ty == 81.2, "navigation target is the grind spot")
MOCK.player.level = 5
MOCK.fire("PLAYER_LEVEL_UP", 5)
MOCK.tick(1)
check(ns.Engine.current == 3 and ns.Engine.progress.done["grind5"] == 1, "reaching the level completes and remembers it")
MOCK.player.level = 1
ns.Engine:Load("A_Start_Pending")

-- Feature suites carried over from TBCGuide, adapted to fixture data -----------------------------------
TEST = { check = check, ns = ns }
dofile("tests/test_automation.lua")
dofile("tests/test_markers.lua")
dofile("tests/test_gear.lua")
dofile("tests/test_minimap.lua")
dofile("tests/test_config.lua")
dofile("tests/test_dungeons.lua")

-- Re-login cases (last: PLAYER_LOGIN re-runs every module's Init, which would double event handlers).
ForeverGuideCharDB = { activeGuide = "GUIDE_FROM_A_NEWER_VERSION", progress = { GUIDE_FROM_A_NEWER_VERSION = { done = { s = 1 } } } }
ns:InitSavedVariables()
MOCK.interface = 16002
local mark = #MOCK.printed
MOCK.fire("PLAYER_LOGIN")
check(ns.char.progress.GUIDE_FROM_A_NEWER_VERSION.done.s == 1, "progress of an unknown guide id is kept, not deleted")
check(ns.Engine.guide and ns.Engine.guide.id ~= "GUIDE_FROM_A_NEWER_VERSION", "an unknown active guide falls back to a recommendation")
local warned = false
for i = mark + 1, #MOCK.printed do if MOCK.printed[i]:find("built for interface 16001", 1, true) then warned = true end end
check(warned, "a different client interface number is reported")
MOCK.interface = nil

print(string.format("%d passed, %d failed", passes, failures))
os.exit(failures == 0 and 0 or 1)
