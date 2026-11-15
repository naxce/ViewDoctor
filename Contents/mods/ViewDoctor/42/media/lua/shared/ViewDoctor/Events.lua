ViewDoctor = ViewDoctor or {}

local subscribers = {}

function ViewDoctor.onResult(fn)
    table.insert(subscribers, fn)
end

function ViewDoctor.fireResult(r)
    for _, fn in ipairs(subscribers) do pcall(fn, r) end
end
