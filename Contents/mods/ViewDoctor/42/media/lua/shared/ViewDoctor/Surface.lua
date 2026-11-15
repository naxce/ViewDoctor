ViewDoctor = ViewDoctor or {}

local Surface = {}
ViewDoctor.Surface = Surface

local CYLINDER = math.rad(160)
local FLAT = math.rad(50)
local MIN_WIDTH = 0.22
local EDGE = math.pi / 2 / CYLINDER

function Surface.new(ax, ay, bx, by, wa, wb, flat, minLen)
    local cx, cy = (ax + bx) / 2, (ay + by) / 2
    local dx, dy = bx - ax, by - ay
    local l = math.sqrt(dx * dx + dy * dy)
    local ux, uy = 1, 0
    if l >= 1e-3 then ux, uy = dx / l, dy / l end
    local len = math.max(l, minLen or 0)
    local floor = MIN_WIDTH * ((minLen or 0) > 0 and minLen or len)
    local least = math.min(wa, wb)
    if least < 1e-6 then
        wa, wb = floor, floor
    else
        local f = math.max(1, floor / least)
        wa, wb = wa * f, wb * f
    end
    return {
        ax = cx - ux * len / 2, ay = cy - uy * len / 2,
        ux = ux, uy = uy, nx = -uy, ny = ux,
        len = len, wa = wa, wb = wb, flat = flat and true or false,
    }
end

local function width(s, x)
    return s.wa + (s.wb - s.wa) * x
end

function Surface.map(s, x, y)
    local w = width(s, x)
    local theta, off
    if s.flat then
        theta = (y - 0.5) * FLAT
        off = w * (y - 0.5) * 2
    else
        local u = y - 0.5
        if math.abs(u) > EDGE then
            local sign = u < 0 and -1 or 1
            theta = sign * math.pi / 2
            off = sign * w * (1 + math.abs(u) - EDGE)
        else
            theta = u * CYLINDER
            off = w * math.sin(theta)
        end
    end
    local along = s.len * x
    return s.ax + s.ux * along + s.nx * off, s.ay + s.uy * along + s.ny * off, math.cos(theta), w / ((s.wa + s.wb) / 2)
end

function Surface.unmap(s, mx, my)
    local rx, ry = mx - s.ax, my - s.ay
    local x = (rx * s.ux + ry * s.uy) / s.len
    local d = rx * s.nx + ry * s.ny
    local w = width(s, math.max(0, math.min(1, x)))
    if s.flat then return x, 0.5 + d / (2 * w) end
    local ad = math.abs(d)
    local sign = d < 0 and -1 or 1
    if ad > w then return x, 0.5 + sign * (EDGE + (ad - w) / w) end
    return x, 0.5 + math.asin(d / w) / CYLINDER
end

function Surface.size(s, x, n)
    return n * s.len * width(s, x) / ((s.wa + s.wb) / 2)
end

function Surface.aspect(s)
    return (s.flat and 2 or CYLINDER) * (s.wa + s.wb) / 2 / s.len
end
