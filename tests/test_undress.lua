next = nil
package.path = arg[1] .. "/client/?.lua;" .. arg[1] .. "/shared/?.lua;" .. package.path
ViewDoctor = ViewDoctor or {}
SandboxVars = { ViewDoctor = { Undress = true } }

local function action(kind)
    return { new = function(_, character, item, time) return { kind = kind, character = character, item = item, maxTime = time or 50 } end }
end
ISUnequipAction = action("off")
ISWearClothing = action("on")

require "ViewDoctor/Undress"
local Undress = ViewDoctor.Undress

local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

local worn = {
    { item = "tshirt", covers = { Torso_Upper = true, UpperArm_L = true } },
    { item = "jacket", covers = { Torso_Upper = true, UpperArm_L = true, ForeArm_L = true } },
    { item = "trousers", covers = { UpperLeg_L = true, LowerLeg_L = true } },
    { item = "wrap", covers = { ForeArm_L = true }, bandage = true },
}
assert(same(Undress.covering(worn, "ForeArm_L"), { "jacket" }))
assert(same(Undress.covering(worn, "UpperArm_L"), { "jacket", "tshirt" }))
assert(same(Undress.covering(worn, "Head"), {}))

instanceof = function() return true end
local cap = { getCoveredParts = function() return { size = function() return 0 end } end }
local capped = { getWornItems = function()
    return { size = function() return 1 end, get = function()
        return { getItem = function() return cap end, getLocation = function() return "base:hat" end }
    end }
end }
assert(Undress.worn(capped)[1].covers.Head, "a hat with no blood location still covers the head")

local inventory = { list = {} }
function inventory:getItems()
    local list = self.list
    return { size = function() return #list end, get = function(_, i) return list[i + 1] end }
end
local onBody = {}
local player = {}
function player:getPlayerNum() return 0 end
function player:getInventory() return inventory end
function player:setWornItem(_, item) onBody[item] = true end
triggerEvent = function() end
function player:getWornItems() return { contains = function(_, item) return onBody[item] == true end } end

local function cloth(name)
    local c = { name = name, container = inventory, md = {} }
    function c:getContainer() return self.container end
    function c:getModData() return self.md end
    function c:canBeEquipped() return "" end
    function c:getBodyLocation() return name end
    inventory.list[#inventory.list + 1] = c
    onBody[c] = true
    return c
end

local tshirt, jacket, trousers = cloth("tshirt"), cloth("jacket"), cloth("trousers")
Undress.worn = function()
    local list = {}
    if onBody[tshirt] then list[#list + 1] = { item = tshirt, covers = { Torso_Upper = true, UpperArm_L = true } } end
    if onBody[jacket] then list[#list + 1] = { item = jacket, covers = { Torso_Upper = true, UpperArm_L = true, ForeArm_L = true } } end
    if onBody[trousers] then list[#list + 1] = { item = trousers, covers = { UpperLeg_L = true, LowerLeg_L = true } } end
    return list
end

local function items(actions)
    local out = {}
    for i, a in ipairs(actions) do out[i] = a.item end
    return out
end

local function strip(actions)
    for _, a in ipairs(actions) do onBody[a.item] = nil end
end

local function dress(actions)
    for _, a in ipairs(actions) do onBody[a.item] = true end
end

local off = Undress.begin(player, "UpperArm_L", 0)
assert(same(items(off), { jacket, tshirt }) and off[1].kind == "off", "outermost first")
assert(off[1].maxTime == 25 and off[1]._vdDone, "short fixed undress time, never gated")
strip(off)
assert(#Undress.begin(player, "UpperArm_L", 1) == 0, "a second treatment on the same part undresses nothing")

assert(#Undress.finish(player, "UpperArm_L", 1) == 0, "dressing waits for the queued treatment")
assert(#Undress.begin(player, "UpperArm_L", 1) == 0, "the record is kept while waiting")
local on = Undress.finish(player, "UpperArm_L", 0)
assert(same(items(on), { tshirt, jacket }) and on[1].kind == "on", "dressed in reverse order")
assert(on[1].maxTime == 25 and on[1]._vdDone, "short fixed dress time, never gated")
assert(on[1].stopOnWalk == false and on[1].stopOnRun == false and on[1].stopOnAim == false, "walking away does not stop the dressing")
dress(on)
assert(#Undress.finish(player, "UpperArm_L", 0) == 0, "the record is cleared after dressing")

off = Undress.begin(player, "UpperArm_L", 0)
strip(off)
jacket.container = {}
on = Undress.finish(player, "UpperArm_L", 0)
assert(same(items(on), { tshirt }), "a dropped item is skipped, the rest goes back on")
dress(on)
jacket.container = inventory
onBody[jacket] = true

off = Undress.begin(player, "ForeArm_L", 0)
assert(same(items(off), { jacket }))
on = Undress.finish(player, "ForeArm_L", 0)
assert(#on == 0, "an item that never came off is not worn twice")

off = Undress.begin(player, "ForeArm_L", 0)
strip(off)
local second = Undress.begin(player, "UpperArm_L", 0)
assert(same(items(second), { tshirt }), "an item already taken off for another part is not taken off twice")
strip(second)
on = Undress.finish(player, "ForeArm_L", 0)
assert(#on == 0, "the jacket stays off while the upper arm is still to be treated")
on = Undress.finish(player, "UpperArm_L", 0)
assert(same(items(on), { tshirt, jacket }), "everything returns after the last part")
dress(on)

off = Undress.begin(player, "UpperLeg_L", 0)
strip(off)
local again = Undress.begin(player, "UpperLeg_L", 0)
assert(#again == 0, "a stale record with nothing queued does not undress twice")
on = Undress.finish(player, "UpperLeg_L", 0)
assert(same(items(on), { trousers }), "items of a stale record still go back on")
dress(on)

onBody[tshirt], onBody[jacket] = nil, nil
off = Undress.begin(player, "UpperLeg_L", 0)
strip(off)
assert(#Undress.begin(player, "LowerLeg_L", 0) == 0, "trousers already off for the thigh")
assert(#Undress.finish(player, "UpperLeg_L", 0) == 0, "trousers stay off while the lower leg is still to be treated")
on = Undress.finish(player, "LowerLeg_L", 0)
assert(same(items(on), { trousers }), "trousers return after the lower leg")
dress(on)
onBody[tshirt], onBody[jacket] = true, true

local again = Undress.again(player, trousers)
assert(again == nil, "a worn item is not dressed again")
onBody[trousers] = nil
again = Undress.again(player, trousers)
assert(again and again.item == trousers and again.kind == "on" and again.stopOnWalk == false, "an item still off can be dressed again")
onBody[trousers] = true

off = Undress.begin(player, "UpperArm_L", 0)
strip(off)
Undress.records = {}
Undress.restore(player)
assert(onBody[tshirt] and onBody[jacket] and not jacket.md.ViewDoctorOff, "items still off after a reload are worn again at once")

SandboxVars.ViewDoctor.Undress = false
assert(#Undress.begin(player, "UpperArm_L", 0) == 0, "sandbox option off")
SandboxVars.ViewDoctor.Undress = true

print("undress ok")
