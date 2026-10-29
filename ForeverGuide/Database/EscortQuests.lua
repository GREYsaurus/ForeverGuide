-- ForeverGuide - escort / scripted-event quest safeguard list
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Quests that must NEVER be accepted automatically. This list is one of several independent
-- signals (see DB.GetEscortStatus); a quest is manual-only if ANY signal fires:
--   1. this list, plus the per-account list ForeverGuideDB.escortExtra (/fguide escort add <id>);
--   2. questFlags PARTY_ACCEPT (2) in the bundled QuestieDB data (cmangos marks escort-type
--      quests with it; it also covers some scripted "defend/wait" events, which stay manual too).
--      specialFlags NEEDS_EVENT is NOT used: reviewed 2026-10-28, all 67 TBC quests carrying only
--      that flag are exploration/area-trigger quests, none are escorts;
--   3. escort wording in the database objective / trigger text;
--   4. escort wording in the quest text the client shows on the offer panel;
--   5. the quest is not in the bundled database at all (status unknown).
--
-- Contents: EMPTY. TBCGuide's list named TBC quest ids, which say nothing about WoW Forever
-- (PH-DATA-ESCORTS). Until verified Forever data exists, signal 5 makes every quest manual anyway.
-- Add verified ids here, never remove.

local _, ns = ...

ns.EscortQuests = {
}
