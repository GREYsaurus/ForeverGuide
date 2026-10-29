-- ForeverGuide - guide registry
-- Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
-- This program is free software: you can redistribute it and/or modify it under the terms of the
-- GNU General Public License as published by the Free Software Foundation, version 3.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
-- even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details. The complete license text is in LICENSE.
--
-- Compiled guide files (Guides/Compiled/*.lua, generated from guides-src/*.guide) call
-- ns.Guides:Register{...}. A malformed guide is reported and skipped; it never breaks loading.

local _, ns = ...

local Guides = { list = {}, byId = {}, rejected = {} }
ns.Guides = Guides

local VALID_STEP = {
    accept = true, turnin = true, complete = true, ["goto"] = true, note = true, train = true,
    fp = true, fly = true, hs = true, bind = true, level = true, travel = true, guide = true,
    talk = true, buy = true, use = true, collect = true, grind = true,
    pending = true, -- ForeverGuide: a step whose content is not known yet (always placeholder/blocked)
}

-- Content status (docs/GUIDE_FORMAT.md). Only "verified" steps may complete automatically or drive
-- quest automation, waypoints and raid markers; inherited_unverified steps need a manual click;
-- placeholder/blocked steps can never be completed, only deferred.
local STATUS = { verified = true, inherited_unverified = true, placeholder = true, blocked = true }
Guides.STATUS = STATUS
local QUEST_STEP = { accept = true, turnin = true, complete = true }
-- Fields that would reach game APIs (quest flags, map positions, raid markers). A placeholder step must
-- not carry any of them, so unresolved content cannot cause API calls, waypoints or quest matches.
local LIVE_FIELDS = { "q", "obj", "z", "x", "y", "mark", "level" }

local function reject(id, why)
    Guides.rejected[#Guides.rejected + 1] = tostring(id) .. ": " .. why
    if ns.Error then ns:Error("guide rejected " .. tostring(id) .. ": " .. why) end
end

local function positiveInt(v) return type(v) == "number" and v > 0 and v == math.floor(v) end

-- Returns an error string for a malformed step, or nil.
local function checkStep(g, s, i, seen)
    if type(s) ~= "table" or not VALID_STEP[s[1]] then return "bad step " .. i end
    if type(s.sid) ~= "string" or s.sid == "" then return "step " .. i .. " has no stable id (sid)" end
    if seen[s.sid] then return "duplicate step id " .. s.sid end
    seen[s.sid] = true
    s.status = s.status or g.status
    if not STATUS[s.status] then return "step " .. s.sid .. " has bad status " .. tostring(s.status) end
    if s.rev ~= nil and not positiveInt(s.rev) then return "step " .. s.sid .. " has bad rev" end
    if s.ph ~= nil and not (ns.PlaceholderById and ns.PlaceholderById[s.ph]) then
        return "step " .. s.sid .. " references unknown placeholder " .. tostring(s.ph)
    end
    if s.status == "placeholder" or s.status == "blocked" then
        if not s.ph then return "placeholder step " .. s.sid .. " must name its placeholder (ph)" end
        for _, k in ipairs(LIVE_FIELDS) do
            if s[k] ~= nil then return "placeholder step " .. s.sid .. " must not set " .. k end
        end
        return nil
    end
    if s[1] == "pending" then return "pending step " .. s.sid .. " must have status placeholder or blocked" end
    if QUEST_STEP[s[1]] and not positiveInt(s.q) then return "step " .. s.sid .. " needs a quest id" end
    if s.x ~= nil or s.y ~= nil or s.z ~= nil then
        -- 0,0 is never a valid "unknown" position: leave the fields out instead.
        if not positiveInt(s.z) or type(s.x) ~= "number" or type(s.y) ~= "number"
            or s.x <= 0 or s.y <= 0 or s.x > 100 or s.y > 100 then
            return "step " .. s.sid .. " has an invalid position"
        end
    end
    -- A grind step without a target level would count as done at once.
    if s[1] == "grind" and type(s.level) ~= "number" then return "grind step " .. s.sid .. " needs a level" end
    if s[1] == "level" and type(s.level) ~= "number" then return "level step " .. s.sid .. " needs a level" end
    return nil
end

function Guides:Register(g)
    if type(g) ~= "table" or type(g.id) ~= "string" then return reject(g and g.id, "missing id") end
    if self.byId[g.id] then return reject(g.id, "duplicate id") end
    if g.faction ~= "Alliance" and g.faction ~= "Horde" and g.faction ~= "Both" then return reject(g.id, "bad faction") end
    if type(g.steps) ~= "table" or #g.steps == 0 then return reject(g.id, "no steps") end
    g.status = g.status or "verified"
    if not STATUS[g.status] then return reject(g.id, "bad status " .. tostring(g.status)) end
    local seen = {}
    for i, s in ipairs(g.steps) do
        local err = checkStep(g, s, i, seen)
        if err then return reject(g.id, err) end
        s.index = i
    end
    -- Unknown level range (placeholder guides): shown as pending, matched for any level.
    g.levelsKnown = g.minLevel ~= nil and g.maxLevel ~= nil
    g.minLevel = g.minLevel or 1
    g.maxLevel = g.maxLevel or ns.Target.maxLevel or g.minLevel
    self.byId[g.id] = g
    self.list[#self.list + 1] = g
    g.order = #self.list
end

function Guides:Get(id) return id and self.byId[id] end

-- True when the step's data is verified for WoW Forever, so game signals may complete it.
function Guides:IsTrusted(s) return s ~= nil and s.status == "verified" end

-- True when the step has no usable content yet (shown as "Pending WoW Forever data").
function Guides:IsPending(s) return s ~= nil and (s.status == "placeholder" or s.status == "blocked") end

-- True when every step of the guide is pending.
function Guides:IsPlaceholderOnly(g)
    for _, s in ipairs(g.steps) do if not self:IsPending(s) then return false end end
    return true
end

-- Does guide `g` apply to a character (race/class/faction)?
function Guides:AppliesTo(g, info)
    if g.faction ~= "Both" and info.faction and g.faction ~= info.faction then return false end
    if g.races and info.race and not ns.Contains(g.races, info.race) then return false end
    if g.classes and info.class and not ns.Contains(g.classes, info.class) then return false end
    return true
end

-- Does step `s` apply to a character?
function Guides:StepApplies(s, info)
    if s.races and info.race and not ns.Contains(s.races, info.race) then return false end
    if s.classes and info.class and not ns.Contains(s.classes, info.class) then return false end
    if s.faction and info.faction and s.faction ~= info.faction then return false end
    return true
end

-- Resolves the next guide in the route for a character (first matching `next` entry).
function Guides:NextFor(g, info)
    if not g or not g.next then return nil end
    for _, n in ipairs(g.next) do
        local ok = true
        if n.races and not ns.Contains(n.races, info.race) then ok = false end
        if n.classes and not ns.Contains(n.classes, info.class) then ok = false end
        if n.faction and n.faction ~= info.faction then ok = false end
        if ok and self.byId[n.id] then return self.byId[n.id] end
    end
end

-- Filtered, sorted list for the browser.
function Guides:Filter(f)
    local out = {}
    for _, g in ipairs(self.list) do
        local ok = true
        if f.faction and g.faction ~= "Both" and g.faction ~= f.faction then ok = false end
        if ok and f.race and g.races and not ns.Contains(g.races, f.race) then ok = false end
        if ok and f.class and g.classes and not ns.Contains(g.classes, f.class) then ok = false end
        if ok and f.chapter and g.chapter ~= f.chapter then ok = false end
        if ok and f.level and (f.level < g.minLevel - 2 or f.level > g.maxLevel + 1) then ok = false end
        if ok and f.text and f.text ~= "" then
            local t = string.lower(f.text)
            if not (string.find(string.lower(g.name), t, 1, true) or string.find(string.lower(g.zoneName or ""), t, 1, true)) then ok = false end
        end
        if ok then out[#out + 1] = g end
    end
    table.sort(out, function(a, b)
        if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
        return a.order < b.order
    end)
    return out
end
