require "ViewDoctor/Games"

local T = {}
ViewDoctor.Treatments = T

local clamp = ViewDoctor.Games.clamp

local function nameOf(bodyPart)
    if not bodyPart then return nil end
    return BodyPartType.ToString(bodyPart:getType())
end

local function partOf(patient, name)
    if not patient or not name then return nil end
    local bpt = BodyPartType.FromString(name)
    if not bpt or bpt == BodyPartType.MAX then return nil end
    return patient:getBodyDamage():getBodyPart(bpt)
end

local function entry(game, opts, flags)
    local e = { game = game, opts = opts or {}, timers = {}, xp = 0 }
    for k, v in pairs(flags or {}) do e[k] = v end
    return e
end

T.list = {
    stitch = entry("connect", nil, { stems = true, bleeds = true, risky = true, timers = { "DeepWound", "Stitch" }, xp = 15 }),
    unstitch = entry("snip"),
    bandage = entry("wrap", nil, { stems = true, bandage = true, timers = { "Scratch", "Cut" }, xp = 5 }),
    unbandage = entry("wrap", { reverse = true, passes = 3 }),
    splint = entry("wrap", { passes = 3, board = true }, { timers = { "Fracture" }, xp = 5 }),
    unsplint = entry("wrap", { reverse = true, passes = 2, board = true }),
    disinfect = entry("scrub", nil, { risky = true, cleanses = true, xp = 5 }),
    cleanburn = entry("scrub", { gentle = true }, { timers = { "Burn" }, xp = 5 }),
    poultice = entry("scrub", { gentle = true }, { timers = { "Scratch", "Cut" }, xp = 5 }),
    glass = entry("extract", nil, { bleeds = true, risky = true, timers = { "DeepWound" }, leftover = "glass", xp = 15 }),
    bullet = entry("extract", { bullet = true }, { bleeds = true, risky = true, timers = { "DeepWound" }, leftover = "bullet", xp = 15 }),
    transfusion = entry("inject", nil, { bleeds = true }),
    drawblood = entry("inject", nil, { bleeds = true }),
    inject = entry("inject", nil, { bleeds = true }),
    amputate = entry("saw", nil, { anim = "SawLog", stump = true, stems = true, bleeds = true, risky = true, timers = { "DeepWound" } }),
    cauterize = entry("hold", nil, { stump = true, onStump = true, stems = true }),
    cleanwound = entry("scrub", nil, { stump = true, onStump = true, risky = true, cleanses = true, timers = { "DeepWound" } }),
}

local NEEDLE = { iv = true, injection = true, emergency = true }

local function needleSite(a) return a.adminType == "emergency" and "UpperLeg_L" or "ForeArm_L" end

T.actions = {
    ISStitch = function(a) return a.doIt and "stitch" or "unstitch", a.otherPlayer, a.bodyPart end,
    ISApplyBandage = function(a) return a.doIt and "bandage" or "unbandage", a.otherPlayer, a.bodyPart end,
    ISSplint = function(a) return a.doIt and "splint" or "unsplint", a.otherPlayer, a.bodyPart end,
    ISDisinfect = function(a) return "disinfect", a.otherPlayer, a.bodyPart end,
    ISCleanBurn = function(a) return "cleanburn", a.otherPlayer, a.bodyPart end,
    ISComfreyCataplasm = function(a) return "poultice", a.otherPlayer, a.bodyPart end,
    ISPlantainCataplasm = function(a) return "poultice", a.otherPlayer, a.bodyPart end,
    ISRemoveGlass = function(a) return "glass", a.otherPlayer, a.bodyPart end,
    ISRemoveBullet = function(a) return "bullet", a.otherPlayer, a.bodyPart end,

    EHR_StitchMinigameAction = function(a) return "stitch", a.otherPlayer, a.bodyPart end,
    EHR_ApplyBandagePackAction = function(a) return "bandage", a.otherPlayer, a.bodyPart end,
    EHRTransfusionAction = function(a) return "transfusion", a.character, "ForeArm_L" end,
    EHRDrawBloodAction = function(a) return "drawblood", a.character, "ForeArm_L" end,
    EHRMedicationAction = function(a)
        if not NEEDLE[a.adminType] then return nil end
        return "inject", a.character, needleSite(a)
    end,
    EHR_AdministerMedicationAction = function(a)
        if not NEEDLE[a.adminType] then return nil end
        return "inject", a.patient, needleSite(a)
    end,

    CutLimbAction = function(a) return "amputate", a.patient, a.limbName end,
    CauterizeAction = function(a) return "cauterize", a.character, a.limbName end,
    CleanWoundAction = function(a) return "cleanwound", a.patient, a.bodyPart end,
}

function T.resolve(action)
    local find = T.actions[action.Type]
    if not find then return nil end
    local id, patient, where = find(action)
    local e = id and T.list[id]
    if not e then return nil end
    local bodyPart, part = where, nil
    if type(where) == "string" then
        part, bodyPart = where, partOf(patient, where)
    else
        part = nameOf(where)
    end
    return {
        effect = id, game = e.game, opts = e.opts, anim = e.anim, patient = patient, part = part, bodyPart = bodyPart,
        view = e.onStump and T.stumpOf(part) or part,
        ehr = action.Type == "EHR_StitchMinigameAction" or nil,
    }
end

function T.stumpOf(name)
    local ok, data = pcall(require, "TOC/StaticData")
    local map = ok and type(data) == "table" and data.LIMBS_ADJACENT_IND_STR
    return map and map[name] or name
end

local function tocData(player)
    local ok, DataController = pcall(require, "TOC/Controllers/DataController")
    if not ok or type(DataController) ~= "table" or not DataController.GetInstance then return nil end
    local okInst, dc = pcall(DataController.GetInstance, player:getUsername())
    if okInst then return dc end
    return nil
end

local function handGone(dc, limb)
    local ok, gone = pcall(function() return dc:getIsCut(limb) and not dc:getIsProstEquipped(limb) end)
    return ok and gone == true
end

function T.oneHanded(doctor, part)
    local dc = tocData(doctor)
    if not dc then return false end
    local side = part and part:sub(-2)
    if side == "_L" then return handGone(dc, "Hand_R") end
    if side == "_R" then return handGone(dc, "Hand_L") end
    return handGone(dc, "Hand_L") or handGone(dc, "Hand_R")
end

function T.hands(doctor)
    local dc = tocData(doctor)
    if not dc then return true, true end
    return not handGone(dc, "Hand_L"), not handGone(dc, "Hand_R")
end

local DIFFICULTY = { 0.25, 0.55, 0.85 }

function T.difficulty(doctor, oneHanded)
    local sv = SandboxVars.ViewDoctor or {}
    local level = doctor:getPerkLevel(Perks.Doctor)
    local d = (DIFFICULTY[sv.Difficulty or 2] or 0.45) + 0.25 - level * 0.05
    if oneHanded then d = d + 0.15 end
    return clamp(d, 0, 1)
end

local SHAKY = { "PAIN", "PANIC", "DRUNK", "ENDURANCE", "HYPOTHERMIA", "TIRED" }
local WEIGHT = { PAIN = 1, PANIC = 1.2, DRUNK = 1.5, ENDURANCE = 0.5, HYPOTHERMIA = 0.8, TIRED = 0.3 }

function T.tremor(doctor, oneHanded)
    local moodles = doctor:getMoodles()
    local shake = 0
    for _, name in ipairs(SHAKY) do
        local mt = MoodleType[name]
        if mt then
            local ok, level = pcall(function() return moodles:getMoodleLevel(mt) end)
            if ok and level then shake = shake + level * WEIGHT[name] end
        end
    end
    local amp = 0.003 + 0.0025 * shake
    if oneHanded then amp = amp * 1.6 end
    return amp * (1 - doctor:getPerkLevel(Perks.Doctor) * 0.05)
end

function T.limit(game)
    local sv = SandboxVars.ViewDoctor or {}
    local base = sv.TimeLimit or 30
    if game == "saw" or game == "connect" then return base * 1.3 end
    return base
end

T.partOf = partOf
