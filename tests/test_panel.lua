next = nil
package.path = arg[1] .. "/client/?.lua;" .. arg[1] .. "/shared/?.lua;" .. package.path
package.loaded["ISUI/ISUIElement"] = true
math.randomseed(3)

local W, H = 1920, 1080
local calls = {}

local function record(kind, ...)
    local c = { kind = kind, ... }
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        assert(type(v) ~= "number" or v == v, kind .. " got NaN in argument " .. i)
    end
    table.insert(calls, c)
end

ISUIElement = {}
ISUIElement.__index = ISUIElement
function ISUIElement:derive(name)
    local c = { Type = name }
    c.__index = c
    return setmetatable(c, { __index = self })
end
function ISUIElement.new(cls, x, y, w, h)
    local o = setmetatable({ x = x, y = y, width = w, height = h }, cls)
    o.javaObject = {
        DrawTexture = function(_, t, ...) record("quad", t, ...) end,
        DrawTextureScaledColor = function(_, t, ...) record("sprite", t, ...) end,
    }
    return o
end
for _, m in ipairs({ "initialise", "instantiate", "setAlwaysOnTop", "setWantKeyEvents", "addToUIManager", "setCapture", "bringToTop", "removeFromUIManager", "update" }) do
    ISUIElement[m] = function() end
end
function ISUIElement:setWidth(w) self.width = w end
function ISUIElement:setHeight(h) self.height = h end
function ISUIElement:drawRect(...) record("rect", ...) end
function ISUIElement:drawTextCentre(...) record("text", ...) end

local now = 0
mouseX, mouseY = W / 2, H / 2
getTexture = function(path) return path end
getCore = function() return { getScreenWidth = function() return W end, getScreenHeight = function() return H end } end
getMouseX = function() return mouseX end
getMouseY = function() return mouseY end
getTimestampMs = function() return now end
isGamePaused = function() return false end
getText = function(k) return k end
getTextManager = function() return { getFontHeight = function() return 20 end, MeasureStringX = function() return 100 end } end
UIFont = { Medium = 1, Small = 2 }
Keyboard = { KEY_ESCAPE = 1 }

local limb = { seen = true, ax = 700, ay = 700, bx = 1200, by = 500, wa = 60, wb = 45 }
local fp = true
local propCalls = {}
ViewDoctorPose = {
    seen = function() return limb.seen end,
    firstPerson = function() return fp end,
    cursor = function(x, y) limb.cx, limb.cy = x, y return true end,
    lx = function() return (limb.cx or 0) / W end,
    ly = function() return (limb.cy or 0) / H end,
    aspect = function() return 0.5 end,
    tool = function() end,
    toolFree = function() return false end,
}
for _, k in ipairs({ "ax", "ay", "bx", "by", "wa", "wb" }) do ViewDoctorPose[k] = function() return limb[k] end end
ViewDoctorPose.span = function() return 0.25 end
local shownX, shownY = 0, 0
ViewDoctorPose.show = function(...)
    if select("#", ...) ~= 2 then wrongCall = "show takes 2 arguments" end
    local x, y = ...
    shownX, shownY = 600 + x * 500, 400 + y * 200
    return true
end
ViewDoctorPose.sx = function() return shownX end
ViewDoctorPose.sy = function() return shownY end
local function exactly(n, name, f)
    return function(...)
        if select("#", ...) ~= n then wrongCall = name .. " takes " .. n .. " arguments, got " .. select("#", ...) end
        return f(...)
    end
end
ViewDoctorPose.rest = exactly(0, "rest", function() propCalls.rest = (propCalls.rest or 0) + 1 end)
ViewDoctorPose.cursor = exactly(2, "cursor", ViewDoctorPose.cursor)
ViewDoctorPose.tool = exactly(2, "tool", ViewDoctorPose.tool)
ViewDoctorPose.seen = exactly(0, "seen", ViewDoctorPose.seen)
local propsOpen, propsWork = true, true
local PropsMock = {
    open = exactly(0, "open", function() return propsOpen end),
    working = exactly(0, "working", function() return propsWork end),
    set = exactly(8, "set", function() propCalls.set = (propCalls.set or 0) + 1 end),
    drop = exactly(1, "drop", function() propCalls.drop = (propCalls.drop or 0) + 1 end),
    tool = exactly(5, "tool", function() propCalls.tool = (propCalls.tool or 0) + 1 end),
    close = exactly(0, "close", function() propCalls.close = (propCalls.close or 0) + 1 end),
}

require "ViewDoctor/Panel"
local Panel = ViewDoctor.Panel
local G = ViewDoctor.Games

local function open(kind, follow, part)
    return Panel.open({ game = kind, opts = { diff = 0.5, limit = 600 }, follow = follow, part = part or "ForeArm_L", title = "t", help = "h", onDone = function() end })
end

local function frame(p)
    calls = {}
    now = now + 16
    p:prerender()
    local pre = #calls
    p:render()
    return pre, #calls
end

local function covers(c)
    return c.kind == "rect" and (c[3] >= W * 0.9 or c[4] >= H * 0.9)
end

local function uses(name)
    for _, c in ipairs(calls) do
        if type(c[1]) == "string" and c[1]:find(name, 1, true) then return true end
    end
    return false
end

for _, kind in ipairs(G.kinds) do
    ViewDoctorProps = nil
    local p = open(kind, true)
    local pre = frame(p)
    assert(p.onLimb, kind .. ": panel sits on the limb")
    assert(pre == 0, kind .. ": nothing is drawn behind the limb in first person, got " .. pre .. " calls")
    assert(not uses("vignette"), kind .. ": no vignette on the limb")
    p.hurt, p.hurtX, p.hurtY = 1, 0.5, 0.5
    pre = frame(p)
    assert(pre == 0, kind .. ": a fault draws no backdrop flash on the limb")
    p:close()

    limb.seen = false
    p = open(kind, false)
    local _, total = frame(p)
    assert(not p.onLimb, kind .. ": centred when the limb is not followed")
    assert(not uses("vignette"), kind .. ": no hard-edged vignette off the limb")
    for _, c in ipairs(calls) do assert(not covers(c), kind .. ": no screen-wide dim box off the limb") end
    assert(uses("glow"), kind .. ": soft round backdrop off the limb")
    assert(total > 5, kind .. ": the flat game is drawn")
    p:close()
    calls = {}
    p:render()
    assert(#calls == 0, kind .. ": a closed panel draws nothing")
    limb.seen = true
end

for _, kind in ipairs(G.kinds) do
    ViewDoctorProps = PropsMock
    propCalls = {}
    fp, propsWork, limb.seen = true, true, true
    local p = open(kind, true)
    assert(p.props == true, kind .. ": props are on in first person")
    mouseX, mouseY = W * 0.4, H * 0.6
    local pre, total = frame(p)
    assert(pre == 0, kind .. ": nothing flat behind the props")
    assert(total < 90, kind .. ": props mode draws only the UI and the guides, got " .. total .. " calls")
    local rings, onLimbGuide = 0, false
    for _, c in ipairs(calls) do
        if c.kind == "sprite" and type(c[1]) == "string" and c[1]:find("ring", 1, true) then
            rings = rings + 1
            local cx, cy = c[2] + c[4] / 2, c[3] + c[5] / 2
            if cx >= 600 and cx <= 1100 and cy >= 400 and cy <= 600 then onLimbGuide = true end
        end
    end
    assert(onLimbGuide, kind .. ": a guide ring shows where to act on the limb, rings drawn: " .. rings)
    assert((propCalls.set or 0) >= 1 and propCalls.tool == 1, kind .. ": the scene reaches the props")
    assert(math.abs(p.tipX - 0.4) < 0.05 and math.abs(p.tipY - 0.6) < 0.05, kind .. ": the cursor comes from the cast onto the limb")
    assert(p.game.ky == 0.5 and p.game.len == 0.25, kind .. ": hit zones use the limb's own proportions")
    local game = p.game
    fp = false
    pre, total = frame(p)
    assert(p.props == false and propCalls.close == 1, kind .. ": leaving first person closes the props once")
    assert(p.game == game and total > 5, kind .. ": the flat game carries on with the same state")
    frame(p)
    assert(propCalls.close == 1, kind .. ": props are not closed twice")
    p:close()
    fp = true

    propCalls = {}
    p = open(kind, true)
    propsWork = false
    frame(p)
    assert(p.props == false and propCalls.close == 1, kind .. ": broken props fall back to the flat game")
    p:close()
    propsWork = true

    propCalls = {}
    p = open(kind, true)
    frame(p)
    limb.seen = false
    for _ = 1, 30 do frame(p) end
    assert(p.props == true, kind .. ": a short loss of the limb keeps the props")
    for _ = 1, 30 do frame(p) end
    assert(p.props == false, kind .. ": a limb lost for longer falls back")
    p:close()
    limb.seen = true

    propCalls = {}
    p = open(kind, true)
    frame(p)
    p:close()
    assert(propCalls.close == 1, kind .. ": closing the panel removes the props")

    propsOpen = false
    p = open(kind, true)
    assert(p.props == false, kind .. ": props that will not open leave the flat game")
    p:close()
    propsOpen = true
    ViewDoctorProps = nil
end

assert(wrongCall == nil, wrongCall)
print("panel ok")
