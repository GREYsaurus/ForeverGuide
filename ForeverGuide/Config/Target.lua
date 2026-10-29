-- ForeverGuide - target client and ruleset configuration
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- Adapted from TBCGuide (https://github.com/GREYsaurus/TBCGuide), same author.
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Everything that depends on WHICH client / realm ruleset we run on lives here, so a launch update
-- is a config edit, not a code rewrite. Every value carries its evidence class (docs/COMPATIBILITY.md):
--   verified_source | verified_docs | verified_runtime | unverified | blocked
-- A nil value means "unknown": callers must treat it as missing and never substitute a guess.
-- Open items are listed in Config/Placeholders.lua and docs/PLACEHOLDERS.md.

local _, ns = ...

ns.Target = {
    name = "World of Warcraft: Forever",

    -- warcraft.wiki.gg "Patch 1.60.1/API changes" (read 2026-10-29): Forever 1.60.1 is built on the
    -- Retail 12.1.5 client, TOC 16001, game type "forever" (= "camelot"). The TOC format page lists
    -- 16001 for Forever Beta/Test only; the RELEASE interface is not published. PH-PLATFORM-INTERFACE.
    interface = 16001,
    interfaceStatus = "blocked",       -- beta value; release value unverified -> packaging refuses to build
    clientBase = "Retail 12.1.5",      -- verified_docs
    clientBuild = nil,                 -- PH-PLATFORM-BUILD: release build number unknown
    -- The add-on warns when the client reports any other interface number.
    minInterface = 16001,
    maxInterface = 16001,

    -- Ruleset ------------------------------------------------------------------------------
    -- warcraft.wiki.gg "World of Warcraft: Forever": "level cap is 60". Documented, not observed in a
    -- client: unverified. Used only for display and level-range validation. PH-RULES-LEVELCAP.
    maxLevel = 60,
    maxLevelStatus = "unverified",
    -- Talent system: fan sites describe a trait-based tree with a different point budget. Nothing is
    -- verified, so the talent calculator is BLOCKED and these stay nil. PH-TALENTS-SYSTEM.
    firstTalentLevel = nil,
    talentPointsAt = function() return 0 end,
    -- Quest log capacity. Only used if the client does not report it (C_QuestLog.GetMaxNumQuestsCanAccept).
    -- PH-RULES-QUESTLOG: no documented Forever value; nil makes the log-full check rely on the client.
    questLogMax = nil,
    -- Default XP multiplier. Advisory "grind" notes only. PH-RULES-XPRATE.
    xpRate = nil,

    -- Optional integrations (all optional; the guide works without any of them) ----------------
    integrations = {
        TomTom = true,       -- waypoints via TomTom if a Forever build of it is loaded (unverified)
        Questie = false,     -- never required
    },
}

-- Private ruleset add-ons can override values before PLAYER_LOGIN, e.g. ForeverGuide.Target.xpRate = 3
