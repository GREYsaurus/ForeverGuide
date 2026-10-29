-- ForeverGuide - saved variables, defaults and migrations
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- ForeverGuideDB      (account-wide): settings profiles, protection lists, frame positions
--   .profiles[name]       one table per profile (the settings below)
--   .profileKeys[char]    "Name - Realm" -> profile name used by that character
--   .defaultProfile       profile new characters start with
-- ForeverGuideCharDB  (per character): active guide, per-guide progress, simulated talents
-- Both are validated on load; anything malformed is reset field-by-field, never wholesale.
-- These names are ForeverGuide's own: TBCGuide's TBCGuideDB/TBCGuideCharDB are never read or written
-- (docs/SAVED_DATA.md explains why there is no import).
-- ns.db is a view of ForeverGuideDB whose `profile` field is the active profile; every other field
-- reads and writes ForeverGuideDB itself, so the profile table is never saved twice.

local _, ns = ...

-- Saved-data schema. Bump it and add a MIGRATIONS entry for every incompatible change
-- (docs/SAVED_DATA.md). Migrations run in order, once, and must be deterministic.
local SCHEMA = 1
ns.SCHEMA = SCHEMA

local profileDefaults = {
        debug = false,
        autoAdvance = true,       -- move to the next step when a reliable completion signal arrives
        autoSelectGuide = true,   -- pick a guide automatically on first login
        showArrow = true,
        showMapPins = true,
        useTomTom = true,
        stepsShown = 4,           -- current step + upcoming
        scale = 1,
        locked = false,
        hideCompletedOptional = false,
        showDungeonSteps = true,  -- Include Dungeon Quests: steps tagged [dungeon=...] (docs/GUIDE_FORMAT.md)
        showElite = true,
        speedRoute = false,       -- maximum-speed route: hide [optional] side quests (documented default: off)
        talentHints = true,       -- remind when talent points are unspent
        -- Automation (docs/AUTOMATION.md). Quest automation only ever touches quests that have an
        -- open step in the active guide; escort quests and reward choices are always manual.
        autoAccept = true,          -- accept guide quests when their offer panel opens
        autoAcceptOptional = false, -- ...including steps marked [optional]
        autoAcceptGroup = false,    -- ...including [elite]/[group]/[dungeon] steps
        autoTurnIn = true,          -- turn in guide quests that need no reward choice
        turnInUnrelated = false,    -- also turn in completed quests that are not in the guide
        questNotify = true,         -- chat messages for accepted / turned-in / manual quests
        autoSellJunk = false,       -- OFF by default: sell grey (Poor) items when a vendor opens
        sellNotify = true,          -- chat summary of junk sales
        sellNotifyItems = false,    -- one chat line per item sold
        -- Raid markers (docs/RAID_MARKERS.md)
        markEnabled = true,         -- /fguide mark, the marker bar and guide marking
        autoMark = true,            -- mark NPCs the current guide step names with [mark=...]
        autoMarkObjectives = true,  -- also mark kill objectives / item droppers of the current steps
        markReplace = false,        -- automatic marking may replace an existing icon
        markClearOnAdvance = true,  -- remove our automatic icons when the step changes
        markNotify = true,          -- chat messages for marking results
        defaultMarker = 8,          -- 1 star .. 8 skull
        showMarkerBar = false,
        showMinimapButton = true,   -- minimap button (left-click: settings, right-click: guide window)
        -- Gear scoring (docs/GEAR_RESEARCH.md); read-only, never equips or chooses anything
        gearEnabled = false,        -- ForeverGuide: OFF by default; the weights are TBC research (PH-GEAR-WEIGHTS)
        gearTooltip = true,         -- score lines on item tooltips
        gearQuestRewards = true,    -- rank reward choices in chat
        gearShowPercent = true,     -- relative score change (%), only when both scores are valid
        gearShowConfidence = true,
        -- Settings window (UI/Config.lua); features in Core/Assist.lua
        showAllFrames = true,       -- master switch for the guide window and arrow
        hideWindow = false,
        autohideRaid = false,       -- hide the guide window and arrow while in a raid group
        worldMapButton = true,      -- ForeverGuide button on the world map
        autoReward = false,         -- choose a quest reward when gear scoring finds a clear winner
        trainerAuto = false,        -- learn affordable spells at your class trainer
        flightAuto = true,          -- fly to the current fly step's destination when the taxi map opens
        bindAuto = true,            -- confirm the hearthstone bind on the guide's bind step
        skipGossip = true,          -- pick the only gossip option when an NPC offers nothing else
        inventoryManager = true,    -- master switch for junk selling, junk list and junk deletion
        junkModifierToggle = false, -- mark/unmark items as junk with modifier + right-click in bags
        junkModifier = "CTRL",
        discardJunkFull = false,    -- delete the cheapest junk item when the bags are full
        skipOverleveled = true,     -- skip accept steps of quests that are grey for you
        disableStepSkips = false,   -- never skip steps automatically (debug)
        maxNameplateDistance = false, -- raise the nameplate CVar to its maximum (41 yards)
        markFriendly = true,        -- also mark the quest giver/finisher of the current step
        markInGroup = true,         -- allow automatic marking while in a group
        targetMacro = true,         -- keep a "ForeverGuide" macro targeting the current step's NPCs
        targetNotify = true,        -- chat note when a current-step mob or NPC first comes into view
        announceLevelEmote = false, announceLevelParty = false, announceLevelGuild = false,
        tipsEnabled = true,
        drownWarn = true, drownSound = true, drownFlash = true, drownThreshold = 20,
        lowHealthWarn = true, lowHealthThreshold = 20, lowHealthFlash = false, lowHealthAnim = true,
        trackRares = false,         -- chat alert when a rare mob's nameplate appears
        skipKilledRares = false,    -- ...but not for rares this character already killed
        colorFriendly = { r = 0.4, g = 0.8, b = 1 },  -- NPC names in step text
        colorQuest = { r = 1, g = 0.82, b = 0 },      -- quest names
        colorWarning = { r = 1, g = 0.47, b = 0.27 }, -- warnings
        guideFontSize = 12,
        showStepList = true,        -- show upcoming steps under the current one
        arrowScale = 1,
        arrowUpdateMs = 50,
        checkConflicts = true,      -- warn about other guide add-ons that act on the same NPCs
}

local accountDefaults = {
    schema = SCHEMA,
    profiles = {},
    profileKeys = {},
    defaultProfile = "Default",
    junkList = {},          -- [itemID] = true: items the player marked as junk
    protectedItems = {},    -- [itemID] = true: never sold automatically
    protectedClasses = {},  -- [itemClassID] = true/false: overrides Vendor.CLASSES defaults
    escortExtra = {},       -- [questID] = true: extra quests that must never be auto-accepted
    migrations = {},        -- [name] = true: one-time setting changes already applied
    minimap = { angle = 220 }, -- minimap button position: degrees around the minimap
    frames = {
        main = { point = "RIGHT", x = -60, y = 120, w = 320, h = 230, minimized = false, shown = true },
        browser = { point = "CENTER", x = 0, y = 0 },
        talents = { point = "CENTER", x = 0, y = 0 },
        arrow = { point = "TOP", x = 0, y = -120 },
        orphans = { point = "CENTER", x = 0, y = 0 },
        markerBar = { point = "TOP", x = 0, y = -200 },
    },
}

local charDefaults = {
    schema = SCHEMA,
    activeGuide = nil,
    progress = {},      -- [guideId] = { step = sid, done = { [sid] = rev }, skipped = { [sid] = rev }, deferred = { [sid] = true } }
    history = {},       -- recently used guide ids (most recent first)
    talentBuild = nil,  -- chosen build id for this character
    simTalents = {},    -- [class] = { [talentId] = rank } simulated allocation in the calculator
    junkStats = { items = 0, copper = 0 }, -- confirmed automatic junk sales (all time)
    gearProfile = nil,  -- chosen gear profile id (Gear/Profiles.lua); nil = automatic
    killedRares = {},   -- [npcID] = true: rares this character killed (skipKilledRares)
}
ns.PROFILE_DEFAULTS = profileDefaults

-- "Name - Realm" for the current character.
function ns.CharKey()
    local name = UnitName and UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Realm"
    return tostring(name) .. " - " .. tostring(realm)
end

-- Fills a profile table with defaults and repairs invalid values.
function ns.FixProfile(p)
    ns.Merge(p, profileDefaults)
    local dm = p.defaultMarker
    if type(dm) ~= "number" or dm < 1 or dm > 8 then p.defaultMarker = 8 end
    if p.junkModifier ~= "CTRL" and p.junkModifier ~= "ALT" and p.junkModifier ~= "SHIFT" then p.junkModifier = "CTRL" end
    for _, k in ipairs({ "colorFriendly", "colorQuest", "colorWarning" }) do
        local c = p[k]
        if type(c) ~= "table" or type(c.r) ~= "number" or type(c.g) ~= "number" or type(c.b) ~= "number" then
            local d = profileDefaults[k]
            p[k] = { r = d.r, g = d.g, b = d.b }
        end
    end
    return p
end

-- Keeps only [sid] = rev entries (string key, positive integer revision). Position-keyed entries
-- (numeric keys, as TBCGuide stored them) are dropped: a position says nothing about which objective
-- was done once steps are inserted, removed or reordered. Returns the number of entries dropped.
local function sanitizeMarks(t, flag)
    local dropped = 0
    for k, v in pairs(t) do
        local ok = type(k) == "string" and k ~= ""
        if ok and flag then ok = v == true
        elseif ok then ok = type(v) == "number" and v >= 1 and v == math.floor(v) end
        if not ok then t[k] = nil dropped = dropped + 1 end
    end
    return dropped
end

-- Progress records of guides that are not installed (renamed, removed, or from a newer version) are
-- kept untouched so they come back if the guide does; they are never matched to another guide.
local function sanitizeProgress(p)
    if type(p) ~= "table" then return {}, 0 end
    local dropped = 0
    for guideId, rec in pairs(p) do
        if type(guideId) ~= "string" or type(rec) ~= "table" then
            p[guideId] = nil
        else
            if rec.step ~= nil and type(rec.step) ~= "string" then rec.step = nil end
            for _, key in ipairs({ "done", "skipped", "deferred" }) do
                if type(rec[key]) ~= "table" then rec[key] = {} end
                dropped = dropped + sanitizeMarks(rec[key], key == "deferred")
            end
        end
    end
    return p, dropped
end
ns.SanitizeProgress = sanitizeProgress

-- MIGRATIONS[n] upgrades saved data from schema n-1 to n. Schema 0 = no schema field: a table written
-- by a pre-release build or copied by hand from another add-on.
local MIGRATIONS = {
    [1] = function(account, char)
        -- Index-keyed progress cannot be mapped to stable step ids safely: drop it (sanitizeProgress
        -- does the dropping); keep the guide history so the browser still lists recent guides.
        local _, dropped = sanitizeProgress(char.progress or {})
        if dropped > 0 then
            ns.migrationNote = string.format("discarded %d position-based progress mark(s) from older saved data; "
                .. "they cannot be matched to steps safely.", dropped)
        end
    end,
}
ns.MIGRATIONS = MIGRATIONS

local function migrate(sv, account, char)
    local from = type(sv.schema) == "number" and sv.schema or 0
    if from > SCHEMA then
        -- Written by a newer ForeverGuide: never downgrade or rewrite it.
        ns.newerSchema = from
        return false
    end
    for n = from + 1, SCHEMA do
        if MIGRATIONS[n] then MIGRATIONS[n](account, char) end
    end
    return true
end

function ns:InitSavedVariables()
    local fresh = type(ForeverGuideDB) ~= "table" or next(ForeverGuideDB) == nil
    if type(ForeverGuideDB) ~= "table" then ForeverGuideDB = {} end
    if type(ForeverGuideCharDB) ~= "table" then ForeverGuideCharDB = {} end
    if fresh then ForeverGuideDB.schema = SCHEMA end
    if next(ForeverGuideCharDB) == nil then ForeverGuideCharDB.schema = SCHEMA end
    local charOk = migrate(ForeverGuideCharDB, ForeverGuideDB, ForeverGuideCharDB)
    local accountOk = migrate(ForeverGuideDB, ForeverGuideDB, ForeverGuideCharDB)
    -- Before 0.5.0 there was a single ForeverGuideDB.profile; it becomes the "Default" profile.
    local legacy = type(ForeverGuideDB.profile) == "table" and ForeverGuideDB.profile or nil
    ForeverGuideDB.profile = nil
    ns.Merge(ForeverGuideDB, accountDefaults)
    ns.Merge(ForeverGuideCharDB, charDefaults)
    for _, key in ipairs({ "profiles", "profileKeys", "junkList" }) do
        if type(ForeverGuideDB[key]) ~= "table" then ForeverGuideDB[key] = {} end
    end
    local profiles = ForeverGuideDB.profiles
    for name, p in pairs(profiles) do
        if type(name) ~= "string" or type(p) ~= "table" then profiles[name] = nil end
    end
    if legacy and not profiles.Default then profiles.Default = legacy end
    if type(ForeverGuideDB.defaultProfile) ~= "string" then ForeverGuideDB.defaultProfile = "Default" end
    if type(ForeverGuideCharDB.killedRares) ~= "table" then ForeverGuideCharDB.killedRares = {} end
    ForeverGuideCharDB.progress = sanitizeProgress(ForeverGuideCharDB.progress)
    if type(ForeverGuideCharDB.history) ~= "table" then ForeverGuideCharDB.history = {} end
    if type(ForeverGuideCharDB.simTalents) ~= "table" then ForeverGuideCharDB.simTalents = {} end
    for _, key in ipairs({ "protectedItems", "protectedClasses", "escortExtra", "migrations" }) do
        if type(ForeverGuideDB[key]) ~= "table" then ForeverGuideDB[key] = {} end
    end
    -- After 0.4.0: objective marking became the default (before, only 5 guide steps marked anything).
    -- Saved settings from earlier versions still hold the old default, so turn it on once.
    local mig = ForeverGuideDB.migrations
    if not mig.objectiveMarking then
        mig.objectiveMarking = true
        local flipped = false
        for _, p in pairs(profiles) do
            if not fresh and p.autoMarkObjectives == false then p.autoMarkObjectives = true flipped = true end
        end
        if flipped then
            ns.migrationNote = "raid markers now also mark the mobs of your current kill steps. "
                .. "Turn this off with /fguide set autoMarkObjectives off."
        end
    end
    -- Active profile for this character.
    local key = ns.CharKey()
    local active = ForeverGuideDB.profileKeys[key]
    if type(active) ~= "string" or type(profiles[active]) ~= "table" then
        active = ForeverGuideDB.defaultProfile
        if type(profiles[active]) ~= "table" and active ~= "Default" and type(profiles.Default) == "table" then active = "Default" end
        ForeverGuideDB.profileKeys[key] = active
    end
    profiles[active] = profiles[active] or {}
    for _, p in pairs(profiles) do ns.FixProfile(p) end
    local mm = ForeverGuideDB.minimap
    if type(mm) ~= "table" then ForeverGuideDB.minimap = { angle = 220 } mm = ForeverGuideDB.minimap end
    local ang = tonumber(mm.angle)
    if not ang or ang ~= ang or ang == math.huge or ang == -math.huge then mm.angle = 220 else mm.angle = ang % 360 end
    local js = ForeverGuideCharDB.junkStats
    if type(js) ~= "table" or type(js.items) ~= "number" or type(js.copper) ~= "number" then
        ForeverGuideCharDB.junkStats = { items = 0, copper = 0 }
    end
    if ForeverGuideCharDB.gearProfile ~= nil and type(ForeverGuideCharDB.gearProfile) ~= "string" then
        ForeverGuideCharDB.gearProfile = nil
    end
    if ForeverGuideCharDB.activeGuide ~= nil and type(ForeverGuideCharDB.activeGuide) ~= "string" then
        ForeverGuideCharDB.activeGuide = nil
    end
    if accountOk then ForeverGuideDB.schema = SCHEMA end
    if charOk then ForeverGuideCharDB.schema = SCHEMA end
    ns:SetActiveProfile(active)
    ns.char = ForeverGuideCharDB
end

-- Points ns.db at ForeverGuideDB with `profile` = the named profile (which must exist).
function ns:SetActiveProfile(name)
    ns.db = setmetatable({ profile = ForeverGuideDB.profiles[name], profileName = name }, {
        __index = ForeverGuideDB,
        __newindex = ForeverGuideDB,
    })
end

function ns:GetProgress(guideId)
    local p = ns.char.progress[guideId]
    if not p then
        p = { done = {}, skipped = {}, deferred = {} }
        ns.char.progress[guideId] = p
    end
    return p
end

function ns:ResetProgress(guideId)
    ns.char.progress[guideId] = { done = {}, skipped = {}, deferred = {} }
end

-- Clears this character's progress in every guide. Settings, profiles and lists are not touched.
function ns:ResetAllProgress()
    ns.char.progress = {}
end

function ns:ResetSettings()
    ForeverGuideDB = nil
    ns:InitSavedVariables()
end
