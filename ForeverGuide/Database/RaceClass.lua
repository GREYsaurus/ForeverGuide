-- ForeverGuide - playable race/class combinations
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- SPDX-License-Identifier: GPL-3.0-only
--
-- status = "inherited_unverified" (PH-RACECLASS-COMBOS): the eight original races with the class lists
-- TBCGuide read from client CharBaseInfo (build 2.5.6.70577), minus Draenei and Blood Elf, which
-- warcraft.wiki.gg says are not playable in WoW Forever. Nobody has checked the Forever character
-- creation screen yet. The new Skyborne race is NOT listed: its race file token and class list are
-- unknown (PH-RACE-SKYBORNE). Characters of unlisted races still work; they just get no race-specific
-- start guide. Keep tools/src/GuideCompiler.cs (RaceClasses) in sync.
local _, ns = ...
ns.RaceClass = {
  status = "inherited_unverified",
  build = nil,
  races = {
    Human = {id=1,faction="Alliance",name="Human",classes={"WARRIOR","PALADIN","ROGUE","PRIEST","MAGE","WARLOCK"}},
    Orc = {id=2,faction="Horde",name="Orc",classes={"WARRIOR","HUNTER","ROGUE","SHAMAN","WARLOCK"}},
    Dwarf = {id=3,faction="Alliance",name="Dwarf",classes={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST"}},
    NightElf = {id=4,faction="Alliance",name="Night Elf",classes={"WARRIOR","HUNTER","ROGUE","PRIEST","DRUID"}},
    Scourge = {id=5,faction="Horde",name="Undead",classes={"WARRIOR","ROGUE","PRIEST","MAGE","WARLOCK"}},
    Tauren = {id=6,faction="Horde",name="Tauren",classes={"WARRIOR","HUNTER","SHAMAN","DRUID"}},
    Gnome = {id=7,faction="Alliance",name="Gnome",classes={"WARRIOR","ROGUE","MAGE","WARLOCK"}},
    Troll = {id=8,faction="Horde",name="Troll",classes={"WARRIOR","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE"}},
  },
}
