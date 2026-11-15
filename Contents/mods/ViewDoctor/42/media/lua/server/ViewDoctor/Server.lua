require "ViewDoctor/Effects"
require "ViewDoctor/Treatments"

local Server = {}
ViewDoctor.Server = Server

local T = ViewDoctor.Treatments
local MIN_GAP_MS = 1500
local MAX_RANGE = 4
local GRANT_MS = 5000
local lastAt = {}
local grants = {}

local function instantOn()
    return (SandboxVars.ViewDoctor or {}).InstantOnServer == true
end

function Server.grant(player, actionType, nowMs)
    grants[player:getOnlineID()] = { type = actionType, at = nowMs }
end

function Server.instant(action, nowMs)
    if not instantOn() or not action.character then return false end
    local id = action.character:getOnlineID()
    local g = grants[id]
    if not g or g.type ~= action.Type or nowMs - g.at >= GRANT_MS then return false end
    grants[id] = nil
    return true
end

function Server.wrapDurations()
    for name in pairs(T.actions) do
        local cls = _G[name]
        if type(cls) == "table" and type(cls.getDuration) == "function" then
            local original = cls.getDuration
            cls.getDuration = function(self, ...)
                if self._vdInstant or Server.instant(self, getTimestampMs()) then
                    self._vdInstant = true
                    return 1
                end
                return original(self, ...)
            end
        end
    end
end

local function limited(command, player)
    local now = getTimestampMs()
    local key = command .. player:getOnlineID()
    if now - (lastAt[key] or 0) < MIN_GAP_MS then return true end
    lastAt[key] = now
    return false
end

local function result(player, args)
    local patient = player
    local id = tonumber(args.patient)
    if id and id ~= player:getOnlineID() then patient = getPlayerByOnlineID(id) end
    if not patient or patient:isDead() then return end
    if patient ~= player and patient:DistToSquared(player) > MAX_RANGE * MAX_RANGE then return end
    local q = tonumber(args.q)
    if not q then return end
    q = ViewDoctor.Games.clamp(q, 0, 1)
    ViewDoctor.fireResult({
        doctor = player, patient = patient, part = tostring(args.part), treatment = tostring(args.effect),
        quality = q, grade = ViewDoctor.Effects.grade(q), botched = args.botched == true,
    })
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "ViewDoctor" or type(args) ~= "table" then return end
    if command == "result" then
        if not limited(command, player) then result(player, args) end
    elseif command == "done" then
        if T.actions[args.type] and not limited(command, player) then Server.grant(player, args.type, getTimestampMs()) end
    end
end)

Server.wrapDurations()
