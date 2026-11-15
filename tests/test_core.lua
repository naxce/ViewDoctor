next = nil
package.path = arg[1] .. "/client/?.lua;" .. arg[1] .. "/shared/?.lua;" .. package.path
for _, m in ipairs({ "TimedActions/ISBaseTimedAction", "TimedActions/ISTimedActionQueue", "ISUI/ISUIElement" }) do
    package.loaded[m] = true
end

local ticks = {}
Events = setmetatable({}, { __index = function(t, k)
    local e = { Add = function(f) ticks[k] = ticks[k] or {}; table.insert(ticks[k], f) end }
    rawset(t, k, e)
    return e
end })

local function derive(base, name)
    local c = { Type = name }
    c.__index = c
    return setmetatable(c, { __index = base })
end

ISBaseTimedAction = {}
ISBaseTimedAction.__index = ISBaseTimedAction
function ISBaseTimedAction:derive(name) return derive(self, name) end
function ISBaseTimedAction.new(cls, character)
    return setmetatable({ character = character, maxTime = -1, stopOnWalk = true }, cls)
end
function ISBaseTimedAction:stop() self.stopped = true end
function ISBaseTimedAction:perform() self.performed = true end
function ISBaseTimedAction:forceStop() self:stop() end
function ISBaseTimedAction:forceComplete() self:perform() end
function ISBaseTimedAction:setActionAnim(a) self.anim = a end
function ISBaseTimedAction:setAnimVariable() end
function ISBaseTimedAction:setOverrideHandModels() end

ISUIElement = { derive = function(self, name) return derive(self, name) end }

local queue = {}
ISTimedActionQueue = {
    add = function(a) table.insert(queue, a); return queue end,
    addAfter = function(prev, a)
        for i, v in ipairs(queue) do
            if v == prev then table.insert(queue, i + 1, a); return queue, a end
        end
    end,
    getTimedActionQueue = function()
        return { queue = queue, indexOf = function(_, a)
            for i, v in ipairs(queue) do if v == a then return i end end
            return -1
        end }
    end,
}

SandboxVars = { ViewDoctor = { Enabled = true, Difficulty = 2, TimeLimit = 30, QualityEffects = true, BotchPenalty = true } }
BodyPartType = { MAX = "MAX" }
function BodyPartType.FromString(s) return s end
function BodyPartType.ToString(t) return t end
function BodyPartType.getDisplayName(t) return t end
Perks = { Doctor = "Doctor" }
MoodleType = { PAIN = "PAIN" }
JoypadState = { players = {} }
CharacterActionAnims = { Bandage = "Bandage" }
Metabolics = {}
isClient = function() return false end
isServer = function() return false end
getText = function(k) return k end
getTimestampMs = function() return 0 end
roll = 99
ZombRand = function() return roll end
addXp = function(_, _, n) xpGiven = (xpGiven or 0) + n end
instanceof = function(o, cls) return cls == "IsoPlayer" and o.isPlayer end

local function newPart(name)
    local p = { name = name, pain = 10, bleed = 0, infected = false }
    function p:getType() return self.name end
    function p:getAdditionalPain() return self.pain end
    function p:setAdditionalPain(v) self.pain = v end
    function p:getBleedingTime() return self.bleed end
    function p:setBleedingTime(v) self.bleed = v end
    function p:bandaged() return false end
    function p:setInfectedWound(v) self.infected = v end
    function p:setWoundInfectionLevel(v) self.infection = v end
    function p:setBleeding(v) self.bleeding = v end
    function p:setHaveGlass(v) self.glass = v end
    function p:setHaveBullet(v) self.bullet = v end
    for _, k in ipairs({ { "DeepWound", "deep" }, { "Cut", "cut" }, { "Scratch", "scratch" }, { "Burn", "burn" }, { "Fracture", "fracture" }, { "Stitch", "stitch" } }) do
        p["get" .. k[1] .. "Time"] = function(self) return self[k[2]] or 0 end
        p["set" .. k[1] .. "Time"] = function(self, v) self[k[2]] = v end
    end
    return p
end

local parts = {}
local player = { isPlayer = true, instant = false, halo = nil }
function player:getBodyDamage() return { getBodyPart = function(_, n) parts[n] = parts[n] or newPart(n); return parts[n] end } end
function player:isLocalPlayer() return true end
function player:getPlayerNum() return 0 end
function player:isTimedActionInstant() return self.instant end
function player:getPerkLevel() return 2 end
function player:getMoodles() return { getMoodleLevel = function() return 0 end } end
function player:getUsername() return "doc" end
function player:setHaloNote(t) self.halo = t end
function player:reportEvent() end
function player:setMetabolicTarget() end
function player:faceThisObject() end
function player:SetVariable() end
function player:getModData() self.md = self.md or {}; return self.md end
local inventory, onBody = { list = {} }, {}
function inventory:getItems()
    local list = self.list
    return { size = function() return #list end, get = function(_, i) return list[i + 1] end }
end
getSpecificPlayer = function() return player end
function player:getInventory() return inventory end
function player:getWornItems() return { contains = function(_, item) return onBody[item] == true end } end
local function clothing(kind)
    return { new = function(_, character, item, time) return { Type = kind, character = character, item = item, maxTime = time or 50 } end }
end
ISUnequipAction = clothing("ISUnequipAction")
ISWearClothing = clothing("ISWearClothing")

local posed = {}
ViewDoctorPose = {
    start = function(part, left, right) posed.part, posed.left, posed.right = part, left, right; return posed.refuse ~= true end,
    stop = function() posed.stopped = true end,
    firstPerson = function() return posed.third ~= true end,
}
local propsClosed = 0
ViewDoctorProps = { close = function() propsClosed = propsClosed + 1 end }

require "ViewDoctor/Core"
ViewDoctor.Undress.worn = function() return {} end
local opened
ViewDoctor.Panel.open = function(args) opened = args; return { closed = false, close = function(s) s.closed = true end } end

local function stitch(doIt)
    local cls = { Type = "ISStitch" }
    cls.__index = cls
    function cls:perform() self.realPerformed = true end
    return setmetatable({ character = player, otherPlayer = player, bodyPart = player:getBodyDamage():getBodyPart("Hand_L"), doIt = doIt, maxTime = 200 }, cls)
end

local function runTicks() for _, f in ipairs(ticks.OnTick or {}) do f() end end

queue = {}
local real = stitch(true)
ISTimedActionQueue.add(real)
local gate = queue[1]
assert(gate.Type == "VD_GateAction" and gate.real == real and #queue == 1, "self-stitching is gated")
gate:start()
assert(opened.game == "connect" and opened.follow == true, "connect-the-dots opens on the 3D hand")
assert(posed.part == "Hand_L", "the left hand is raised into view")
assert(gate.anim == nil, "no bandaging animation covers the wound while the limb is posed")
assert(posed.left == true and posed.right == true, "both hands are offered to hold the tool")
opened.onDone(false, 0.9, { misses = 0 })
assert(queue[2] == real and real._vdDone and real.maxTime == 1, "stitch queued after the game with no wait")
assert(gate.performed and posed.stopped, "gate done, arm lowered")
assert(player.halo == "IGUI_VD_Grade_Clean", "clean work announced")
ISTimedActionQueue.add(real)
assert(queue[3] == real, "an already played action is not gated twice")
real:perform()
runTicks()
assert(real.realPerformed and parts.Hand_L.pain == 4, "clean stitching takes pain away after the stitch is done")

queue = {}
parts.Hand_L = nil
ISTimedActionQueue.add(stitch(true))
gate = queue[1]
gate:start()
opened.onDone(false, 0.05, { misses = 5 })
assert(gate.stopped and #queue == 1, "botched: no stitch queued")
assert(parts.Hand_L.pain == 22 and parts.Hand_L.bleed == 3, "botching hurts and bleeds")

queue = {}
parts.Hand_L = nil
ISTimedActionQueue.add(stitch(true))
gate = queue[1]
gate:start()
opened.onDone(true, 0.5, {})
assert(gate.stopped and #queue == 1 and parts.Hand_L.pain == 10, "cancelled: nothing happens")

queue = {}
local handed
EHR = { StitchMinigame = { CreateVanillaAction = function(c, o, i, bp, q, misses)
    handed = { q = q, misses = misses }
    return { character = c, maxTime = 150 }
end } }
local ehrGate = setmetatable({ character = player, otherPlayer = player, bodyPart = player:getBodyDamage():getBodyPart("ForeArm_R"), item = {} },
    { __index = { Type = "EHR_StitchMinigameAction" } })
ISTimedActionQueue.add(ehrGate)
gate = queue[1]
gate:start()
assert(posed.part == "ForeArm_R", "right forearm raised")
opened.onDone(false, 0.7, { misses = 2 })
assert(handed.q == 0.7 and handed.misses == 2 and queue[2].maxTime == 1, "EHR gets our quality and its own stitch")

queue = {}
player.instant = true
ISTimedActionQueue.add(stitch(true))
assert(queue[1].Type == "ISStitch", "instant actions are left alone")
player.instant = false
JoypadState.players[1] = {}
ISTimedActionQueue.add(stitch(true))
assert(queue[2].Type == "ISStitch", "controller players are left alone")
JoypadState.players[1] = nil
SandboxVars.ViewDoctor.Enabled = false
ISTimedActionQueue.add(stitch(true))
assert(queue[3].Type == "ISStitch", "sandbox switch turns it off")
SandboxVars.ViewDoctor.Enabled = true
local pill = setmetatable({ character = player, adminType = "pill" }, { __index = { Type = "EHRMedicationAction" } })
ISTimedActionQueue.add(pill)
assert(queue[4] == pill, "swallowing a pill is not a minigame")
local shot = setmetatable({ character = player, adminType = "injection" }, { __index = { Type = "EHRMedicationAction" } })
ISTimedActionQueue.add(shot)
assert(queue[5].Type == "VD_GateAction" and queue[5].info.game == "inject", "an injection is")

queue = {}
local panelAction = { Type = "HealthPanelAction", character = player }
ISTimedActionQueue.add(panelAction)
local viaPanel = stitch(true)
ISTimedActionQueue.addAfter(panelAction, viaPanel)
assert(queue[2].Type == "VD_GateAction" and queue[2].real == viaPanel, "the health panel queues with addAfter and is gated")
local follow = { Type = "ISInventoryTransferAction", character = player }
ISTimedActionQueue.addAfter(viaPanel, follow)
assert(queue[3] == follow, "chaining after a gated action lands after its gate")

local T = ViewDoctor.Treatments
assert(T.list.glass.leftover == "glass" and T.list.glass.game == "extract", "registry holds glass")
assert(T.resolve(stitch(false)).effect == "unstitch", "stitch removal resolves from the registry")
local seen
ViewDoctor.onResult(function(r) seen = r end)
ViewDoctor.fireResult({ treatment = "stitch", quality = 0.9, grade = "Clean", botched = false })
assert(seen and seen.grade == "Clean", "result event reaches subscribers")
local store = ViewDoctor.State.get(player)
assert(store.v == 1 and type(store.parts) == "table", "state store is versioned")

local Effects = ViewDoctor.Effects
assert(math.abs(Effects.healFactor(1) - 0.6) < 1e-6 and math.abs(Effects.healFactor(0) - 1.4) < 1e-6, "heal factor ends")
assert(math.abs(Effects.infectChance(0.5) - 15) < 1e-6, "infection chance shape")
local hand = newPart("Hand_L"); parts.Hand_L = hand; hand.deep = 10; hand.bleeding = true; hand.bleed = 5; hand.stitch = 1
roll = 99
ViewDoctor.fireResult({ doctor = player, patient = player, part = "Hand_L", treatment = "stitch", quality = 0.9, grade = "Clean", botched = false })
assert(math.abs(hand.deep - 10 * Effects.healFactor(0.9)) < 1e-4 and hand.bleeding == false and hand.bleed == 0, "clean stitch heals faster and stops bleeding")
assert(xpGiven and xpGiven > 0, "clean work gives bonus XP")
assert(math.abs(hand.stitch - (50 - 49 * Effects.healFactor(0.9))) < 1e-4, "clean stitches close sooner")
hand.stitch = 1
ViewDoctor.fireResult({ doctor = player, patient = player, part = "Hand_L", treatment = "stitch", quality = 0.3, grade = "Sloppy", botched = false })
assert(hand.stitch == 1, "sloppy stitches keep a running stitch timer")
local leg = newPart("UpperLeg_L"); parts.UpperLeg_L = leg
roll = 0
ViewDoctor.fireResult({ doctor = player, patient = player, part = "UpperLeg_L", treatment = "glass", quality = 0.3, grade = "Sloppy", botched = false })
assert(leg.glass == true and leg.infected == true, "sloppy glass removal leaves a shard and infects")
local fore = newPart("ForeArm_R"); parts.ForeArm_R = fore; fore.deep = 20
package.loaded["TOC/StaticData"] = { LIMBS_ADJACENT_IND_STR = { Hand_R = "ForeArm_R" } }
roll = 99
ViewDoctor.fireResult({ doctor = player, patient = player, part = "Hand_R", treatment = "amputate", quality = 1, grade = "Clean", botched = false })
assert(math.abs(fore.deep - 12) < 1e-4, "amputation quality lands on TOC's stump part")
assert(ViewDoctor.State.get(player).parts.ForeArm_R.q == 1, "last quality is stored per part")
local cau = setmetatable({ character = player, limbName = "Hand_R" }, { __index = { Type = "CauterizeAction" } })
local ci = T.resolve(cau)
assert(ci.part == "Hand_R" and ci.view == "ForeArm_R", "cauterizing targets the cut limb and shows the stump")
queue = {}
ISTimedActionQueue.add(cau)
queue[1]:start()
assert(posed.part == "ForeArm_R" and opened.part == "ForeArm_R", "the stump is raised for cauterizing")

queue = {}
local cut = setmetatable({ character = player, patient = player, limbName = "Hand_L", maxTime = 300 }, { __index = {
    Type = "CutLimbAction",
    start = function(self)
        local st = stitch(true)
        st.bodyPart = player:getBodyDamage():getBodyPart("ForeArm_L")
        ISTimedActionQueue.addAfter(self, st)
    end,
} })
ISTimedActionQueue.add(cut)
gate = queue[1]
assert(gate.Type == "VD_GateAction" and gate.info.game == "saw" and gate.info.part == "Hand_L", "amputation is the saw game on the hand")
gate:start()
opened.onDone(false, 0.9, {})
assert(queue[2] == cut and cut.maxTime == 1, "amputation finishes at once after the saw")
cut:start()
local stitchGate = queue[3]
assert(stitchGate.Type == "VD_GateAction" and stitchGate.info.effect == "stitch" and stitchGate.info.part == "ForeArm_L", "TOC's stump stitch is a minigame too")
parts.ForeArm_L = newPart("ForeArm_L"); parts.ForeArm_L.deep = 10
stitchGate:start()
opened.onDone(false, 1, {})
stitchGate.real:perform()
runTicks()
assert(math.abs(parts.ForeArm_L.deep - 6) < 1e-4, "the stump stitch applies its own quality to the stump")

local trousers = { getContainer = function() return inventory end, md = {} }
function trousers:getModData() return self.md end
function trousers:canBeEquipped() return "" end
function trousers:getBodyLocation() return "base:pants" end
function player:setWornItem(_, item) onBody[item] = true end
triggerEvent = triggerEvent or function() end
inventory.list[1] = trousers
onBody[trousers] = true
ViewDoctor.Undress.worn = function()
    if not onBody[trousers] then return {} end
    return { { item = trousers, covers = { UpperLeg_L = true, LowerLeg_L = true } } }
end
local function types()
    local out = {}
    for i, a in ipairs(queue) do out[i] = a.Type end
    return table.concat(out, ",")
end
local function onLeg(cls)
    local a = stitch(true)
    a.bodyPart = player:getBodyDamage():getBodyPart("UpperLeg_L")
    if cls then setmetatable(a, { __index = { Type = cls, perform = function(self) self.realPerformed = true end } }) end
    return a
end
queue = {}
ISTimedActionQueue.add(onLeg())
ISTimedActionQueue.add(onLeg("ISApplyBandage"))
assert(types() == "ISUnequipAction,VD_GateAction,VD_GateAction", "one undress before two treatments on the thigh: " .. types())
assert(queue[1].item == trousers and queue[1]._vdDone, "the trousers come off first")
onBody[trousers] = nil
queue[2]:start()
opened.onDone(false, 0.9, { misses = 0 })
assert(types() == "ISUnequipAction,VD_GateAction,ISStitch,VD_GateAction", "no dressing while the bandage is still queued: " .. types())
table.remove(queue, 1)
table.remove(queue, 1)
table.remove(queue, 1)
queue[1]:start()
opened.onDone(false, 0.9, { misses = 0 })
assert(types() == "VD_GateAction,ISApplyBandage,ISWearClothing", "one dress after the last treatment: " .. types())
assert(queue[3].item == trousers, "the trousers go back on")
onBody[trousers] = true

queue = {}
ISTimedActionQueue.add(onLeg())
onBody[trousers] = nil
queue[2]:start()
queue = { queue[2] }
opened.onDone(true, 0.5, {})
queue = {}
runTicks()
assert(types() == "ISWearClothing" and queue[1].item == trousers, "cancelling puts the trousers back on: " .. types())
onBody[trousers] = true

queue = {}
ISTimedActionQueue.add(onLeg())
onBody[trousers] = nil
queue[1]:forceCancel()
queue = {}
runTicks()
assert(types() == "ISWearClothing", "an undress wiped from the queue still gets its clothes back: " .. types())
onBody[trousers] = true

queue = {}
ISTimedActionQueue.add(onLeg())
onBody[trousers] = nil
queue[2]:start()
opened.onDone(false, 0.9, { misses = 0 })
assert(types() == "ISUnequipAction,VD_GateAction,ISStitch,ISWearClothing", "dress queued behind the stitch: " .. types())
local wear = queue[4]
queue = {}
wear:forceCancel()
runTicks()
assert(types() == "ISWearClothing" and queue[1].item == trousers, "a dress wiped with the queue is queued again: " .. types())
for _ = 1, 5 do
    local w = queue[1]
    queue = {}
    if w then w:forceCancel() end
    runTicks()
end
assert(#queue == 0, "but not forever")
onBody[trousers] = true

queue = {}
posed.third = true
ISTimedActionQueue.add(stitch(true))
queue[#queue]:start()
assert(queue[#queue].anim == "Bandage" and opened.follow == true, "outside first person the bandaging animation still plays")
posed.third = nil

posed.stopped = nil
propsClosed = 0
onBody[trousers] = nil
trousers.md.ViewDoctorOff = true
queue = {}
for _, f in ipairs(ticks.OnGameStart or {}) do f() end
assert(posed.stopped and propsClosed == 1, "a new game starts with no pose and no props left over")
assert(#queue == 0 and onBody[trousers] and not trousers.md.ViewDoctorOff, "clothing left off by a quit mid-treatment is worn again at load, with no timed action")

queue = {}
local other = { isPlayer = true }
setmetatable(other, { __index = player })
local onOther = onLeg()
onOther.otherPlayer = other
onOther.bodyPart = { getType = function() return "UpperLeg_L" end }
ISTimedActionQueue.add(onOther)
assert(types() == "VD_GateAction", "treating someone else strips nobody: " .. types())

queue = {}
posed.refuse = true
ISTimedActionQueue.add(stitch(true))
queue[1]:start()
assert(queue[1].anim == "Bandage" and opened.follow == false, "without a pose the vanilla bandaging animation plays")
posed.refuse = nil
package.loaded["TOC/Controllers/DataController"] = { GetInstance = function()
    return { getIsCut = function(_, limb) return limb == "Hand_R" end, getIsProstEquipped = function() return false end }
end }
queue = {}
ISTimedActionQueue.add(onLeg())
queue[#queue]:start()
assert(posed.left == true and posed.right == false, "a cut right hand is not offered")
package.loaded["TOC/Controllers/DataController"] = nil

print("core ok")
