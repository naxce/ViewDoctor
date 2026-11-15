next = nil
package.path = arg[1] .. "/server/?.lua;" .. arg[1] .. "/shared/?.lua;" .. package.path
local handlers = {}
Events = setmetatable({}, { __index = function(t, k)
    local e = { Add = function(f) handlers[k] = handlers[k] or {}; table.insert(handlers[k], f) end }
    rawset(t, k, e)
    return e
end })
SandboxVars = { ViewDoctor = { Enabled = true, Difficulty = 2, TimeLimit = 30, QualityEffects = true, BotchPenalty = true } }
getTimestampMs = function() return 0 end
ISStitch = { getDuration = function() return 200 end }
require "ViewDoctor/Server"

local S = ViewDoctor.Server
local doc = { getOnlineID = function() return 1 end }
local act = setmetatable({ Type = "ISStitch", character = doc }, { __index = ISStitch })
SandboxVars.ViewDoctor.InstantOnServer = false
S.grant(doc, "ISStitch", 0)
assert(act:getDuration() == 200, "option off: server keeps the vanilla time")
SandboxVars.ViewDoctor.InstantOnServer = true
S.grant(doc, "ISStitch", 0)
assert(S.instant(act, 1000) == true, "fresh grant shortens")
assert(S.instant(act, 1000) == false, "grant is single-use and type-bound")
S.grant(doc, "ISApplyBandage", 0)
assert(S.instant(act, 1000) == false, "grant is single-use and type-bound")
S.grant(doc, "ISStitch", 0)
assert(S.instant(act, 6000) == false, "grant expires")
S.grant(doc, "ISStitch", 0)
getTimestampMs = function() return 100 end
assert(act:getDuration() == 1, "a granted action runs instantly on the server")
local twice = setmetatable({ Type = "ISStitch", character = doc }, { __index = ISStitch })
S.grant(doc, "ISStitch", 200)
assert(twice:getDuration() == 1 and twice:getDuration() == 1, "the granted action stays instant when the game asks its duration again")
local later = setmetatable({ Type = "ISStitch", character = doc }, { __index = ISStitch })
assert(later:getDuration() == 200, "a later action is not shortened")
print("server ok")
