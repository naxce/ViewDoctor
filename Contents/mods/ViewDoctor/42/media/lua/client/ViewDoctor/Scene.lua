require "ViewDoctor/Games"

local G = ViewDoctor.Games
local clamp = G.clamp

local Scene = {}
ViewDoctor.Scene = Scene

Scene.TILT = 0.9
Scene.PIECES = 6

local TOOL = {
    connect = "SutureNeedleHolder",
    snip = "Scalpel",
    wrap = "Bandage",
    scrub = "VD_Swab",
    extract = "Tweezers",
    saw = "GardenSaw",
    hold = "Scalpel",
    inject = "VD_Syringe",
}

Scene.SIZE = {
    SutureNeedleHolder = 0.8,
    Scalpel = 1,
    Bandage = 0.4,
    Tweezers = 0.8,
    GardenSaw = 0.7,
}

local function put(list, id, model, x, y, lift, turn, tilt, scale)
    list[#list + 1] = { id = id, model = model, x = x, y = y, lift = lift or 0, turn = turn or 0, tilt = tilt or 0, scale = scale or 1 }
end

local function span(g, x1, y1, x2, y2)
    local dx, dy = (x2 - x1) * g.len, (y2 - y1) * g.ky * g.len
    return math.sqrt(dx * dx + dy * dy), math.atan2(dy, dx)
end

local function rod(list, g, id, model, x1, y1, x2, y2, lift)
    local l, turn = span(g, x1, y1, x2, y2)
    if l < 1e-5 then return end
    put(list, id, model, (x1 + x2) / 2, (y1 + y2) / 2, lift, turn, 0, l)
end

local function girth(g)
    return g.ky * g.len / 2.4
end

local function idOf(g, item, first)
    if not item._vd then
        g._vdNext = (g._vdNext or first) + 1
        item._vd = g._vdNext - 1
    end
    return item._vd
end

local build = {}

build.connect = function(g, list, tipX, tipY)
    put(list, 0, "VD_Gash", 0.5, 0.5 + g.sway, 0, 0, 0, 0.68 * g.len / 0.1)
    for i = 1, g.total do
        local x, y = G.point(g, i)
        if i > g.at then
            local size = g.radius * g.len / 0.004
            if i == g.at + 1 then size = size * 1.5 end
            put(list, i, "VD_Dot", x, y, 0.001, 0, 0, size)
        end
        if i < g.at then
            local nx, ny = G.point(g, i + 1)
            local l, turn = span(g, x, y, nx, ny)
            put(list, 20 + i, "VD_Stitch", (x + nx) / 2, (y + ny) / 2, 0, turn, 0, math.max(0.2, l / 0.018))
        end
    end
    if g.holding and g.at >= 1 then
        local x, y = G.point(g, g.at)
        rod(list, g, 40, "VD_Thread", x, y, tipX, tipY, 0.004)
    end
end

build.snip = function(g, list)
    put(list, 0, "VD_Gash", 0.5, 0.5, 0, 0, 0, 0.5 * g.len / 0.1)
    for i, k in ipairs(g.knots) do
        put(list, idOf(g, k, 1), "VD_Stitch", k.x, k.y, 0, math.pi / 2, 0, i == 1 and 2.2 or 1.7)
    end
end

build.wrap = function(g, list, tipX, tipY)
    local n = Scene.PIECES
    local r = girth(g)
    put(list, 95, "VD_Gash", 0.5, 0.5, 0, 0, 0, 0.3 * g.len / 0.1)
    for i, lane in ipairs(g.lanes) do
        local shown = 0
        if i < g.lane then
            shown = n
        elseif i == g.lane and g.holding then
            shown = math.floor(clamp((tipY - lane.from) / (lane.to - lane.from), 0, 1) * n + 0.5)
        end
        for k = 1, n do
            local on = k <= shown
            if g.opts.reverse then on = not on end
            if on then
                put(list, (i - 1) * n + k - 1, "VD_Wrap", lane.x, lane.from + (lane.to - lane.from) * (k - 0.5) / n, 0, 0, 0, r)
            end
        end
    end
    if g.opts.board then
        put(list, 90, "VD_Board", 0.5, 0.2, 0.002, 0, 0, g.len / 0.25)
        put(list, 91, "VD_Board", 0.5, 0.8, 0.002, 0, 0, g.len / 0.25)
    end
end

build.scrub = function(g, list)
    put(list, 0, "VD_Gash", 0.5, 0.5, 0, 0, 0, g.core * 2 * g.len / 0.1)
    local model = g.opts.gentle and "VD_Patch@VD_Burn" or "VD_Patch"
    for i, s in ipairs(g.spots) do
        if s.dirt > 0 then
            put(list, i, model, s.x, s.y, 0.001, i * 1.3, 0, s.size * (0.4 + 0.6 * s.dirt) * 0.045 * g.len / 0.015)
        end
    end
end

build.extract = function(g, list)
    if not g.opts.bullet then put(list, 0, "VD_Gash", 0.5, 0.5, 0, 0, 0, 0.4 * g.len / 0.1) end
    for _, s in ipairs(g.shards) do
        local id = idOf(g, s, 1)
        local _, turn = span(g, 0, 0, s.dx, s.dy)
        local x, y = s.x + s.dx * s.pulled, s.y + s.dy * s.pulled
        if g.opts.bullet then
            put(list, 0, "VD_Hole", s.x, s.y, 0, 0, 0, 2)
            put(list, id, "VD_Bullet", x, y, 0.001, turn, Scene.TILT, 2.5)
        else
            put(list, id, "VD_Shard", x, y, 0, turn, Scene.TILT, 1)
        end
    end
end

build.saw = function(g, list)
    local n = Scene.PIECES
    local shown = math.max(1, math.ceil(n * clamp(g.strokes / g.need, 0, 1)))
    local r = girth(g)
    for k = 1, n do
        if math.abs(k - (n + 1) / 2) < shown / 2 + 0.01 then
            put(list, k - 1, "VD_Cut", 0.5, 0.2 + 0.6 * (k - 0.5) / n, 0, 0, 0, r)
        end
    end
end

build.hold = function(g, list)
    local x, y = G.target(g)
    put(list, 0, "VD_Patch@VD_Glow", x, y, 0.001, 0, 0, g.radius * g.len / 0.015)
end

build.inject = function(g, list)
    local n = 8
    local lx, ly
    for i = 0, n do
        local x = 0.08 + 0.84 * i / n
        local y = G.vein(g, x)
        if lx then rod(list, g, i - 1, "VD_Vein", lx, ly, x, y, 0.0005) end
        lx, ly = x, y
    end
    put(list, 10, "VD_Dot", g.tx, G.vein(g, g.tx), 0.002, 0, 0, g.radius * g.len / 0.004 * 0.6)
end

function Scene.build(g, tipX, tipY)
    g.len = g.len or 0.25
    local list = {}
    build[g.kind](g, list, tipX, tipY)
    local tool
    if not g.opts.board then
        local model = TOOL[g.kind]
        tool = { model = model, x = tipX, y = tipY, tilt = Scene.TILT, scale = Scene.SIZE[model] or 1 }
    end
    return list, tool
end

local FIELDS = { "model", "x", "y", "lift", "turn", "tilt", "scale" }

function Scene.sync(props, tool, last, api)
    api = api or ViewDoctorProps
    last = last or {}
    local now = {}
    for _, p in ipairs(props) do
        local old = last[p.id]
        local same = old ~= nil
        if same then
            for _, f in ipairs(FIELDS) do
                if old[f] ~= p[f] then
                    same = false
                    break
                end
            end
        end
        if not same then api.set(p.id, p.model, p.x, p.y, p.lift, p.turn, p.tilt, p.scale) end
        now[p.id] = { model = p.model, x = p.x, y = p.y, lift = p.lift, turn = p.turn, tilt = p.tilt, scale = p.scale }
    end
    for id in pairs(last) do
        if not now[id] then api.drop(id) end
    end
    if tool then api.tool(tool.model, tool.x, tool.y, tool.tilt, tool.scale) else api.tool("", 0.5, 0.5, 0, 1) end
    return now
end

return Scene
