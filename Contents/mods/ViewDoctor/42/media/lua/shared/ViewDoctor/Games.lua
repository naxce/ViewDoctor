ViewDoctor = ViewDoctor or {}

local Games = {}
ViewDoctor.Games = Games

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
Games.clamp = clamp

local function dist(ax, ay, bx, by, ky)
    local dx, dy = ax - bx, (ay - by) * (ky or 1)
    return math.sqrt(dx * dx + dy * dy)
end
Games.dist = dist

local function segmentDist(px, py, ax, ay, bx, by, ky)
    ky = ky or 1
    local vx, vy = bx - ax, (by - ay) * ky
    local l2 = vx * vx + vy * vy
    if l2 <= 0 then return dist(px, py, ax, ay, ky) end
    local t = clamp(((px - ax) * vx + (py - ay) * ky * vy) / l2, 0, 1)
    return dist(px, py, ax + (bx - ax) * t, ay + (by - ay) * t, ky)
end

local function rand(g, lo, hi)
    return g.rand(lo, hi)
end

local function defaultRand(lo, hi)
    if ZombRandFloat then return ZombRandFloat(lo, hi) end
    return lo + math.random() * (hi - lo)
end

local function scaled(g, base)
    return base * (1.25 - 0.65 * g.diff)
end

local function count(g, lo, hi)
    return math.floor(lo + (hi - lo) * g.diff + 0.5)
end

local function measure(g, dt)
    if dt <= 0 then return end
    local now = g.moved / dt
    g.speed = g.speed + (now - g.speed) * math.min(1, dt * 12)
    g.moved = 0
end

local setup, press, move, release, tick, score, progress = {}, {}, {}, {}, {}, {}, {}

function Games.point(g, i)
    local p = g.points[i]
    return p.x, p.y + g.sway
end

setup.connect = function(g)
    local n = count(g, 5, 9)
    g.points = {}
    for i = 1, n do
        local t = (i - 1) / (n - 1)
        local side = (i % 2 == 0) and 1 or -1
        g.points[i] = { x = 0.2 + 0.6 * t + rand(g, -0.015, 0.015), y = 0.5 + side * (0.085 + rand(g, -0.012, 0.012)) }
    end
    g.radius = scaled(g, 0.036)
    g.tolerance = scaled(g, 0.04)
    g.maxSpeed = 2.4 - 0.9 * g.diff
    g.sway, g.swayAmp = 0, 0.006 + 0.014 * g.diff
    g.at, g.devSum, g.lenSum = 0, 0, 0
    g.total = n
end

local function tear(g)
    g.holding = false
    g.slips = g.slips + 1
    g.torn = g.t
end

press.connect = function(g, x, y)
    local wx, wy = Games.point(g, math.max(g.at, 1))
    if dist(x, y, wx, wy, g.ky) <= g.radius then
        g.holding = true
        if g.at == 0 then g.at = 1 end
        g.lx, g.ly = x, y
        g.speed = 0
    else
        g.misses = g.misses + 1
    end
end

move.connect = function(g, x, y)
    if not g.holding then return end
    local ax, ay = Games.point(g, g.at)
    local bx, by = Games.point(g, g.at + 1)
    local step = dist(x, y, g.lx, g.ly, g.ky)
    g.lx, g.ly = x, y
    g.moved = g.moved + step
    local dev = segmentDist(x, y, ax, ay, bx, by, g.ky)
    g.devSum = g.devSum + dev * step
    g.lenSum = g.lenSum + step
    if dev > g.tolerance * 2.5 then return tear(g) end
    if dist(x, y, bx, by, g.ky) <= g.radius then
        g.at = g.at + 1
        if g.at >= g.total then
            g.done = true
            g.holding = false
        end
    end
end

release.connect = function(g, x, y)
    if g.holding and not g.done then
        local px, py = Games.point(g, g.at)
        if not x or dist(x, y, px, py, g.ky) > g.radius then g.slips = g.slips + 1 end
    end
    g.holding = false
end

tick.connect = function(g, dt)
    g.sway = (math.sin(g.t * 1.9) + 0.4 * math.sin(g.t * 3.1 + 1)) * g.swayAmp
    measure(g, dt)
    if g.holding and g.speed > g.maxSpeed then tear(g) end
end

score.connect = function(g)
    local dev = g.lenSum > 0 and g.devSum / g.lenSum or 0
    local accuracy = 1 - clamp(dev / g.tolerance, 0, 1)
    return progress.connect(g) * (0.4 + 0.6 * accuracy) - 0.06 * g.slips - 0.03 * g.misses
end

progress.connect = function(g)
    return math.max(0, g.at - 1) / (g.total - 1)
end

function Games.cycle(g, k)
    return (g.t / g.period + k.phase) % 1
end

function Games.tight(g, k)
    return Games.cycle(g, k) >= 1 - g.window
end

setup.snip = function(g)
    local n = count(g, 4, 7)
    g.knots = {}
    for i = 1, n do
        local t = (i - 0.5) / n
        g.knots[i] = { x = 0.2 + 0.6 * t + rand(g, -0.015, 0.015), y = 0.5 + rand(g, -0.03, 0.03), phase = rand(g, 0, 1) }
    end
    g.radius = scaled(g, 0.032)
    g.period = 1.3 - 0.45 * g.diff
    g.window = 0.3 - 0.14 * g.diff
    g.total, g.cut = n, 0
end

press.snip = function(g, x, y)
    local k = g.knots[1]
    if k and dist(x, y, k.x, k.y, g.ky) <= g.radius and Games.tight(g, k) then
        table.remove(g.knots, 1)
        g.cut = g.cut + 1
        if g.cut >= g.total then g.done = true end
        return
    end
    g.misses = g.misses + 1
end

score.snip = function(g)
    return g.cut / g.total - 0.07 * g.misses
end

progress.snip = function(g)
    return g.cut / g.total
end

setup.wrap = function(g)
    local n = g.opts.passes or count(g, 4, 6)
    g.lanes = {}
    for i = 1, n do
        local t = (i - 0.5) / n
        local x = 0.26 + 0.48 * t
        if g.opts.reverse then x = 0.74 - 0.48 * t end
        local down = i % 2 == 1
        g.lanes[i] = { x = x, from = down and 0.2 or 0.8, to = down and 0.8 or 0.2 }
    end
    g.half = scaled(g, g.opts.reverse and 0.05 or 0.036)
    g.radius = scaled(g, 0.042)
    g.minSpeed = 0.18
    g.maxSpeed = (g.opts.reverse and 1.0 or 1.5) - 0.45 * g.diff
    g.lane, g.total, g.outside, g.travel, g.slack, g.held = 1, n, 0, 0, 0, 0
end

press.wrap = function(g, x, y)
    local lane = g.lanes[g.lane]
    if dist(x, y, lane.x, lane.from, g.ky) <= g.radius then
        g.holding = true
        g.lx, g.ly = x, y
        g.speed, g.grip = 0, 0
    else
        g.misses = g.misses + 1
    end
end

move.wrap = function(g, x, y)
    if not g.holding then return end
    local lane = g.lanes[g.lane]
    local step = dist(x, y, g.lx, g.ly, g.ky)
    g.lx, g.ly = x, y
    g.moved = g.moved + step
    g.travel = g.travel + step
    if math.abs(x - lane.x) > g.half then g.outside = g.outside + step end
    local passed = lane.to > lane.from and y >= lane.to or lane.to < lane.from and y <= lane.to
    if passed then
        g.holding = false
        g.lane = g.lane + 1
        if g.lane > g.total then g.done = true end
    end
end

release.wrap = function(g)
    if g.holding then g.slips = g.slips + 1 end
    g.holding = false
end

tick.wrap = function(g, dt)
    measure(g, dt)
    if not g.holding then return end
    g.grip = g.grip + dt
    local fast, slow = g.speed > g.maxSpeed, g.grip >= 0.2 and g.speed < g.minSpeed
    if fast or g.grip >= 0.2 then g.held = g.held + dt end
    if fast or slow then g.slack = g.slack + dt end
end

score.wrap = function(g)
    local outFrac = g.travel > 0 and g.outside / g.travel or 0
    local slackFrac = g.held > 0 and g.slack / g.held or 0
    return progress.wrap(g) * (1 - clamp(outFrac * 1.5, 0, 0.8)) * (1 - clamp(slackFrac * 0.8, 0, 0.6))
        - 0.05 * g.slips - 0.02 * g.misses
end

progress.wrap = function(g)
    return (g.lane - 1) / g.total
end

setup.scrub = function(g)
    local n = count(g, 7, 12)
    g.spots = {}
    for i = 1, n do
        local a = rand(g, 0, math.pi * 2)
        local r = rand(g, 0.12, 0.28)
        g.spots[i] = { x = 0.5 + math.cos(a) * r * 1.2, y = 0.5 + math.sin(a) * r * 0.75, dirt = 1, size = rand(g, 0.8, 1.25), rubbed = -1 }
    end
    g.reach = scaled(g, 0.065)
    g.core = g.opts.gentle and 0.11 or 0.075
    g.speedLimit = (g.opts.gentle and 0.45 or 0.8) - 0.2 * g.diff
    g.regrow = 0.05 + 0.1 * g.diff
    g.rough, g.total = 0, n
end

press.scrub = function(g, x, y)
    g.holding = true
    g.lx, g.ly = x, y
    g.speed = 0
end

local function scrubbed(g)
    for _, s in ipairs(g.spots) do
        if s.dirt > 0 then return end
    end
    g.done = true
end

move.scrub = function(g, x, y)
    if not g.holding then return end
    local step = dist(x, y, g.lx, g.ly, g.ky)
    g.lx, g.ly = x, y
    g.moved = g.moved + step
    for _, s in ipairs(g.spots) do
        if s.dirt > 0 and dist(x, y, s.x, s.y, g.ky) <= g.reach then
            s.dirt = math.max(0, s.dirt - step * 5)
            s.rubbed = g.t
        end
    end
    scrubbed(g)
end

release.scrub = function(g)
    g.holding = false
end

tick.scrub = function(g, dt)
    measure(g, dt)
    if g.holding and dist(g.lx, g.ly, 0.5, 0.5, g.ky) <= g.core and g.speed > g.speedLimit then
        g.rough = g.rough + (g.speed - g.speedLimit) * dt
    end
    for _, s in ipairs(g.spots) do
        if s.dirt > 0 and s.dirt < 1 and g.t - s.rubbed > 0.6 then
            s.dirt = math.min(1, s.dirt + g.regrow * dt)
        end
    end
end

score.scrub = function(g)
    return progress.scrub(g) * (1 - clamp(g.rough / 0.5, 0, 0.7))
end

progress.scrub = function(g)
    local dirt = 0
    for _, s in ipairs(g.spots) do dirt = dirt + s.dirt end
    return 1 - dirt / g.total
end

setup.extract = function(g)
    local n = g.opts.bullet and 1 or count(g, 2, 4)
    g.shards = {}
    for i = 1, n do
        local a = rand(g, 0, math.pi * 2)
        local cx = n == 1 and 0.5 or 0.5 + math.cos(i * 2.1) * 0.16
        local cy = n == 1 and 0.5 or 0.5 + math.sin(i * 2.1) * 0.1
        g.shards[i] = { x = cx, y = cy, dx = math.cos(a), dy = math.sin(a), pulled = 0 }
    end
    g.pullLength = 0.2
    g.lateral = scaled(g, 0.056)
    g.radius = scaled(g, 0.032)
    g.probeRadius = scaled(g, 0.026)
    g.probeNeed = g.opts.bullet and (1.0 + 0.6 * g.diff) or 0
    g.probe = 0
    g.maxSpeed = (0.9 - 0.35 * g.diff) * 1.4
    g.total, g.removed = n, 0
end

local function shardEnd(s, pull)
    return s.x + s.dx * (0.04 + pull), s.y + s.dy * (0.04 + pull)
end
Games.shardEnd = shardEnd

press.extract = function(g, x, y)
    g.holding = true
    g.lx, g.ly = x, y
    g.speed = 0
    if g.probe < g.probeNeed then return end
    for i, s in ipairs(g.shards) do
        local ex, ey = shardEnd(s, s.pulled)
        if dist(x, y, ex, ey, g.ky) <= g.radius then
            g.grab = i
            g.gx, g.gy = x - s.dx * s.pulled, y - s.dy * s.pulled
            return
        end
    end
    g.misses = g.misses + 1
end

move.extract = function(g, x, y)
    if not g.holding then return end
    g.moved = g.moved + dist(x, y, g.lx, g.ly, g.ky)
    g.lx, g.ly = x, y
    local s = g.grab and g.shards[g.grab]
    if not s then return end
    local px, py = x - g.gx, y - g.gy
    local along = px * s.dx + py * s.dy
    local ex, ey = s.dx, s.dy * g.ky
    local across = math.abs(px * -ey + py * g.ky * ex) / math.sqrt(ex * ex + ey * ey)
    if across > g.lateral then
        g.slips = g.slips + 1
        g.grab = nil
        return
    end
    s.pulled = clamp(along, 0, g.pullLength)
    if s.pulled >= g.pullLength then
        table.remove(g.shards, g.grab)
        g.grab = nil
        g.removed = g.removed + 1
        if g.removed >= g.total then g.done = true end
    end
end

release.extract = function(g)
    g.holding = false
    g.grab = nil
end

tick.extract = function(g, dt)
    measure(g, dt)
    if g.grab and g.speed > g.maxSpeed then
        g.slips = g.slips + 1
        g.grab = nil
    end
    if g.probe < g.probeNeed and g.holding then
        if dist(g.lx, g.ly, 0.5, 0.5, g.ky) <= g.probeRadius then
            g.probe = g.probe + dt
        else
            g.probe = math.max(0, g.probe - dt * 2)
        end
    end
end

score.extract = function(g)
    return progress.extract(g) - 0.1 * g.slips - 0.04 * g.misses
end

progress.extract = function(g)
    local partial = 0
    for _, s in ipairs(g.shards) do partial = partial + s.pulled / g.pullLength * 0.5 end
    return (g.removed + partial) / g.total
end

setup.saw = function(g)
    g.need = count(g, 10, 16)
    g.half = scaled(g, 0.035)
    g.drift, g.driftV = 0, 0
    g.wander = 0.12 + 0.18 * g.diff
    g.maxSpeed = 3.2 - 1.0 * g.diff
    g.strokes, g.wobble, g.travel = 0, 0, 0
end

function Games.blade(g, x)
    return x + g.drift
end

press.saw = function(g, x, y)
    if math.abs(Games.blade(g, x) - 0.5) <= g.half * 2 then
        g.holding = true
        g.lx, g.ly = x, y
        g.speed = 0
        g.side = g.side or (y < 0.5 and -1 or 1)
    else
        g.misses = g.misses + 1
    end
end

move.saw = function(g, x, y)
    if not g.holding then return end
    local step = dist(x, y, g.lx, g.ly, g.ky)
    g.lx, g.ly = x, y
    g.moved = g.moved + step
    g.travel = g.travel + step
    if math.abs(Games.blade(g, x) - 0.5) > g.half then g.wobble = g.wobble + step end
    if g.side < 0 and y >= 0.7 or g.side > 0 and y <= 0.3 then
        g.side = -g.side
        g.strokes = g.strokes + 1
        if g.strokes >= g.need then g.done = true end
    end
end

release.saw = function(g)
    if g.holding and not g.done then g.slips = g.slips + 1 end
    g.holding = false
end

tick.saw = function(g, dt)
    g.driftV = (g.driftV + rand(g, -1, 1) * g.wander * dt * 6) * math.max(0, 1 - dt * 1.5)
    g.drift = clamp(g.drift + g.driftV * dt, -0.15, 0.15)
    measure(g, dt)
    if g.holding and g.speed > g.maxSpeed then
        g.holding = false
        g.slips = g.slips + 1
        g.torn = g.t
    end
end

score.saw = function(g)
    local frac = g.travel > 0 and g.wobble / g.travel or 0
    return progress.saw(g) * (1 - clamp(frac * 1.5, 0, 0.8)) - 0.04 * g.slips
end

progress.saw = function(g)
    return g.strokes / g.need
end

function Games.target(g)
    return 0.5 + math.cos(g.t * 0.9) * g.orbit, 0.5 + math.sin(g.t * 1.3) * g.orbit * 0.7
end

setup.hold = function(g)
    g.radius = scaled(g, 0.07)
    g.need = 3 + g.diff
    g.orbit = 0.03 + 0.05 * g.diff
    g.held, g.burnt, g.ox, g.oy = 0, 0, 0, 0
    g.nextKick = rand(g, 0.5, 1.2)
end

press.hold = function(g, x, y)
    g.holding = true
    g.lx, g.ly = x, y
end

move.hold = function(g, x, y)
    g.lx, g.ly = x, y
end

release.hold = function(g)
    g.holding = false
end

tick.hold = function(g, dt)
    g.ox, g.oy = g.ox * math.max(0, 1 - dt * 2.5), g.oy * math.max(0, 1 - dt * 2.5)
    g.nextKick = g.nextKick - dt
    if g.nextKick <= 0 then
        local a = rand(g, 0, math.pi * 2)
        local k = 0.05 + 0.07 * g.diff
        g.ox, g.oy = g.ox + math.cos(a) * k, g.oy + math.sin(a) * k
        g.nextKick = rand(g, 0.6, 1.4)
    end
    if not g.holding or not g.lx then return end
    local cx, cy = Games.target(g)
    if dist(g.lx + g.ox, g.ly + g.oy, cx, cy, g.ky) <= g.radius then
        g.held = g.held + dt
        if g.held >= g.need then g.done = true end
    else
        g.burnt = g.burnt + dt
    end
end

score.hold = function(g)
    return progress.hold(g) * (1 - clamp(g.burnt / 1.5, 0, 0.8))
end

progress.hold = function(g)
    return clamp(g.held / g.need, 0, 1)
end

function Games.vein(g, x)
    return 0.5 + math.sin(x * 7 + g.bend) * 0.025 + math.sin(g.t * 2.3) * g.roll
end

setup.inject = function(g)
    g.bend = rand(g, 0, math.pi * 2)
    g.roll = 0.004 + 0.008 * g.diff
    g.tx = rand(g, 0.32, 0.5)
    g.radius = scaled(g, 0.024)
    g.settle = 0.5
    g.push = 0.16
    g.maxSpeed = 0.32 - 0.12 * g.diff
    g.inside, g.pushed, g.attempts, g.wobble = 0, 0, 0, 0
    g.maxAttempts = 3
end

local function blown(g)
    g.holding = false
    g.phase = nil
    g.attempts = g.attempts + 1
    g.blownAt = g.t
    if g.attempts >= g.maxAttempts then g.done = true end
end

press.inject = function(g, x, y)
    g.lx, g.ly = x, y
    if dist(x, y, g.tx, Games.vein(g, g.tx), g.ky) <= g.radius then
        g.holding = true
        g.phase = "in"
        g.inside, g.pushed, g.speed = 0, 0, 0
    else
        blown(g)
    end
end

move.inject = function(g, x, y)
    if g.holding then g.moved = g.moved + math.abs(x - (g.lx or x)) end
    g.lx, g.ly = x, y
end

release.inject = function(g)
    if g.holding and not g.done then blown(g) end
    g.holding = false
end

tick.inject = function(g, dt)
    measure(g, dt)
    if not g.holding then return end
    if g.phase == "in" then
        local d = dist(g.lx, g.ly, g.tx, Games.vein(g, g.tx), g.ky)
        if d > g.radius * 1.8 then return blown(g) end
        g.wobble = g.wobble + d / g.radius * dt
        g.inside = g.inside + dt
        if g.inside >= g.settle then
            g.phase = "push"
            g.px = g.lx
        end
        return
    end
    if math.abs(g.ly - Games.vein(g, g.tx)) * g.ky > g.radius * 2 or g.speed > g.maxSpeed then return blown(g) end
    g.pushed = clamp((g.lx - g.px) / g.push, 0, 1)
    if g.pushed >= 1 then
        g.success = true
        g.holding = false
        g.done = true
    end
end

score.inject = function(g)
    if not g.success then return 0 end
    return 1 - 0.22 * g.attempts - clamp(g.wobble * 0.3, 0, 0.35)
end

progress.inject = function(g)
    if g.success then return 1 end
    if g.phase == "push" then return 0.5 + 0.5 * g.pushed end
    if g.phase == "in" then return 0.5 * g.inside / g.settle end
    return 0
end

Games.kinds = { "connect", "snip", "wrap", "scrub", "extract", "saw", "hold", "inject" }

function Games.new(kind, opts)
    opts = opts or {}
    local g = {
        kind = kind,
        opts = opts,
        diff = clamp(opts.diff or 0.5, 0, 1),
        ky = opts.ky or 1,
        rand = opts.rand or defaultRand,
        limit = opts.limit or 30,
        t = 0,
        misses = 0,
        slips = 0,
        moved = 0,
        speed = 0,
        done = false,
        holding = false,
    }
    setup[kind](g)
    return g
end

function Games.press(g, x, y)
    if g.done then return end
    press[g.kind](g, x, y)
end

function Games.move(g, x, y)
    if g.done or not move[g.kind] then return end
    move[g.kind](g, x, y)
end

function Games.release(g, x, y)
    if g.done or not release[g.kind] then return end
    release[g.kind](g, x, y)
end

function Games.tick(g, dt)
    if g.done then return end
    g.t = g.t + dt
    if tick[g.kind] then tick[g.kind](g, dt) end
    if g.t >= g.limit then
        g.done = true
        g.timedOut = true
    end
end

function Games.faults(g)
    return g.misses + g.slips + (g.attempts or 0)
end

local LOOSE = { "radius", "tolerance", "half", "reach", "lateral", "probeRadius", "maxSpeed", "minSpeed", "speedLimit" }

function Games.loosen(g, k)
    g.base = g.base or {}
    for _, f in ipairs(LOOSE) do
        if g[f] then
            g.base[f] = g.base[f] or g[f]
            g[f] = g.base[f] * k
        end
    end
end

function Games.progress(g)
    return clamp(progress[g.kind](g), 0, 1)
end

function Games.quality(g)
    return clamp(score[g.kind](g), 0, 1)
end
