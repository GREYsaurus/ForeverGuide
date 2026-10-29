-- ForeverGuide - compiled guide data. GENERATED from guides-src/alliance/00_start_pending.guide by tools/build.ps1 guides.
-- DO NOT EDIT: edit the .guide source and rebuild. Guide routes and notes are original ForeverGuide content
-- (GPL-3.0-only). Quest ids, NPC names and coordinates may only come from verified WoW Forever data.
local _, ns = ...
ns.Guides:Register({
  id="A_Start_Pending", name="Alliance starting zones", faction="Alliance", chapter="Azeroth", status="placeholder",
  minLevel=nil, maxLevel=nil, zone=nil, zoneName=nil, start=true, races={"Human","Dwarf","NightElf","Gnome"},
  desc="Starting zones for Human, Dwarf, Night Elf and Gnome characters. The route will be written from verified WoW Forever quest data after launch; until then each step is marked as pending.",
  next={},
  steps={
    {"pending",sid="a.start.route",status="placeholder",ph="PH-ROUTE-ALLIANCE-START",text="Starting zone, first quest giver and opening quests for your race",v=0},
    {"pending",sid="a.start.trainer",status="placeholder",ph="PH-ROUTE-ALLIANCE-START",text="Class trainer and level-up training in the starting area",v=0},
    {"pending",sid="a.start.travel",status="placeholder",ph="PH-ROUTE-TRAVEL",text="Hearthstone bind, flight path and the way out of the starting area",v=0},
    {"pending",sid="a.start.next",status="placeholder",ph="PH-ROUTE-LEVELING",text="Next leveling zone and its level range",v=0},
  },
})
