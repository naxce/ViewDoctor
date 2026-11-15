ViewDoctor = ViewDoctor or {}

local State = { VERSION = 1, migrations = {} }
ViewDoctor.State = State

function State.get(player)
    local md = player:getModData()
    local s = md.ViewDoctor
    if type(s) ~= "table" then
        s = { v = State.VERSION, parts = {} }
        md.ViewDoctor = s
    end
    for n = (s.v or 0) + 1, State.VERSION do
        if State.migrations[n] then State.migrations[n](s) end
        s.v = n
    end
    s.parts = s.parts or {}
    return s
end
