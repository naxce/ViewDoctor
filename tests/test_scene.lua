next = nil
package.path = arg[1] .. "/client/?.lua;" .. arg[1] .. "/shared/?.lua;" .. package.path
math.randomseed(11)
require "ViewDoctor/Games"
require "ViewDoctor/Scene"
local G = ViewDoctor.Games
local Scene = ViewDoctor.Scene

local FIELDS = { "x", "y", "lift", "turn", "tilt", "scale" }

local function sane(props, what)
    local seen = {}
    for _, p in ipairs(props) do
        assert(type(p.id) == "number" and p.id >= 0 and p.id < 96 and p.id == math.floor(p.id), what .. ": id in the pool, got " .. tostring(p.id))
        assert(not seen[p.id], what .. ": id " .. p.id .. " used twice")
        seen[p.id] = true
        assert(type(p.model) == "string" and p.model ~= "", what .. ": model name")
        for _, f in ipairs(FIELDS) do
            assert(type(p[f]) == "number" and p[f] == p[f] and math.abs(p[f]) < 1e6, what .. ": " .. f .. " is a real number")
        end
    end
    return seen
end

local function count(props, model)
    local n = 0
    for _, p in ipairs(props) do if p.model == model then n = n + 1 end end
    return n
end

local TOOLS = { connect = "SutureNeedleHolder", snip = "Scalpel", wrap = "Bandage", scrub = "VD_Swab", extract = "Tweezers", saw = "GardenSaw", hold = "Scalpel", inject = "VD_Syringe" }
for _, kind in ipairs(G.kinds) do
    local g = G.new(kind, { diff = 1 })
    local props, tool = Scene.build(g, 0.5, 0.5)
    assert(#props >= 1, kind .. ": at least one prop")
    sane(props, kind)
    assert(tool and tool.model == TOOLS[kind] and tool.x == 0.5 and tool.y == 0.5 and tool.tilt == tool.tilt, kind .. ": cursor tool")
end

local g = G.new("connect", { diff = 0.5 })
local before = Scene.build(g, 0.5, 0.5)
local dots, arches = count(before, "VD_Dot"), count(before, "VD_Stitch")
assert(dots == g.total and arches == 0 and count(before, "VD_Gash") == 1, "a fresh wound shows every entry point and no stitch")
G.press(g, G.point(g, 1))
for i = 2, 3 do
    for k = 1, 12 do
        local ax, ay = G.point(g, i - 1)
        local bx, by = G.point(g, i)
        G.move(g, ax + (bx - ax) * k / 12, ay + (by - ay) * k / 12)
        G.tick(g, 0.025)
    end
end
assert(g.at == 3, "two pairs closed")
local after = Scene.build(g, 0.6, 0.6)
assert(count(after, "VD_Dot") == dots - 3, "reached points lose their dot")
assert(count(after, "VD_Stitch") == 2, "each closed pair is a stitch")
assert(count(after, "VD_Thread") == 1, "thread runs to the needle while holding")
sane(after, "connect in play")

g = G.new("extract", { diff = 0.5 })
while #g.shards < 3 do g = G.new("extract", { diff = 0.5 }) end
local full = sane(Scene.build(g, 0.5, 0.5), "extract")
assert(count(Scene.build(g, 0.5, 0.5), "VD_Shard") == #g.shards, "one shard prop per shard")
local gone = g.shards[2]
local goneId
for _, p in ipairs(Scene.build(g, 0.5, 0.5)) do
    if p.model == "VD_Shard" and math.abs(p.x - gone.x) < 1e-9 and math.abs(p.y - gone.y) < 1e-9 then goneId = p.id end
end
table.remove(g.shards, 2)
local left = sane(Scene.build(g, 0.5, 0.5), "extract after a pull")
local missing = 0
for id in pairs(full) do
    if not left[id] then
        missing = missing + 1
        assert(id == goneId, "the removed shard's own id disappears")
    end
end
assert(missing == 1, "removing one shard drops exactly one id")

g = G.new("extract", { diff = 0.5, bullet = true })
local b = Scene.build(g, 0.5, 0.5)
assert(count(b, "VD_Hole") == 1 and count(b, "VD_Bullet") == 1, "a bullet sits in its hole")

g = G.new("wrap", { diff = 1, passes = 6 })
g.lane = 7
local wrapped = Scene.build(g, 0.5, 0.5)
sane(wrapped, "wrap done")
assert(count(wrapped, "VD_Wrap") == 36, "six lanes of six pieces")
g = G.new("wrap", { diff = 1, passes = 3, reverse = true })
assert(count(Scene.build(g, 0.5, 0.5), "VD_Wrap") == 18, "removing starts fully wrapped")
g.lane = 4
assert(count(Scene.build(g, 0.5, 0.5), "VD_Wrap") == 0, "and ends bare")
g = G.new("wrap", { diff = 1, passes = 3, board = true })
local splint, splintTool = Scene.build(g, 0.5, 0.5)
assert(count(splint, "VD_Board") == 2 and splintTool == nil, "a splint has two boards and no cursor tool")

g = G.new("scrub", { diff = 0.5 })
local dirty = count(Scene.build(g, 0.5, 0.5), "VD_Patch")
g.spots[1].dirt = 0
assert(count(Scene.build(g, 0.5, 0.5), "VD_Patch") == dirty - 1, "a clean spot has no patch")
g = G.new("scrub", { diff = 0.5, gentle = true })
assert(count(Scene.build(g, 0.5, 0.5), "VD_Patch@VD_Burn") > 0, "burns use the burn texture")

g = G.new("saw", { diff = 0.5 })
local shallow = count(Scene.build(g, 0.5, 0.5), "VD_Cut")
g.strokes = g.need
assert(count(Scene.build(g, 0.5, 0.5), "VD_Cut") > shallow, "the cut grows with the strokes")

local sets, drops, tools = 0, 0, 0
local api = {
    set = function() sets = sets + 1 end,
    drop = function() drops = drops + 1 end,
    tool = function() tools = tools + 1 end,
}
g = G.new("connect", { diff = 0.5 })
local props, tool = Scene.build(g, 0.5, 0.5)
local last = Scene.sync(props, tool, nil, api)
assert(sets == #props and drops == 0 and tools == 1, "first sync sets everything")
sets = 0
props, tool = Scene.build(g, 0.5, 0.5)
last = Scene.sync(props, tool, last, api)
assert(sets == 0 and tools == 2, "an unchanged scene sets nothing")
props[2].x = props[2].x + 0.01
last = Scene.sync(props, tool, last, api)
assert(sets == 1, "one moved prop is one set")
table.remove(props, 3)
sets = 0
last = Scene.sync(props, tool, last, api)
assert(sets == 0 and drops == 1, "a vanished prop is one drop")
Scene.sync(props, nil, last, api)
assert(tools == 5, "the tool is reported every call")

print("scene ok")
