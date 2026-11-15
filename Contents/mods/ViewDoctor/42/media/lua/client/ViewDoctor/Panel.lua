require "ISUI/ISUIElement"
require "ViewDoctor/Games"
require "ViewDoctor/Surface"
require "ViewDoctor/Scene"

local G = ViewDoctor.Games
local Surface = ViewDoctor.Surface
local Scene = ViewDoctor.Scene
local clamp = G.clamp

local Panel = ISUIElement:derive("ViewDoctorPanel")
ViewDoctor.Panel = Panel

local C = {
    ink = { 0.03, 0.02, 0.02 },
    skin = { 0.86, 0.66, 0.54 },
    skinDark = { 0.62, 0.42, 0.33 },
    skinLight = { 1.0, 0.86, 0.76 },
    wound = { 0.62, 0.05, 0.05 },
    woundDeep = { 0.22, 0.0, 0.01 },
    blood = { 0.45, 0.02, 0.03 },
    thread = { 0.96, 0.92, 0.82 },
    steel = { 0.82, 0.85, 0.9 },
    gold = { 1.0, 0.76, 0.28 },
    green = { 0.42, 0.95, 0.55 },
    bad = { 1.0, 0.28, 0.2 },
    cloth = { 0.97, 0.96, 0.92 },
    clothShade = { 0.78, 0.76, 0.7 },
    dirt = { 0.36, 0.25, 0.12 },
    glass = { 0.72, 0.92, 1.0 },
    vein = { 0.32, 0.42, 0.85 },
    hot = { 1.0, 0.5, 0.12 },
    text = { 0.97, 0.95, 0.9 },
    soft = { 0.75, 0.72, 0.68 },
}

local ARC = 28
local TEX = {}

local function tex(name)
    local t = TEX[name]
    if t == nil then
        t = getTexture("media/ui/ViewDoctor/" .. name .. ".png") or false
        TEX[name] = t
    end
    return t or nil
end

local function bridge(api, name, ...)
    if api == nil or api[name] == nil then return nil end
    local ok, v = pcall(api[name], ...)
    if ok then return v end
    return nil
end

local function pose(name)
    return bridge(ViewDoctorPose, name)
end

local function props(name, ...)
    return bridge(ViewDoctorProps, name, ...)
end

local function posed(name, ...)
    return bridge(ViewDoctorPose, name, ...)
end

function Panel:quad(t, x1, y1, x2, y2, x3, y3, x4, y4, c, a)
    self.javaObject:DrawTexture(t, x1, y1, x2, y2, x3, y3, x4, y4, c[1], c[2], c[3], a)
end

function Panel:box(x, y, w, h, c, a)
    self:drawRect(x, y, w, h, a, c[1], c[2], c[3])
end

function Panel:line(x1, y1, x2, y2, w, c, a)
    local dx, dy = x2 - x1, y2 - y1
    local l = math.sqrt(dx * dx + dy * dy)
    if l < 0.01 then return end
    local nx, ny = -dy / l * w / 2, dx / l * w / 2
    self:quad(nil, x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny, c, a)
end

function Panel:stroke(x1, y1, x2, y2, w, c, a)
    self:line(x1, y1, x2, y2, w, c, a)
    self:sprite("dot", x1, y1, w / 2, c, a)
    self:sprite("dot", x2, y2, w / 2, c, a)
end

local function sized(name, r)
    if r > 48 then return name .. "_big" end
    return name
end

function Panel:sprite(name, x, y, r, c, a)
    local t = tex(sized(name, r))
    if t then self.javaObject:DrawTextureScaledColor(t, x - r, y - r, r * 2, r * 2, c[1], c[2], c[3], a) end
end

function Panel:skin(t, x1, y1, x2, y2, x3, y3, x4, y4, c, a, sh)
    local f, k = 1, 1
    if sh then f, k = 0.5 + 0.5 * sh, 0.6 + 0.4 * sh end
    self.javaObject:DrawTexture(t, x1, y1, x2, y2, x3, y3, x4, y4, c[1] * f, c[2] * f, c[3] * f, a * k)
end

function Panel:ribbon(x1, y1, x2, y2, hw, c, a)
    local dx, dy = x2 - x1, y2 - y1
    local l = math.sqrt(dx * dx + dy * dy)
    if l < 1e-4 then return end
    local ox, oy = -dy / l * hw, dx / l * hw
    local segs = math.max(1, math.ceil(math.abs(dy) * 10))
    local s = self.surf
    local px, py, qx, qy
    for i = 0, segs do
        local x, y = x1 + dx * i / segs, y1 + dy * i / segs
        local ax, ay = Surface.map(s, x + ox, y + oy)
        local bx, by = Surface.map(s, x - ox, y - oy)
        if i > 0 then
            local _, _, sh = Surface.map(s, x - dx / segs / 2, y - dy / segs / 2)
            self:skin(nil, px, py, ax, ay, bx, by, qx, qy, c, a, sh)
        end
        px, py, qx, qy = ax, ay, bx, by
    end
end

function Panel:curve(x1, y1, x2, y2, w, c, a)
    local segs = math.max(1, math.ceil(math.abs(y2 - y1) * 8))
    local lx, ly = self:P(x1, y1)
    for i = 1, segs do
        local x, y = self:P(x1 + (x2 - x1) * i / segs, y1 + (y2 - y1) * i / segs)
        self:line(lx, ly, x, y, w, c, a)
        lx, ly = x, y
    end
end

function Panel:blob(name, x, y, rx, ry, c, a, unshaded)
    local t = tex(sized(name, self:S(math.max(rx, ry), x)))
    if not t then return end
    local s = self.surf
    local x1, y1 = Surface.map(s, x - rx, y - ry)
    local x2, y2 = Surface.map(s, x + rx, y - ry)
    local x3, y3 = Surface.map(s, x + rx, y + ry)
    local x4, y4 = Surface.map(s, x - rx, y + ry)
    self:skin(t, x1, y1, x2, y2, x3, y3, x4, y4, c, a, not unshaded and self:shade(x, y) or nil)
end

function Panel:arc(x, y, r, w, c, a, fill)
    local last = math.floor(ARC * clamp(fill or 1, 0, 1) + 0.5)
    local step = math.pi * 2 / ARC
    for i = 0, last - 1 do
        local a1, a2 = i * step - math.pi / 2, (i + 1) * step - math.pi / 2
        local c1, s1, c2, s2 = math.cos(a1), math.sin(a1), math.cos(a2), math.sin(a2)
        self:quad(nil, x + c1 * r, y + s1 * r, x + c2 * r, y + s2 * r, x + c2 * (r - w), y + s2 * (r - w), x + c1 * (r - w), y + s1 * (r - w), c, a)
    end
end

function Panel:P(x, y)
    if self.props then
        if posed("show", x, y) == true then return pose("sx"), pose("sy") end
        return -9999, -9999
    end
    local sx, sy = Surface.map(self.surf, x, y)
    return sx, sy
end

function Panel:S(n, x)
    if self.props then return n * (self.along or 300) end
    return Surface.size(self.surf, x or 0.5, n)
end

function Panel:measure()
    local ax, ay = self:P(0, 0.5)
    local bx, by = self:P(1, 0.5)
    if ax < -9000 or bx < -9000 then return end
    local l = math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
    if l > 1 then self.along = l end
end

function Panel:shade(x, y)
    local _, _, sh = Surface.map(self.surf, x, y)
    return sh
end

function Panel:toLocal(mx, my)
    return Surface.unmap(self.surf, mx, my)
end

function Panel:tremor(t)
    local a = self.amp
    return a * (math.sin(t * 7.3) * 0.6 + math.sin(t * 12.9 + 1.3) * 0.4),
        a * (math.sin(t * 8.1 + 0.7) * 0.6 + math.sin(t * 11.3 + 2.1) * 0.4)
end

function Panel:refreshTip()
    local mx, my
    if self.props then
        posed("cursor", getMouseX(), getMouseY())
        mx, my = pose("lx"), pose("ly")
    end
    if not (mx and my) then mx, my = self:toLocal(getMouseX(), getMouseY()) end
    local ox, oy = self:tremor(self.clock)
    local x, y = mx + ox, my + oy
    local dx, dy = x - (self.tipX or x), y - (self.tipY or y)
    local l = math.sqrt(dx * dx + dy * dy)
    if l > 0.002 then
        self.dirX = self.dirX + (dx / l - self.dirX) * 0.25
        self.dirY = self.dirY + (dy / l - self.dirY) * 0.25
    end
    self.tipX, self.tipY = x, y
end

local function fit(t, w, h)
    local cx, cy = (t[1] + t[3]) / 2, (t[2] + t[4]) / 2
    local dx, dy = t[3] - t[1], t[4] - t[2]
    local l = math.sqrt(dx * dx + dy * dy)
    local k = l > h * 0.6 and h * 0.6 / l or 1
    dx, dy, l = dx * k, dy * k, l * k
    local ux, uy = 1, 0
    if l > 1e-3 then ux, uy = dx / l, dy / l end
    local len = math.max(l, h * 0.3)
    local wide = math.max(t[5] * k, t[6] * k, 0.22 * h * 0.3)
    local ex = math.abs(ux) * len / 2 + math.abs(uy) * wide
    local ey = math.abs(uy) * len / 2 + math.abs(ux) * wide
    cx = clamp(cx, ex, w - ex)
    cy = clamp(cy, ey + h * 0.12, h - ey)
    return { cx - dx / 2, cy - dy / 2, cx + dx / 2, cy + dy / 2, t[5] * k, t[6] * k }
end

function Panel:limbTarget()
    if not self.follow or pose("seen") ~= true then return nil end
    local ax, ay, bx, by, wa, wb = pose("ax"), pose("ay"), pose("bx"), pose("by"), pose("wa"), pose("wb")
    if not (ax and ay and bx and by and wa and wb) then return nil end
    if self.flip == nil then self.flip = math.abs(math.atan2(by - ay, bx - ax)) > math.pi / 2 end
    if self.flip then ax, ay, bx, by, wa, wb = bx, by, ax, ay, wb, wa end
    return { ax, ay, bx, by, wa, wb }
end

function Panel:place(dt)
    local core = getCore()
    local w, h = core:getScreenWidth(), core:getScreenHeight()
    if w ~= self.width or h ~= self.height then
        self:setWidth(w)
        self:setHeight(h)
    end
    if self.held and self.placed then return end
    local t = self:limbTarget()
    local onLimb = t ~= nil
    if onLimb then
        self.seenAt = self.clock
        t = fit(t, w, h)
    elseif self.onLimb and self.clock - (self.seenAt or 0) < 0.6 then
        return
    else
        local L = math.min(w, h) * 0.5
        t = { w / 2 - L / 2, h / 2, w / 2 + L / 2, h / 2, L * 0.24, L * 0.24 }
    end
    if not self.placed or onLimb ~= self.onLimb then
        self.cur = t
        self.placed = true
    else
        local k = math.min(1, dt * 9)
        for i = 1, 6 do self.cur[i] = self.cur[i] + (t[i] - self.cur[i]) * k end
    end
    self.onLimb = onLimb
    local c = self.cur
    local s = Surface.new(c[1], c[2], c[3], c[4], c[5], c[6], self.flat, h * 0.3)
    self.surf = s
    self.game.ky = Surface.aspect(s)
    if self.props then
        self.game.ky = pose("aspect") or self.game.ky
        self.game.len = pose("span") or self.game.len
    end
    self.cx, self.cy = s.ax + s.ux * s.len / 2, s.ay + s.uy * s.len / 2
    self.side = s.len
    self.cos, self.sin = s.ux, s.uy
end

function Panel:step()
    local now = getTimestampMs()
    local dt = clamp((now - self.lastMs) / 1000, 0, 0.1)
    self.lastMs = now
    self:place(dt)
    if self.closed or (isGamePaused and isGamePaused()) then return end
    self.clock = self.clock + dt
    self:refreshTip()
    local g = self.game
    if g.done then return end
    local shown = self.props and self.along or self.surf.len
    if shown and shown > 1 then G.loosen(g, clamp(math.min(self.width, self.height) * 0.5 / shown, 1, 3)) end
    G.move(g, self.tipX, self.tipY)
    G.tick(g, dt)
    local faults = G.faults(g)
    if faults > self.faults then
        self.faults = faults
        self.hurt = 1
        self.hurtX, self.hurtY = self.tipX, self.tipY
    end
    local progress = G.progress(g)
    if progress > self.progress + 0.001 then
        self.spark = 1
        self.sparkX, self.sparkY = self.tipX, self.tipY
    end
    self.progress = progress
    self.hurt = math.max(0, self.hurt - dt * 2.5)
    self.spark = math.max(0, self.spark - dt * 3)
end

function Panel:update()
    ISUIElement.update(self)
    if not self.closed and self.game.done then self:finish(false) end
end

function Panel:onMouseDown()
    self.held = true
    self:refreshTip()
    G.press(self.game, self.tipX, self.tipY)
    return true
end

function Panel:onMouseUp()
    self.held = false
    G.release(self.game, self.tipX, self.tipY)
    return true
end

function Panel:onMouseUpOutside()
    return self:onMouseUp()
end

function Panel:onRightMouseDown()
    self:finish(true)
    return true
end

function Panel:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function Panel:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:finish(true) end
end

function Panel:finish(cancelled)
    if self.closed then return end
    local quality = G.quality(self.game)
    self:close()
    self.onDone(cancelled, quality, self.game)
end

function Panel:flatten()
    if not self.props then return end
    self.props = false
    self.shown = nil
    props("close")
    posed("rest")
    self.placed = false
    self:place(0)
end

function Panel:watch()
    if not self.props then return end
    if pose("seen") == true then self.propsSeen = self.clock end
    if props("working") ~= true or pose("firstPerson") ~= true or self.clock - (self.propsSeen or self.clock) > 0.6 then
        self:flatten()
    end
end

function Panel:stage()
    local built, list, tool = pcall(Scene.build, self.game, self.tipX, self.tipY)
    if not built then return self:flatten() end
    local ok, shown = pcall(Scene.sync, list, tool, self.shown)
    if not ok then return self:flatten() end
    self.shown = shown
    if tool then posed("tool", self.tipX, self.tipY) else posed("rest") end
end

function Panel:close()
    if self.closed then return end
    self.closed = true
    if self.props then
        self.props = false
        props("close")
    end
    self:setCapture(false)
    self:removeFromUIManager()
    if Panel.instance == self then Panel.instance = nil end
end

function Panel:limb()
    local s = self.surf
    local bands = 12
    for i = 0, bands - 1 do
        local y0, y1 = i / bands, (i + 1) / bands
        local x1, y1a = Surface.map(s, 0, y0)
        local x2, y2a = Surface.map(s, 1, y0)
        local x3, y3a = Surface.map(s, 1, y1)
        local x4, y4a = Surface.map(s, 0, y1)
        local f = 0.45 + 0.55 * self:shade(0.5, (y0 + y1) / 2)
        self.javaObject:DrawTexture(nil, x1, y1a, x2, y2a, x3, y3a, x4, y4a, C.skin[1] * f, C.skin[2] * f, C.skin[3] * f, 1)
    end
    self:ribbon(0, 0.38, 1, 0.38, 0.06, C.skinLight, 0.4)
end

function Panel:backdrop()
    if self.onLimb then return end
    local s = self.surf
    local r = math.min(math.max(s.len / 2, s.wa, s.wb) * 2, self.cx, self.cy, self.width - self.cx, self.height - self.cy)
    for _ = 1, 3 do self:sprite("glow", self.cx, self.cy, r, C.ink, 0.85) end
    if self.hurt > 0 then self:sprite("glow", self.cx, self.cy, r * 0.8, C.bad, 0.3 * self.hurt) end
    self:limb()
end

function Panel:prerender()
    self:step()
    self:watch()
    if self.props then
        if not self.closed then self:stage() end
    elseif self.placed then
        self:backdrop()
    end
end

local function glowDot(p, x, y, r, c, a)
    p:sprite("glow", x, y, r * 3, c, 0.35 * a)
    p:sprite("dot", x, y, r, c, a)
end

local function marker(p, x, y, r, c)
    local pulse = 0.5 + 0.5 * math.sin(p.clock * 6)
    p:sprite("glow", x, y, r * (2.6 + pulse * 0.6), c, 0.3 + 0.2 * pulse)
    p:sprite("ring", x, y, r * (1 + pulse * 0.12), c, 0.95)
    p:sprite("dot", x, y, r * 0.32, c, 1)
end

local function gash(p, x1, y1, x2, y2, hw)
    p:ribbon(x1, y1, x2, y2, hw * 1.9, C.blood, 0.55)
    p:ribbon(x1, y1, x2, y2, hw, C.wound, 0.85)
    p:ribbon(x1, y1, x2, y2, hw * 0.4, C.woundDeep, 0.85)
end

local draw = {}
local guide = {}

draw.connect = function(p, g)
    local wy = 0.5 + g.sway
    gash(p, 0.16, wy, 0.84, wy, 0.035)
    for i = 1, g.at - 1 do
        local x1, y1 = p:P(G.point(g, i))
        local x2, y2 = p:P(G.point(g, i + 1))
        p:line(x1, y1, x2, y2, 5, C.ink, 0.45)
        p:line(x1, y1, x2, y2, 3, C.thread, 1)
    end
    if g.holding and g.at >= 1 then
        local x1, y1 = p:P(G.point(g, g.at))
        local x2, y2 = p:P(p.tipX, p.tipY)
        p:line(x1, y1, x2, y2, 2, C.thread, 0.8)
        local nx, ny = G.point(g, g.at + 1)
        local cx, cy = G.point(g, g.at)
        local mx = cx + (nx - cx) * 0.5
        local qx, qy = p:P(mx, cy + (ny - cy) * 0.5)
        local tol = p:S(g.tolerance * 2.5, mx)
        p:line(x1, y1, qx, qy, tol * 2, C.gold, 0.06)
    end
    for i = 1, g.total do
        local gx, gy = G.point(g, i)
        local x, y = p:P(gx, gy)
        local r = p:S(g.radius, gx)
        if i <= g.at then
            glowDot(p, x, y, r * 0.3, C.green, 1)
        elseif i == math.max(g.at, 1) or i == g.at + 1 then
            marker(p, x, y, r, C.gold)
        else
            p:sprite("dot", x, y, r * 0.22, C.thread, 0.7)
        end
    end
end

draw.snip = function(p, g)
    gash(p, 0.16, 0.5, 0.84, 0.5, 0.014)
    for i, k in ipairs(g.knots) do
        local x, y = p:P(k.x, k.y)
        local r = p:S(g.radius, k.x)
        local s = r * 0.7
        local ux, uy = p.cos * s, p.sin * s
        local vx, vy = -p.sin * s, p.cos * s
        p:line(x - ux - vx, y - uy - vy, x + ux + vx, y + uy + vy, 3, C.thread, 1)
        p:line(x - ux + vx, y - uy + vy, x + ux - vx, y + uy - vy, 3, C.thread, 1)
        if i == 1 then
            local tight = G.tight(g, k)
            local cyc = G.cycle(g, k)
            local c = tight and C.green or C.gold
            p:sprite("ring", x, y, r * (1 + (1 - cyc) * 2.2), c, 0.9)
            p:sprite("ring", x, y, r, c, tight and 0.9 or 0.35)
            if tight then p:sprite("glow", x, y, r * 2.5, C.green, 0.35) end
        else
            p:sprite("ring", x, y, r * 0.8, C.thread, 0.25)
        end
    end
end

draw.wrap = function(p, g)
    p:blob("dot", 0.5, 0.5, 0.13, 0.1, C.blood, 0.6)
    p:blob("dot", 0.5, 0.5, 0.1, 0.06, C.wound, 0.85)
    for i, lane in ipairs(g.lanes) do
        local wrapped = i < g.lane
        if g.opts.reverse then wrapped = not wrapped end
        if wrapped then
            p:ribbon(lane.x, 0, lane.x, 1, g.half + 0.006, C.clothShade, 0.85)
            p:ribbon(lane.x, 0, lane.x, 1, g.half, i % 2 == 0 and C.clothShade or C.cloth, 0.85)
        end
    end
    local lane = g.lanes[g.lane]
    if not lane then return end
    p:curve(lane.x - g.half, lane.from, lane.x - g.half, lane.to, 2, C.gold, 0.6)
    p:curve(lane.x + g.half, lane.from, lane.x + g.half, lane.to, 2, C.gold, 0.6)
    local sx, sy = p:P(lane.x, lane.from)
    local ex, ey = p:P(lane.x, lane.to)
    p:sprite("ring", ex, ey, p:S(g.radius, lane.x) * 0.7, C.gold, 0.4)
    if g.holding then
        local hx, hy = clamp(p.tipX, 0, 1), p.tipY
        local fast = g.speed > g.maxSpeed or g.speed < g.minSpeed and g.grip > 0.2
        p:ribbon(lane.x, lane.from, hx, hy, g.half, C.cloth, 0.85)
        local px, py = p:P(hx, hy)
        p:sprite("glow", px, py, p:S(g.half, hx) * 2.2, fast and C.bad or C.green, 0.45)
    else
        marker(p, sx, sy, p:S(g.radius, lane.x), C.gold)
    end
end

draw.scrub = function(p, g)
    p:blob("glow", 0.5, 0.5, g.core * 2.2, g.core * 1.6, C.blood, 0.55)
    p:blob("dot", 0.5, 0.5, g.core, g.core * 0.7, C.wound, 0.85)
    p:blob("dot", 0.5, 0.5, g.core * 0.5, g.core * 0.32, C.woundDeep, 0.85)
    for _, s in ipairs(g.spots) do
        if s.dirt > 0 then
            local r = 0.045 * s.size
            p:blob("glow", s.x, s.y, r * 1.8, r * 1.8, C.dirt, 0.5 * s.dirt)
            local k = r * (0.5 + 0.5 * s.dirt)
            p:blob("dot", s.x, s.y, k, k, C.dirt, 0.25 + 0.6 * s.dirt)
        end
    end
    local rough = g.holding and G.dist(g.lx, g.ly, 0.5, 0.5, g.ky) <= g.core and g.speed > g.speedLimit
    p:blob("glow", p.tipX, p.tipY, g.reach * 1.6, g.reach * 1.6, rough and C.bad or C.cloth, g.holding and 0.5 or 0.2, true)
    p:blob("ring", p.tipX, p.tipY, g.reach, g.reach, C.cloth, g.holding and 0.95 or 0.45, true)
end

draw.extract = function(p, g)
    local x, y = p:P(0.5, 0.5)
    p:blob("glow", 0.5, 0.5, 0.16, 0.16, C.blood, 0.6)
    p:blob("dot", 0.5, 0.5, 0.06, 0.06, C.wound, 0.85)
    if g.probe < g.probeNeed then
        local r = p:S(g.probeRadius)
        marker(p, x, y, r, C.gold)
        p:arc(x, y, r + 12, 4, C.green, 0.9, g.probe / g.probeNeed)
    end
    local bullet = g.opts.bullet
    for i, s in ipairs(g.shards) do
        local ex, ey = G.shardEnd(s, s.pulled)
        local bx, by = ex - s.dx * 0.07, ey - s.dy * 0.07
        local x1, y1 = p:P(bx, by)
        local x2, y2 = p:P(ex, ey)
        if bullet then
            p:stroke(x1, y1, x2, y2, p:S(0.03, ex), C.ink, 0.6)
            p:stroke(x1, y1, x2, y2, p:S(0.024, ex), { 0.72, 0.55, 0.28 }, 1)
        else
            p:line(x1, y1, x2, y2, 6, C.ink, 0.4)
            p:line(x1, y1, x2, y2, 4, C.glass, 0.95)
            p:sprite("glow", x2, y2, p:S(0.02, ex), C.glass, 0.6)
        end
        if g.probe >= g.probeNeed then
            local c = g.grab == i and C.green or C.gold
            if g.grab == i then
                p:sprite("ring", x2, y2, p:S(g.radius, ex), c, 0.9)
            else
                marker(p, x2, y2, p:S(g.radius, ex), c)
            end
            if g.diff < 0.5 then
                local tx, ty = p:P(G.shardEnd(s, g.pullLength))
                p:line(x2, y2, tx, ty, 1, C.gold, 0.3)
            end
        end
    end
end

draw.saw = function(p, g)
    p:ribbon(0.5, 0.18, 0.5, 0.82, g.half, C.gold, 0.12)
    p:curve(0.5, 0.18, 0.5, 0.82, 3, C.wound, 0.9)
    local cut = g.strokes / g.need
    if cut > 0 then gash(p, 0.5, 0.5 - 0.32 * cut, 0.5, 0.5 + 0.32 * cut, 0.02) end
    for _, m in ipairs({ { 0.3, -1 }, { 0.7, 1 } }) do
        local x1, y1 = p:P(0.42, m[1])
        local x2, y2 = p:P(0.58, m[1])
        local want = g.side and g.side == m[2]
        p:line(x1, y1, x2, y2, 3, want and C.gold or C.soft, want and 1 or 0.4)
    end
    local blade = G.blade(g, p.tipX)
    local off = math.abs(blade - 0.5) > g.half
    local x1, y1 = p:P(blade, p.tipY - 0.13)
    local x2, y2 = p:P(blade, p.tipY + 0.13)
    p:line(x1, y1, x2, y2, 9, C.ink, 0.5)
    p:line(x1, y1, x2, y2, 6, off and C.bad or C.steel, 0.95)
    local hx, hy = p:P(blade, p.tipY)
    p:sprite("dot", hx, hy, 5, C.text, 1)
end

draw.hold = function(p, g)
    local cx, cy = G.target(g)
    local x, y = p:P(cx, cy)
    local gr = g.radius
    p:blob("glow", cx, cy, gr * 2.2, gr * 2.2, C.blood, 0.7)
    p:blob("dot", cx, cy, gr * 1.1, gr * 1.1, C.wound, 0.85)
    p:blob("dot", cx, cy, gr * 0.55, gr * 0.55, C.woundDeep, 0.85)
    local r = p:S(gr, cx)
    p:sprite("ring", x, y, r, C.gold, 0.9)
    p:arc(x, y, r + 14, 5, C.green, 0.9, g.held / g.need)
    local tx = p.tipX + g.ox
    local hx, hy = p:P(tx, p.tipY + g.oy)
    local heat = g.holding and 1 or 0.45
    p:sprite("glow", hx, hy, p:S(0.06, tx), C.hot, 0.6 * heat)
    p:sprite("dot", hx, hy, p:S(0.018, tx), { 1, 0.9, 0.6 }, heat)
end

draw.inject = function(p, g)
    local lx, ly
    for i = 0, 16 do
        local vx = 0.08 + 0.84 * i / 16
        local vy = G.vein(g, vx)
        if lx then
            p:ribbon(lx, ly, vx, vy, 0.034, C.vein, 0.35)
            p:ribbon(lx, ly, vx, vy, 0.018, C.vein, 0.7)
        end
        lx, ly = vx, vy
    end
    local tx, ty = p:P(g.tx, G.vein(g, g.tx))
    local r = p:S(g.radius, g.tx)
    if g.phase == "push" then
        local hx, hy = p:P(p.tipX, p.tipY)
        local ex, ey = p:P(g.px + g.push, G.vein(g, g.tx))
        p:line(tx, ty, ex, ey, 2, C.gold, 0.35)
        p:sprite("ring", ex, ey, r, C.gold, 0.6)
        p:line(tx, ty, hx, hy, 4, C.steel, 0.9)
        p:arc(tx, ty, r + 10, 4, C.green, 0.9, g.pushed)
    elseif g.phase == "in" then
        p:sprite("ring", tx, ty, r * 1.8, C.green, 0.5)
        p:arc(tx, ty, r + 10, 4, C.green, 0.9, g.inside / g.settle)
    else
        marker(p, tx, ty, r, C.gold)
    end
    for i = 1, g.maxAttempts do
        local x, y = p:P(0.1 + i * 0.05, 0.12)
        p:sprite("dot", x, y, 5, i <= g.maxAttempts - g.attempts and C.gold or C.soft, i <= g.maxAttempts - g.attempts and 1 or 0.3)
    end
end

guide.connect = function(p, g)
    for i = math.max(g.at, 1), g.total do
        local gx, gy = G.point(g, i)
        local x, y = p:P(gx, gy)
        local r = p:S(g.radius, gx)
        if i == g.at and g.holding then
            glowDot(p, x, y, r * 0.3, C.green, 1)
        elseif i == math.max(g.at, 1) or i == g.at + 1 then
            marker(p, x, y, r, i == g.at + 1 and g.holding and C.green or C.gold)
        else
            p:sprite("ring", x, y, r * 0.5, C.thread, 0.5)
        end
    end
end

guide.snip = function(p, g)
    for i, k in ipairs(g.knots) do
        local x, y = p:P(k.x, k.y)
        local r = p:S(g.radius, k.x)
        if i == 1 then
            local tight = G.tight(g, k)
            local c = tight and C.green or C.gold
            p:sprite("ring", x, y, r * (1 + (1 - G.cycle(g, k)) * 2.2), c, 0.9)
            p:sprite("ring", x, y, r, c, tight and 0.9 or 0.45)
            if tight then p:sprite("glow", x, y, r * 2.5, C.green, 0.35) end
        else
            p:sprite("ring", x, y, r * 0.8, C.thread, 0.3)
        end
    end
end

guide.wrap = function(p, g)
    local lane = g.lanes[g.lane]
    if not lane then return end
    local sx, sy = p:P(lane.x, lane.from)
    local ex, ey = p:P(lane.x, lane.to)
    local r = p:S(g.radius, lane.x)
    local lx, ly = sx, sy
    for i = 1, 6 do
        local x, y = p:P(lane.x, lane.from + (lane.to - lane.from) * i / 6)
        p:line(lx, ly, x, y, 3, C.gold, 0.55)
        lx, ly = x, y
    end
    p:sprite("ring", ex, ey, r * 0.7, C.gold, 0.6)
    if g.holding then
        local fast = g.speed > g.maxSpeed or g.speed < g.minSpeed and g.grip > 0.2
        local hx, hy = p:P(clamp(p.tipX, 0, 1), p.tipY)
        p:sprite("ring", sx, sy, r * 0.5, C.green, 0.6)
        p:sprite("glow", hx, hy, r * 1.6, fast and C.bad or C.green, 0.5)
    else
        marker(p, sx, sy, r, C.gold)
    end
end

guide.scrub = function(p, g, mx, my)
    for _, s in ipairs(g.spots) do
        if s.dirt > 0 then
            local x, y = p:P(s.x, s.y)
            p:sprite("ring", x, y, p:S(0.045 * s.size, s.x), C.gold, 0.25 + 0.5 * s.dirt)
        end
    end
    local rough = g.holding and G.dist(g.lx, g.ly, 0.5, 0.5, g.ky) <= g.core and g.speed > g.speedLimit
    p:sprite("ring", mx, my, p:S(g.reach), rough and C.bad or C.cloth, g.holding and 0.95 or 0.5)
end

guide.extract = function(p, g)
    if g.probe < g.probeNeed then
        local x, y = p:P(0.5, 0.5)
        local r = p:S(g.probeRadius)
        marker(p, x, y, r, C.gold)
        p:arc(x, y, r + 12, 4, C.green, 0.9, g.probe / g.probeNeed)
        return
    end
    for i, s in ipairs(g.shards) do
        local ex, ey = G.shardEnd(s, s.pulled)
        local x, y = p:P(ex, ey)
        local r = p:S(g.radius, ex)
        if g.grab == i then
            p:sprite("ring", x, y, r, C.green, 0.9)
            local tx, ty = p:P(G.shardEnd(s, g.pullLength))
            p:line(x, y, tx, ty, 2, C.green, 0.5)
            p:sprite("ring", tx, ty, r * 0.6, C.green, 0.6)
        else
            marker(p, x, y, r, C.gold)
        end
    end
end

guide.saw = function(p, g, mx, my)
    local lx, ly = p:P(0.5, 0.18)
    for i = 1, 6 do
        local x, y = p:P(0.5, 0.18 + 0.64 * i / 6)
        p:line(lx, ly, x, y, 3, C.wound, 0.8)
        lx, ly = x, y
    end
    for _, m in ipairs({ { 0.3, -1 }, { 0.7, 1 } }) do
        local x, y = p:P(0.5, m[1])
        local want = not g.side or g.side == m[2]
        p:sprite("ring", x, y, p:S(g.half * 2), want and C.gold or C.soft, want and 0.9 or 0.35)
    end
    if math.abs(G.blade(g, p.tipX) - 0.5) > g.half then p:sprite("ring", mx, my, 16, C.bad, 0.9) end
end

guide.hold = function(p, g)
    local cx, cy = G.target(g)
    local x, y = p:P(cx, cy)
    local r = p:S(g.radius, cx)
    p:sprite("ring", x, y, r, C.gold, 0.9)
    p:arc(x, y, r + 14, 5, C.green, 0.9, g.held / g.need)
end

guide.inject = function(p, g)
    local tx, ty = p:P(g.tx, G.vein(g, g.tx))
    local r = p:S(g.radius, g.tx)
    if g.phase == "push" then
        local ex, ey = p:P(g.px + g.push, G.vein(g, g.tx))
        p:line(tx, ty, ex, ey, 2, C.gold, 0.5)
        p:sprite("ring", ex, ey, r, C.gold, 0.7)
        p:arc(tx, ty, r + 10, 4, C.green, 0.9, g.pushed)
    elseif g.phase == "in" then
        p:sprite("ring", tx, ty, r * 1.8, C.green, 0.6)
        p:arc(tx, ty, r + 10, 4, C.green, 0.9, g.inside / g.settle)
    else
        marker(p, tx, ty, r, C.gold)
    end
    for i = 1, g.maxAttempts do
        local left = i <= g.maxAttempts - g.attempts
        p:sprite("dot", p.width / 2 - 30 + i * 15, p.height * 0.16, 5, left and C.gold or C.soft, left and 1 or 0.3)
    end
end

local function tool(p, g)
    local x, y = p:P(p.tipX, p.tipY)
    if g.kind == "hold" or g.kind == "saw" or g.kind == "scrub" then return end
    if g.kind == "connect" then
        local dx = (p.dirX * p.cos - p.dirY * p.sin) * 18
        local dy = (p.dirX * p.sin + p.dirY * p.cos) * 18
        p:line(x - dx, y - dy, x + dx * 0.4, y + dy * 0.4, 3, C.steel, 1)
        p:sprite("dot", x, y, 3, C.text, 1)
        return
    end
    p:line(x - 8, y, x - 3, y, 2, C.text, 0.95)
    p:line(x + 3, y, x + 8, y, 2, C.text, 0.95)
    p:line(x, y - 8, x, y - 3, 2, C.text, 0.95)
    p:line(x, y + 3, x, y + 8, 2, C.text, 0.95)
    p:sprite("dot", x, y, 2, C.text, 1)
end

function Panel:hud()
    local g = self.game
    local w, h = self.width, self.height
    local cx = w / 2
    local top = math.floor(h * 0.06)
    local fm = getTextManager():getFontHeight(UIFont.Medium)
    local fs = getTextManager():getFontHeight(UIFont.Small)
    local tm = getTextManager()
    local barW = math.floor(math.min(w * 0.32, 520))
    local boxW = math.max(barW, tm:MeasureStringX(UIFont.Medium, self.title), tm:MeasureStringX(UIFont.Small, self.help)) + 36
    self:box(cx - boxW / 2, top - 10, boxW, fm + fs + 44, C.ink, 0.55)
    self:drawTextCentre(self.title, cx + 1, top + 1, 0, 0, 0, 0.8, UIFont.Medium)
    self:drawTextCentre(self.title, cx, top, C.text[1], C.text[2], C.text[3], 1, UIFont.Medium)
    self:drawTextCentre(self.help, cx, top + fm + 4, C.soft[1], C.soft[2], C.soft[3], 1, UIFont.Small)
    local by = top + fm + fs + 14
    local x0 = cx - barW / 2
    local left = clamp(1 - g.t / g.limit, 0, 1)
    self:box(x0, by, barW, 4, C.soft, 0.18)
    self:box(x0, by, barW * self.progress, 4, C.green, 0.95)
    self:box(x0, by + 8, barW, 3, C.soft, 0.18)
    self:box(x0, by + 8, barW * left, 3, left > 0.25 and C.gold or C.bad, 0.95)
    self:drawTextCentre(self.stopText, cx, h - fs - math.floor(h * 0.04), C.soft[1], C.soft[2], C.soft[3], 0.85, UIFont.Small)
end

function Panel:pointer()
    local x, y = getMouseX(), getMouseY()
    local g = self.game
    self:measure()
    guide[g.kind](self, g, x, y)
    self:sprite("ring", x, y, g.holding and 9 or 12, C.text, 0.9)
    self:sprite("dot", x, y, 2, C.text, 1)
    if self.spark > 0 then self:sprite("glow", x, y, 30 + (1 - self.spark) * 40, C.green, 0.6 * self.spark) end
    if self.hurt > 0 then self:sprite("ring", x, y, 14 + (1 - self.hurt) * 30, C.bad, self.hurt) end
    self:hud()
end

function Panel:render()
    if self.closed or not self.placed then return end
    if self.props then return self:pointer() end
    local g = self.game
    draw[g.kind](self, g)
    tool(self, g)
    if self.spark > 0 then
        local x, y = self:P(self.sparkX, self.sparkY)
        self:sprite("glow", x, y, 30 + (1 - self.spark) * 40, C.green, 0.6 * self.spark)
    end
    if self.hurt > 0 then
        local x, y = self:P(self.hurtX, self.hurtY)
        self:sprite("ring", x, y, 14 + (1 - self.hurt) * 30, C.bad, self.hurt)
    end
    self:hud()
end

function Panel.open(args)
    if Panel.instance then Panel.instance:finish(true) end
    local o = ISUIElement.new(Panel, 0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
    o.game = G.new(args.game, args.opts)
    o.amp = args.tremor or 0.004
    o.follow = args.follow
    o.flat = type(args.part) == "string" and (args.part:sub(1, 5) == "Torso" or args.part == "Groin")
    o.title = args.title
    o.help = args.help
    o.stopText = getText("IGUI_VD_Stop")
    o.onDone = args.onDone
    o.clock = 0
    o.lastMs = getTimestampMs()
    o.tipX, o.tipY = 0.5, 0.5
    o.dirX, o.dirY = 1, 0
    o.faults, o.progress, o.hurt, o.spark = 0, 0, 0, 0
    o.cos, o.sin = 1, 0
    o.props = args.follow == true and props("open") == true
    o:initialise()
    o:instantiate()
    o:setAlwaysOnTop(true)
    o:setWantKeyEvents(true)
    o:addToUIManager()
    o:setCapture(true)
    o:bringToTop()
    o:place(0)
    Panel.instance = o
    return o
end
