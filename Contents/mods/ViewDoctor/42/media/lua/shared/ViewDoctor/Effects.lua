require "ViewDoctor/Games"
require "ViewDoctor/Treatments"
require "ViewDoctor/Events"
require "ViewDoctor/State"

local Effects = {}
ViewDoctor.Effects = Effects

local T = ViewDoctor.Treatments
local SYNC_ALL = 0xFFFFFFFFFFF
local COUNTS_UP = { Stitch = 50 }

Effects.BOTCH = 0.2

function Effects.painDelta(quality, botched)
    if botched then return 12 end
    return math.floor((0.6 - quality) * 20 + 0.5)
end

function Effects.grade(quality)
    if quality >= 0.85 then return "Clean" end
    if quality >= 0.55 then return "Fine" end
    if quality >= Effects.BOTCH then return "Sloppy" end
    return "Botched"
end

function Effects.healFactor(q)
    return 1.4 + (0.6 - 1.4) * q
end

function Effects.infectChance(q)
    return (1 - q) * (1 - q) * 60
end

local function option(name)
    local sv = SandboxVars.ViewDoctor
    if not sv then return true end
    return sv[name] ~= false
end

local function treat(r, e, part, q)
    if e.stems and q >= 0.55 then
        part:setBleeding(false)
        part:setBleedingTime(0)
    end
    if e.bleeds and q >= Effects.BOTCH and q < 0.55 and ZombRand(100) < 50 then
        part:setBleedingTime(math.max(part:getBleedingTime(), 2))
    end
    if e.risky and ZombRand(100) < Effects.infectChance(q) then
        part:setInfectedWound(true)
    end
    if e.cleanses and q >= 0.85 and ZombRand(100) < q * 50 then
        part:setInfectedWound(false)
        part:setWoundInfectionLevel(0)
    end
    for _, name in ipairs(e.timers) do
        local t = part["get" .. name .. "Time"](part)
        local cap = COUNTS_UP[name]
        if cap then
            if t > 0 and t < cap then part["set" .. name .. "Time"](part, math.max(t, cap - (cap - t) * Effects.healFactor(q))) end
        elseif t > 0 then
            part["set" .. name .. "Time"](part, t * Effects.healFactor(q))
        end
    end
    if e.leftover and q < 0.4 and ZombRand(100) < 50 then
        if e.leftover == "glass" then part:setHaveGlass(true) else part:setHaveBullet(true, 0) end
    end
    if e.bandage and part:bandaged() then
        part:setBandageLife(part:getBandageLife() * (0.6 + 0.6 * q))
    end
    if e.xp > 0 and q > 0.5 and r.doctor then
        pcall(addXp, r.doctor, Perks.Doctor, e.xp * (q - 0.5))
    end
end

function Effects.apply(r)
    local e = T.list[r.treatment]
    if not e or not r.patient then return false end
    if r.botched and not option("BotchPenalty") then return false end
    if not r.botched and not option("QualityEffects") then return false end
    local target = e.stump and T.stumpOf(r.part) or r.part
    local part = T.partOf(r.patient, target)
    if not part then return false end
    local q = r.quality

    part:setAdditionalPain(math.max(0, part:getAdditionalPain() + Effects.painDelta(q, r.botched)))
    if r.botched then
        if e.bleeds or e.stems then part:setBleedingTime(math.max(part:getBleedingTime(), 3)) end
    else
        treat(r, e, part, q)
        ViewDoctor.State.get(r.patient).parts[target] = { q = q, t = r.treatment }
    end
    if isServer() then
        syncBodyPart(part, SYNC_ALL)
        r.patient:transmitModData()
    end
    return true
end

ViewDoctor.onResult(Effects.apply)

function Effects.send(doctor, patient, partName, treatment, quality, botched)
    if not partName then return end
    if isClient() then
        sendClientCommand(doctor, "ViewDoctor", "result", {
            patient = patient:getOnlineID(), part = partName, effect = treatment, q = quality, botched = botched,
        })
    else
        ViewDoctor.fireResult({
            doctor = doctor, patient = patient, part = partName, treatment = treatment,
            quality = quality, grade = Effects.grade(quality), botched = botched,
        })
    end
end
