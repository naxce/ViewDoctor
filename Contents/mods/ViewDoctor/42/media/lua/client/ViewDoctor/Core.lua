require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "ViewDoctor/Games"
require "ViewDoctor/Events"
require "ViewDoctor/State"
require "ViewDoctor/Effects"
require "ViewDoctor/Treatments"
require "ViewDoctor/Undress"
require "ViewDoctor/Panel"

local Core = {}
ViewDoctor.Core = Core

local T = ViewDoctor.Treatments
local Effects = ViewDoctor.Effects
local Undress = ViewDoctor.Undress

local add = ISTimedActionQueue.add
local addAfter = ISTimedActionQueue.addAfter

local GRADE_COLOR = {
    Clean = { 120, 220, 120 },
    Fine = { 220, 220, 160 },
    Sloppy = { 230, 160, 90 },
    Botched = { 230, 80, 70 },
}

local function call(name, ...)
    if ViewDoctorPose == nil then return nil end
    local okFn, fn = pcall(function() return ViewDoctorPose[name] end)
    if not okFn or not fn then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function halo(player, grade)
    local c = GRADE_COLOR[grade]
    player:setHaloNote(getText("IGUI_VD_Grade_" .. grade), c[1], c[2], c[3], 300)
end

Core.pending = {}

Events.OnTick.Add(function()
    if #Core.pending == 0 then return end
    local list = Core.pending
    Core.pending = {}
    for _, job in ipairs(list) do
        if job.run then
            pcall(job.run)
        else
            pcall(Effects.send, job.doctor, job.patient, job.part, job.effect, job.q, false)
        end
    end
end)

local function gatesOn(character, part, except)
    local q = ISTimedActionQueue.getTimedActionQueue(character)
    local n = 0
    for _, a in ipairs(q and q.queue or {}) do
        if a ~= except and a.Type == "VD_GateAction" and a.info.patient == character and a.info.view == part then n = n + 1 end
    end
    return n
end

local function keep(character, action, tries)
    action.forceCancel = function()
        if tries >= 3 then return end
        table.insert(Core.pending, { run = function()
            local again = Undress.again(character, action.item)
            if again then
                keep(character, again, tries + 1)
                add(again)
            end
        end })
    end
    return action
end

local function dressLater(character, part)
    table.insert(Core.pending, { run = function()
        for _, a in ipairs(Undress.finish(character, part, gatesOn(character, part))) do add(keep(character, a, 0)) end
    end })
end

local function afterPerform(real, doctor, info, quality)
    local perform = real.perform
    real.perform = function(self)
        perform(self)
        table.insert(Core.pending, { doctor = doctor, patient = info.patient, part = info.part, effect = info.effect, q = quality })
    end
end

local function dropProps()
    call("stop")
    if ViewDoctorProps ~= nil then pcall(function() ViewDoctorProps.close() end) end
end

Events.OnMainMenuEnter.Add(dropProps)
Events.OnPlayerDeath.Add(dropProps)
Events.OnGameStart.Add(dropProps)
Events.OnGameStart.Add(function()
    local player = getSpecificPlayer(0)
    if player then Undress.restore(player) end
end)

VD_GateAction = ISBaseTimedAction:derive("VD_GateAction")

function VD_GateAction:isValid()
    if self.finished then return true end
    local real = self.real
    if real.isValid then
        local ok, valid = pcall(real.isValid, real)
        if ok and valid == false then return false end
    end
    return true
end

function VD_GateAction:waitToStart()
    local real = self.real
    if real.waitToStart then
        local ok, wait = pcall(real.waitToStart, real)
        if ok then return wait == true end
    end
    return false
end

function VD_GateAction:start()
    local info, patient = self.info, self.info.patient
    local follow = false
    if self.character == patient then
        local left, right = T.hands(self.character)
        follow = call("start", info.view, left, right) == true
    end
    if info.anim then
        self:setActionAnim(info.anim)
    elseif self.character ~= patient then
        self:setActionAnim("Loot")
        self.character:SetVariable("LootPosition", "Mid")
    elseif not follow or call("firstPerson") ~= true then
        self:setActionAnim(CharacterActionAnims.Bandage)
        if info.bodyPart and ISHealthPanel and ISHealthPanel.getBandageType then
            self:setAnimVariable("BandageType", ISHealthPanel.getBandageType(info.bodyPart))
        end
        self.character:reportEvent("EventBandage")
    end
    self:setOverrideHandModels(nil, nil)

    local oneHanded = T.oneHanded(self.character, info.part)
    local opts = {}
    for k, v in pairs(info.opts) do opts[k] = v end
    opts.diff = T.difficulty(self.character, oneHanded)
    opts.limit = T.limit(info.game)

    local partLabel = info.bodyPart and BodyPartType.getDisplayName(info.bodyPart:getType()) or ""
    self.panel = ViewDoctor.Panel.open({
        game = info.game,
        opts = opts,
        tremor = T.tremor(self.character, oneHanded),
        follow = follow,
        part = info.view,
        title = getText("IGUI_VD_Title_" .. info.effect) .. (partLabel ~= "" and (" - " .. partLabel) or ""),
        help = getText("IGUI_VD_Help_" .. info.game .. (info.opts.reverse and "_off" or "") .. (info.opts.bullet and "_bullet" or "")),
        onDone = function(cancelled, quality, game) self:resolve(cancelled, quality, game) end,
    })
end

function VD_GateAction:update()
    if self.character ~= self.info.patient then self.character:faceThisObject(self.info.patient) end
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
    if self.panel and self.panel.closed and not self.finished then self:forceStop() end
end

function VD_GateAction:dress()
    if self.dressed or self.character ~= self.info.patient then return end
    self.dressed = true
    dressLater(self.character, self.info.view)
end

function VD_GateAction:forceCancel()
    self:dress()
end

function VD_GateAction:cleanup()
    call("stop")
    self:dress()
    if self.panel and not self.panel.closed then
        self.finished = true
        self.panel:close()
    end
end

function VD_GateAction:stop()
    self:cleanup()
    ISBaseTimedAction.stop(self)
end

function VD_GateAction:perform()
    self:cleanup()
    ISBaseTimedAction.perform(self)
end

function VD_GateAction:resolve(cancelled, quality, game)
    if self.finished then return end
    self.finished = true
    call("stop")
    local info = self.info
    if cancelled then
        self:forceStop()
        return
    end

    local grade = Effects.grade(quality)
    halo(self.character, grade)
    if grade == "Botched" then
        pcall(Effects.send, self.character, info.patient, info.part, info.effect, quality, true)
        self:forceStop()
        return
    end

    local real = self.real
    if info.ehr then
        real = EHR and EHR.StitchMinigame and EHR.StitchMinigame.CreateVanillaAction
            and EHR.StitchMinigame.CreateVanillaAction(real.character, real.otherPlayer, real.item, real.bodyPart, quality, game.misses)
        if not real then
            self:forceStop()
            return
        end
    else
        afterPerform(real, self.character, info, quality)
    end
    real._vdDone = true
    if real.maxTime and real.maxTime > 1 then real.maxTime = 1 end
    if isClient() and (SandboxVars.ViewDoctor or {}).InstantOnServer == true then
        sendClientCommand(self.character, "ViewDoctor", "done", { type = real.Type })
    end
    ISTimedActionQueue.addAfter(self, real)
    if self.character == info.patient then
        self.dressed = true
        local last = real
        for _, a in ipairs(Undress.finish(self.character, info.view, gatesOn(self.character, info.view, self))) do
            addAfter(last, keep(self.character, a, 0))
            last = a
        end
    end
    self:forceComplete()
end

function VD_GateAction:new(character, real, info)
    local o = ISBaseTimedAction.new(self, character)
    o.real = real
    o.info = info
    o.maxTime = -1
    o.stopOnWalk = real.stopOnWalk ~= false
    o.stopOnRun = true
    o.stopOnAim = true
    o.useProgressBar = false
    o.ignoreHandsWounds = true
    o.skipTOC = true
    return o
end

function Core.gate(action)
    if type(action) ~= "table" or action._vdDone or action.Type == "VD_GateAction" then return nil end
    local sv = SandboxVars.ViewDoctor
    if sv and sv.Enabled == false then return nil end
    if not T.actions[action.Type] then return nil end
    local c = action.character
    if not instanceof(c, "IsoPlayer") or not c:isLocalPlayer() or c:getPlayerNum() ~= 0 then return nil end
    if c:isTimedActionInstant() or JoypadState.players[1] then return nil end
    local ok, info = pcall(T.resolve, action)
    if not ok or not info or not info.patient or not info.part then return nil end
    return info
end

local function wrap(action)
    local info = Core.gate(action)
    if not info then return action, {} end
    local gate = VD_GateAction:new(action.character, action, info)
    action._vdGate = gate
    local strip = {}
    if info.patient == action.character then
        local c, part = action.character, info.view
        strip = Undress.begin(c, part, gatesOn(c, part))
        for _, a in ipairs(strip) do
            local stop = a.stop
            a.stop = function(self)
                dressLater(c, part)
                return stop(self)
            end
            a.forceCancel = function() dressLater(c, part) end
        end
    end
    return gate, strip
end

ISTimedActionQueue.add = function(action)
    local gate, strip = wrap(action)
    for _, a in ipairs(strip) do add(a) end
    return add(gate)
end

ISTimedActionQueue.addAfter = function(previous, action)
    if type(previous) == "table" and previous._vdGate and type(action) == "table" and action.character
        and ISTimedActionQueue.getTimedActionQueue(action.character):indexOf(previous) == -1 then
        previous = previous._vdGate
    end
    local gate, strip = wrap(action)
    for _, a in ipairs(strip) do
        addAfter(previous, a)
        previous = a
    end
    return addAfter(previous, gate)
end
