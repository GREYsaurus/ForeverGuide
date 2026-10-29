-- ForeverGuide - central placeholder registry
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Single source of truth for everything ForeverGuide does NOT know yet about WoW Forever. Guide steps
-- point at these ids with ph="PH-..."; tools/build.ps1 validate fails on an unknown id, and
-- tools/build.ps1 report writes docs/PLACEHOLDERS.md from this file. Search the repo for an id to find
-- every record it affects. Resolve an entry by supplying verified data, then set status="verified"
-- (or delete it once nothing references it). Never resolve one by guessing a plausible value.
--
-- Fields: id, area, missing, why, type (expected type of the missing value), affects (files/records),
--         evidence (what is needed to resolve it), status (placeholder | blocked | inherited_unverified | verified)

local _, ns = ...

ns.Placeholders = {
    -- Platform / packaging ----------------------------------------------------------------------
    { id = "PH-PLATFORM-INTERFACE", area = "packaging", status = "blocked",
      missing = "TOC ## Interface value of the WoW Forever release client",
      why = "warcraft.wiki.gg lists 16001 for Forever Beta/Test only; no release value published before launch",
      type = "integer", affects = "ForeverGuide/ForeverGuide.toc, Config/Target.lua (interface, min/maxInterface)",
      evidence = "select(4, GetBuildInfo()) on the live Forever client, or Blizzard/warcraft.wiki.gg TOC listing for release" },
    { id = "PH-PLATFORM-BUILD", area = "platform", status = "placeholder",
      missing = "Release client build number",
      why = "only beta builds (1.60.1.70205 / 70291 / 70450) are documented",
      type = "string", affects = "Config/Target.lua (clientBuild)",
      evidence = "select(2, GetBuildInfo()) on the live client" },
    { id = "PH-PLATFORM-SAVEDVARS", area = "platform", status = "placeholder",
      missing = "Whether the client reliably reads SavedVariables back after /reload and relog",
      why = "one third-party beta report says the beta client wrote SavedVariables but did not reload them; unconfirmed by Blizzard",
      type = "behaviour", affects = "Core/SavedVars.lua (all persistence)",
      evidence = "in-client smoke test: change a setting, /reload, relog; confirm it persists (docs/SMOKE_TEST.md)" },
    { id = "PH-PLATFORM-ADDONFOLDER", area = "packaging", status = "placeholder",
      missing = "Install path of the live client's AddOns folder",
      why = "third-party guides name _forever_\\Interface\\AddOns; not confirmed by an official source",
      type = "path", affects = "README.md, INSTALL.md",
      evidence = "the folder created by the Battle.net launcher for the live Forever client" },

    -- Client API (Retail 12.1.5 base; every call is capability-checked in Compat/Compat.lua) ----------
    { id = "PH-API-QUESTLOG", area = "api", status = "placeholder",
      missing = "Runtime behaviour of C_QuestLog.GetInfo / GetQuestObjectives / IsComplete / GetLogIndexForQuestID on Forever",
      why = "documented for Retail; Forever adds and removes APIs relative to 12.1.5 and has not been tested",
      type = "behaviour", affects = "Compat/Compat.lua (ScanQuestLog, QuestLogSize, AbandonQuestAt)",
      evidence = "/fguide debug api on the live client plus accepting and completing a quest" },
    { id = "PH-API-RAIDTARGET", area = "api", status = "placeholder",
      missing = "Whether SetRaidTarget may be called from insecure add-on code",
      why = "Retail 12.0 made SetRaidTarget secure-only; Forever is built on 12.1.5",
      type = "behaviour", affects = "Core/Marker.lua, UI/MarkerBar.lua",
      evidence = "/fguide mark skull on a target; watch for ADDON_ACTION_BLOCKED" },
    { id = "PH-API-TALENTS", area = "api", status = "blocked",
      missing = "Talent API (C_Traits / C_ClassTalents) layout for Forever trees",
      why = "no verified Forever talent data or API mapping",
      type = "api", affects = "Compat/Compat.lua (talent functions), Talents/Talents.lua, UI/TalentFrame.lua",
      evidence = "client inspection of C_Traits config/tree ids for each class" },
    { id = "PH-API-MAPIDS", area = "api", status = "placeholder",
      missing = "uiMapIDs of Forever zones (original zones are expanded; new zones exist)",
      why = "map ids cannot be taken from Retail or Classic; none are published for Forever",
      type = "integer per zone", affects = "Database/Zones (none shipped), guide z= fields, Core/Navigation.lua",
      evidence = "C_Map.GetBestMapForUnit('player') in each zone on the live client" },

    -- Ruleset ------------------------------------------------------------------------------------
    { id = "PH-RULES-LEVELCAP", area = "ruleset", status = "placeholder",
      missing = "Level cap observed in the live client",
      why = "warcraft.wiki.gg documents 60; not yet observed in a client",
      type = "integer", affects = "Config/Target.lua (maxLevel), tools/src/GuideCompiler.cs (LevelCap)",
      evidence = "GetMaxPlayerLevel() on the live client" },
    { id = "PH-RULES-QUESTLOG", area = "ruleset", status = "placeholder",
      missing = "Quest log capacity",
      why = "no documented Forever value; Retail and Classic differ",
      type = "integer", affects = "Config/Target.lua (questLogMax), tools/src/RouteAnalyzer.cs (LogCap)",
      evidence = "C_QuestLog.GetMaxNumQuestsCanAccept() on the live client" },
    { id = "PH-RULES-XPRATE", area = "ruleset", status = "placeholder",
      missing = "XP rates and per-level XP requirements",
      why = "not published", type = "number", affects = "Config/Target.lua (xpRate), level/grind steps",
      evidence = "UnitXPMax('player') per level on the live client" },
    { id = "PH-RULES-GREYRANGE", area = "ruleset", status = "placeholder",
      missing = "Level difference at which quests turn grey",
      why = "Core/Engine.lua used the TBC value 8 when GetQuestGreenRange is missing",
      type = "integer", affects = "Core/Engine.lua (IsGrey)",
      evidence = "GetQuestGreenRange() on the live client" },

    -- Races / classes ------------------------------------------------------------------------------
    { id = "PH-RACE-SKYBORNE", area = "races", status = "placeholder",
      missing = "Skyborne race file token (UnitRace 2nd return), faction handling and class list",
      why = "new race; the wiki names it and two class options only",
      type = "string + class list", affects = "Database/RaceClass.lua, tools/src/GuideCompiler.cs (race tables)",
      evidence = "UnitRace('player') and the character creation screen on the live client" },
    { id = "PH-RACECLASS-COMBOS", area = "races", status = "inherited_unverified",
      missing = "Race/class combinations for the eight original races",
      why = "copied from the 2004-era table in TBC client data minus Draenei/Blood Elf; Forever may differ",
      type = "table", affects = "Database/RaceClass.lua, tools/src/GuideCompiler.cs (RaceClasses)",
      evidence = "character creation screen on the live client" },

    -- Game data ------------------------------------------------------------------------------------
    { id = "PH-DATA-QUESTDB", area = "data", status = "blocked",
      missing = "Quest, NPC, object and item database for WoW Forever",
      why = "the TBC QuestieDB data does not describe Forever (1,000+ new quests, expanded zones); no licensed Forever source exists yet",
      type = "data set", affects = "Database/ (no data files shipped), Database/QuestDB.lua returns nil for every record",
      evidence = "a licensed Forever data source, or data collected in the live client" },
    { id = "PH-DATA-ESCORTS", area = "data", status = "placeholder",
      missing = "Escort quest ids for the never-auto-accept list",
      why = "the TBC list referred to TBC quest ids", type = "integer list",
      affects = "Database/EscortQuests.lua", evidence = "verified Forever quest data" },

    -- Guide content ----------------------------------------------------------------------------------
    { id = "PH-ROUTE-ALLIANCE-START", area = "guides", status = "placeholder",
      missing = "Alliance starting zones, first quests, NPCs and coordinates",
      why = "Forever expands the original zones; routes cannot be inherited from TBC",
      type = "guide steps", affects = "guides-src/alliance/00_start_pending.guide",
      evidence = "quest ids, NPC ids and coordinates recorded in the live client or a verified database" },
    { id = "PH-ROUTE-HORDE-START", area = "guides", status = "placeholder",
      missing = "Horde starting zones, first quests, NPCs and coordinates",
      why = "as for Alliance", type = "guide steps", affects = "guides-src/horde/00_start_pending.guide",
      evidence = "as for Alliance" },
    { id = "PH-ROUTE-SKYBORNE-START", area = "guides", status = "blocked",
      missing = "Skyborne starting experience",
      why = "depends on PH-RACE-SKYBORNE", type = "guide", affects = "guides-src/ (no file yet)",
      evidence = "PH-RACE-SKYBORNE resolved, then as for Alliance" },
    { id = "PH-ROUTE-LEVELING", area = "guides", status = "placeholder",
      missing = "Leveling zone order, level ranges and level breakpoints after the starting zones",
      why = "new zones (Mount Hyjal, Riverglades, Shen'dralas, Zephras Isle) and expanded originals; level ranges unpublished",
      type = "guide chain", affects = "guides-src/*/ (@next, @levels)", evidence = "verified zone level ranges and quest data" },
    { id = "PH-ROUTE-TRAVEL", area = "guides", status = "placeholder",
      missing = "Flight paths, boats/zeppelins and other transport",
      why = "not published for Forever", type = "guide steps", affects = "fp/fly/travel steps",
      evidence = "flight master maps on the live client" },

    -- Inherited features ---------------------------------------------------------------------------
    { id = "PH-TALENTS-SYSTEM", area = "talents", status = "blocked",
      missing = "Talent trees, point budget and builds",
      why = "TBC trees removed; fan sites describe a different trait-based system (unverified)",
      type = "data set", affects = "Talents/ (no data files shipped), UI/TalentFrame.lua",
      evidence = "client talent data for every class" },
    { id = "PH-GEAR-WEIGHTS", area = "gear", status = "inherited_unverified",
      missing = "Stat weights for WoW Forever",
      why = "Gear/Profiles.lua holds weights researched for TBC; the Forever stat system is unverified",
      type = "weight tables", affects = "Gear/Profiles.lua, UI/GearUI.lua",
      evidence = "Forever item stat formulas or published Forever theorycraft" },
    { id = "PH-CLASS-ADVICE", area = "classes", status = "inherited_unverified",
      missing = "Class leveling tips checked against Forever abilities",
      why = "Classes/ClassAdvice.lua text was written for TBC", type = "text",
      affects = "Classes/ClassAdvice.lua", evidence = "Forever trainer spell lists" },
    { id = "PH-INT-TOMTOM", area = "integrations", status = "placeholder",
      missing = "Whether a Forever build of TomTom exists and keeps TomTom.AddWaypoint",
      why = "optional integration never tested on Forever", type = "behaviour",
      affects = "Core/Navigation.lua", evidence = "load TomTom on the live client; /fguide debug api" },
    { id = "PH-PKG-CURSEFORGE", area = "packaging", status = "blocked",
      missing = "CurseForge project id for ForeverGuide",
      why = "TBCGuide's project id must not be reused", type = "integer",
      affects = ".github/workflows/curseforge.yml, ForeverGuide.toc (X-Curse-Project-ID)",
      evidence = "a new CurseForge project created by the author" },
}

ns.PlaceholderById = {}
for _, p in ipairs(ns.Placeholders) do ns.PlaceholderById[p.id] = p end

-- Label shown wherever unfinished content appears.
ns.PENDING_LABEL = "Pending WoW Forever data"
