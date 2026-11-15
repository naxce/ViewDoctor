next = nil
package.path = arg[1] .. "/shared/?.lua;" .. package.path
math.randomseed(7)
require "ViewDoctor/Games"
local G = ViewDoctor.Games

local function new(kind, opts)
    opts = opts or {}
    opts.rand = function(lo, hi) return lo + math.random() * (hi - lo) end
    return G.new(kind, opts)
end

local function drag(g, ax, ay, bx, by, steps, seconds)
    for i = 1, steps do
        local t = i / steps
        G.move(g, ax + (bx - ax) * t, ay + (by - ay) * t)
        G.tick(g, (seconds or 0.5) / steps)
    end
end

local function near(q, lo, hi, what)
    assert(q >= lo and q <= hi, what .. ": quality " .. q .. " outside " .. lo .. ".." .. hi)
end

local function stitch(g, i, steps)
    for k = 1, steps do
        local ax, ay = G.point(g, i - 1)
        local bx, by = G.point(g, i)
        local t = k / steps
        G.move(g, ax + (bx - ax) * t, ay + (by - ay) * t)
        G.tick(g, 0.3 / steps)
    end
end

local g = new("connect", { diff = 0.5 })
G.press(g, G.point(g, 1))
for i = 2, g.total do stitch(g, i, 12) end
assert(g.done, "connect finishes when every dot is joined")
assert(not g.holding, "the last dot lets go of the thread")
near(G.quality(g), 0.9, 1, "clean stitching")

g = new("connect", { diff = 0.5 })
G.press(g, G.point(g, 1))
drag(g, g.points[1].x, g.points[1].y, 0.9, 0.95, 10)
assert(g.slips == 1 and not g.holding, "veering off the line tears the thread")
G.press(g, 0.0, 0.0)
assert(g.misses == 1 and g.at == 1, "a press off the dot is a miss")
near(G.quality(g), 0, 0.1, "torn stitch")

g = new("connect", { diff = 1 })
local x1, y1 = G.point(g, 1)
G.press(g, x1, y1)
local x2, y2 = G.point(g, 2)
drag(g, x1, y1, x1 + (x2 - x1) * 0.9, y1 + (y2 - y1) * 0.9, 10, 0.02)
assert(g.slips == 1, "yanking the needle tears")

g = new("connect", { diff = 0.5 })
G.press(g, G.point(g, 1))
for i = 2, g.total do
    stitch(g, i, 12)
    G.release(g, G.point(g, i))
    if not g.done then G.press(g, G.point(g, i)) end
end
assert(g.done and g.slips == 0, "letting go on a reached dot is not a slip")
near(G.quality(g), 0.9, 1, "stitching dot by dot")

g = new("connect", { diff = 0.5 })
G.press(g, G.point(g, 1))
local mx, my = G.point(g, 1)
local nx, ny = G.point(g, 2)
drag(g, mx, my, (mx + nx) / 2, (my + ny) / 2, 6)
G.release(g, (mx + nx) / 2, (my + ny) / 2)
assert(g.slips == 1, "letting go between dots is a slip")

for _, kind in ipairs(G.kinds) do
    local a, b = new(kind, { diff = 0.5 }), new(kind, { diff = 0.5 })
    G.loosen(b, 2)
    G.loosen(b, 2)
    for _, f in ipairs({ "radius", "tolerance", "half", "reach", "lateral", "probeRadius", "maxSpeed", "minSpeed", "speedLimit" }) do
        if a[f] then assert(math.abs(b[f] - a[f] * 2) < 1e-9, kind .. ": loosen scales " .. f .. " once from its base") end
    end
    G.loosen(b, 1)
    if a.radius then assert(b.radius == a.radius, kind .. ": loosen 1 restores the base") end
end

g = new("snip", { diff = 0 })
g.window = 1
for _ = 1, g.total do local k = g.knots[1]; G.press(g, k.x, k.y) end
assert(g.done and G.quality(g) == 1, "every knot snipped on the beat")

g = new("snip", { diff = 1 })
local k = g.knots[1]
g.t = (0.5 - k.phase % 1) * g.period
if g.t < 0 then g.t = g.t + g.period end
assert(not G.tight(g, k), "the ring is wide")
G.press(g, k.x, k.y)
assert(g.cut == 0 and g.misses == 1, "snipping off the beat nicks the skin")

g = new("wrap", { diff = 0.5 })
for _, lane in ipairs(g.lanes) do
    G.press(g, lane.x, lane.from)
    drag(g, lane.x, lane.from, lane.x, lane.to, 12)
end
assert(g.done, "wrap done after every pass")
near(G.quality(g), 0.9, 1, "tidy bandage")

g = new("wrap", { diff = 0.5 })
for _, lane in ipairs(g.lanes) do
    G.press(g, lane.x, lane.from)
    drag(g, lane.x + 0.15, lane.from, lane.x + 0.15, lane.to, 12)
end
near(G.quality(g), 0.1, 0.4, "bandage wrapped off the lanes")

g = new("wrap", { diff = 0.5 })
for _, lane in ipairs(g.lanes) do
    G.press(g, lane.x, lane.from)
    drag(g, lane.x, lane.from, lane.x, lane.to, 12, 0.1)
end
near(G.quality(g), 0.3, 0.6, "bandage yanked on too fast is loose")

g = new("wrap", { reverse = true, passes = 3 })
assert(g.total == 3 and g.lanes[1].x > g.lanes[3].x, "unwrapping goes the other way")

g = new("scrub", { diff = 0.5 })
G.press(g, 0.5, 0.5)
for _, s in ipairs(g.spots) do
    for n = 1, 30 do G.move(g, s.x + 0.03 * math.cos(n), s.y + 0.03 * math.sin(n)); G.tick(g, 0.05) end
end
assert(g.done, "scrub done once every spot is clean")
near(G.quality(g), 0.95, 1, "gentle scrubbing")

g = new("scrub", { diff = 1 })
local spot = g.spots[1]
spot.dirt = 0.5
for _ = 1, 40 do G.tick(g, 0.1) end
assert(spot.dirt > 0.6, "half cleaned dirt creeps back")

g = new("scrub", { gentle = true })
G.press(g, 0.5, 0.5)
for n = 1, 40 do G.move(g, 0.5 + (n % 2) * 0.1, 0.5); G.tick(g, 0.02) end
assert(g.rough > 0.3, "rubbing a burn hard is rough")

g = new("extract", { bullet = true, diff = 0.5 })
G.press(g, 0.5, 0.5)
for _ = 1, 40 do G.move(g, 0.5, 0.5); G.tick(g, 0.05) end
assert(g.probe >= g.probeNeed, "the probe found the bullet")
local s = g.shards[1]
local ex, ey = G.shardEnd(s, 0)
G.release(g)
G.press(g, ex, ey)
assert(g.grab == 1, "grabbed the bullet")
drag(g, ex, ey, ex + s.dx * 0.25, ey + s.dy * 0.25, 30, 1.5)
assert(g.done, "bullet out")
near(G.quality(g), 0.99, 1, "steady extraction")

g = new("extract", { diff = 1 })
s = g.shards[1]
ex, ey = G.shardEnd(s, 0)
G.press(g, ex, ey)
G.move(g, ex + s.dx * 0.1, ey + s.dy * 0.1)
G.tick(g, 0.01)
assert(g.slips == 1 and g.grab == nil, "yanking glass out too fast slips")

g = new("extract", { diff = 1 })
local s = g.shards[1]
local ex, ey = G.shardEnd(s, 0)
G.press(g, ex, ey)
for i = 1, 40 do
    local t = i / 40 * 0.2
    G.move(g, ex + s.dx * t - s.dy * 0.03, ey + s.dy * t + s.dx * 0.03)
    G.tick(g, 0.025)
end
assert(g.slips == 0 and g.removed == 1, "a hand 0.03 off the line at a careful pace keeps the shard on Hard")

g = new("extract", { diff = 1 })
g.ky = 0.4
s = g.shards[1]
s.dx, s.dy = 1, 0
ex, ey = G.shardEnd(s, 0)
G.press(g, ex, ey + 0.04)
assert(g.grab == 1, "on a thin limb a grab a little across the shard still holds it")
for i = 1, 40 do
    G.move(g, ex + i / 40 * 0.2, ey + 0.04 + 0.05)
    G.tick(g, 0.025)
end
assert(g.slips == 0 and g.removed == 1, "drift across a thin limb is judged by its size on screen")

g = new("saw", { diff = 0 })
g.wander = 0
G.press(g, 0.5, 0.25)
local y = 0.25
for _ = 1, g.need do
    local to = y < 0.5 and 0.75 or 0.25
    drag(g, 0.5, y, 0.5, to, 8, 0.4)
    y = to
end
assert(g.done, "sawed through")
near(G.quality(g), 0.99, 1, "straight cut")

g = new("saw", { diff = 1 })
g.wander = 0
G.press(g, 0.5, 0.25)
drag(g, 0.5, 0.25, 0.5, 0.75, 2, 0.05)
assert(g.slips == 1 and not g.holding, "forcing the saw binds it")

g = new("hold", { diff = 0 })
g.nextKick = 99
G.press(g, 0.5, 0.5)
for _ = 1, 40 do G.tick(g, 0.1) end
assert(g.done, "cauterized")
near(G.quality(g), 0.99, 1, "held still")

g = new("inject", {})
G.press(g, g.tx, G.vein(g, g.tx))
for _ = 1, 12 do G.move(g, g.tx, G.vein(g, g.tx)); G.tick(g, 0.05) end
assert(g.phase == "push", "needle settled in the vein")
local px = g.lx
for n = 1, 40 do
    local x = px + 0.18 * n / 40
    G.move(g, x, G.vein(g, g.tx))
    G.tick(g, 0.03)
end
assert(g.success and g.done, "plunger pushed")
near(G.quality(g), 0.6, 1, "one clean injection")

g = new("inject", {})
G.press(g, g.tx, G.vein(g, g.tx))
for _ = 1, 12 do G.move(g, g.tx, G.vein(g, g.tx)); G.tick(g, 0.05) end
G.move(g, g.lx + 0.1, g.ly)
G.tick(g, 0.02)
assert(g.attempts == 1 and not g.holding, "ramming the plunger blows the vein")

g = new("inject", {})
for _ = 1, 3 do G.press(g, 0, 0) end
assert(g.done and G.quality(g) == 0, "three misses and the vein is lost")

g = new("snip", {})
G.tick(g, g.limit + 1)
assert(g.done and g.timedOut and G.quality(g) == 0, "running out of time ends the game")

for _, kind in ipairs(G.kinds) do
    local hard = new(kind, { diff = 1 })
    local easy = new(kind, { diff = 0 })
    assert(hard.radius == nil or hard.radius < easy.radius, kind .. ": harder means smaller targets")
    assert(G.progress(easy) == 0, kind .. ": nothing done yet")
end

print("games ok")
