package.path = arg[1] .. "/shared/?.lua;" .. package.path
ViewDoctor = ViewDoctor or {}
require "ViewDoctor/Surface"
local S = ViewDoctor.Surface
local function close(a, b, e, what) assert(math.abs(a - b) <= (e or 1e-3), what .. ": " .. a .. " vs " .. b) end
local s = S.new(100, 300, 500, 300, 60, 40, false, 50)
for _, p in ipairs({ {0.2, 0.3}, {0.5, 0.5}, {0.8, 0.7}, {0.1, 0.9} }) do
    local sx, sy = S.map(s, p[1], p[2])
    local x, y = S.unmap(s, sx, sy)
    close(x, p[1], 1e-3, "round trip x"); close(y, p[2], 1e-3, "round trip y")
end
local _, _, mid = S.map(s, 0.5, 0.5); local _, _, edge = S.map(s, 0.5, 0.95)
assert(mid > 0.99 and edge < 0.4, "bands darken toward the limb sides")
local _, ya = S.map(s, 0, 1); local _, yb = S.map(s, 1, 1)
assert(math.abs(ya - 300) > math.abs(yb - 300), "near end is wider than far end")
local _, yOff = S.unmap(s, 300, 300 + 200)
assert(yOff > 1, "off the side clamps")
local d = S.new(300, 300, 300.0001, 300, 5, 5, false, 120)
local dx, dy = S.map(d, 0.5, 0.5)
assert(dx == dx and dy == dy and d.len >= 120, "degenerate axis")
local thin = S.new(0, 0, 400, 0, 10, 10, false, 300)
assert(thin.wa >= 0.22 * 300 - 1e-6, "minimum half-width keeps games playable")
local thigh = S.new(0, 0, 800, 0, 90, 80, false, 300)
assert(thigh.wa == 90 and thigh.wb == 80, "a long limb keeps its true width")
local flatOn = S.new(0, 0, 400, 0, 0, 0, false, 50)
local zx, zy = S.unmap(flatOn, S.map(flatOn, 0.3, 0.6))
assert(flatOn.wb >= 0.22 * 50 - 1e-6 and zx == zx and zy == zy, "a limb seen end-on still gets a width")
local f = S.new(100, 300, 500, 300, 150, 150, true, 50)
local _, _, fs = S.map(f, 0.5, 0.9)
assert(fs > 0.8, "flat patch barely darkens")
for _, y in ipairs({ -0.4, 1.3 }) do
    local ox, oy = S.unmap(s, S.map(s, 0.4, y))
    close(ox, 0.4, 1e-3, "off-limb round trip x"); close(oy, y, 1e-3, "off-limb round trip y")
end
close(S.aspect(s), math.rad(160) * 50 / 400, 1e-6, "aspect of a cylinder")
close(S.aspect(f), 2 * 150 / 400, 1e-6, "aspect of a flat patch")
print("surface ok")
