ViewDoctor = ViewDoctor or {}

local Undress = {}
ViewDoctor.Undress = Undress

Undress.TIME = 25
Undress.records = {}

local SKIP = { "bandage", "wound", "zeddmg" }
local PLACE = { ["base:hat"] = "Head", ["base:neck"] = "Neck" }

function Undress.covering(worn, part)
    local out = {}
    for i = #worn, 1, -1 do
        local w = worn[i]
        if not w.bandage and w.covers[part] then out[#out + 1] = w.item end
    end
    return out
end

function Undress.worn(player)
    local list = {}
    local items = player:getWornItems()
    for i = 0, items:size() - 1 do
        local entry = items:get(i)
        local item = entry:getItem()
        local where = string.lower(tostring(entry:getLocation()))
        local bandage = false
        for _, word in ipairs(SKIP) do
            if where:find(word, 1, true) then bandage = true end
        end
        local covers = {}
        local count = 0
        if instanceof(item, "Clothing") then
            local parts = item:getCoveredParts()
            count = parts:size()
            for j = 0, count - 1 do covers[tostring(parts:get(j))] = true end
        end
        if count == 0 and PLACE[where] then covers[PLACE[where]] = true end
        list[#list + 1] = { item = item, covers = covers, bandage = bandage }
    end
    return list
end

local function recordsOf(player)
    local key = player:getPlayerNum()
    local r = Undress.records[key]
    if not r then
        r = {}
        Undress.records[key] = r
    end
    return r
end

local function taken(records, item)
    for _, list in pairs(records) do
        for _, e in ipairs(list) do
            if e.item == item then return true end
        end
    end
    return false
end

local function isWorn(player, item)
    return player:getWornItems():contains(item) == true
end

local function held(player, item)
    return item:getContainer() == player:getInventory()
end

local function wear(player, item)
    local a = ISWearClothing:new(player, item)
    a.maxTime = Undress.TIME
    a.stopOnWalk = false
    a.stopOnRun = false
    a.stopOnAim = false
    a._vdDone = true
    return a
end

function Undress.again(player, item)
    item:getModData().ViewDoctorOff = nil
    if not held(player, item) or isWorn(player, item) then return nil end
    return wear(player, item)
end

function Undress.begin(player, part, queued)
    local sv = SandboxVars.ViewDoctor
    if sv and sv.Undress == false then return {} end
    local records = recordsOf(player)
    local list = records[part]
    if list and (queued or 0) > 0 then return {} end
    list = list or {}
    records[part] = list
    local actions = {}
    local worn = Undress.worn(player)
    for i = #worn, 1, -1 do
        local w = worn[i]
        if not w.bandage and w.covers[part] and not taken(records, w.item) then
            list[#list + 1] = { item = w.item, covers = w.covers }
            w.item:getModData().ViewDoctorOff = true
        end
    end
    local shared = false
    for name, other in pairs(records) do
        if name ~= part then
            for _, e in ipairs(other) do
                if e.covers[part] then shared = true end
            end
        end
    end
    for _, e in ipairs(list) do
        if isWorn(player, e.item) then
            local a = ISUnequipAction:new(player, e.item, Undress.TIME)
            a._vdDone = true
            actions[#actions + 1] = a
        end
    end
    if #list == 0 and not shared then records[part] = nil end
    return actions
end

function Undress.finish(player, part, queued)
    local records = recordsOf(player)
    local list = records[part]
    if not list or (queued or 0) > 0 then return {} end
    records[part] = nil
    local actions = {}
    for i = #list, 1, -1 do
        local e = list[i]
        local other
        for name, waiting in pairs(records) do
            if e.covers[name] then other = waiting end
        end
        if other then
            table.insert(other, 1, e)
        else
            actions[#actions + 1] = Undress.again(player, e.item)
        end
    end
    return actions
end

function Undress.restore(player)
    local items = player:getInventory():getItems()
    local dressed = false
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getModData().ViewDoctorOff and Undress.again(player, item) then
            local spot = item:canBeEquipped()
            player:setWornItem(spot ~= nil and spot ~= "" and spot or item:getBodyLocation(), item)
            dressed = true
        end
    end
    if dressed then triggerEvent("OnClothingUpdated", player) end
end

function Undress.clear(player)
    Undress.records[player:getPlayerNum()] = nil
end

return Undress
