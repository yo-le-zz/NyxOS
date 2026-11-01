-- Minimal-but-strict CC:Tweaked mock (Lua 5.1 / lupa). Faithful on the points that
-- cause real crashes: argument type errors, shell/require being program-env only,
-- fs.copy refusing to overwrite, mounts being undeletable, etc.
local H = {}              -- harness table (exported)
H.log = {}
H.hostloadfile = loadfile
H.SB = SANDBOX            -- real dir backing "/"
H.ROM = ROMDIR            -- real dir backing "/rom"
H.mounts = {}             -- name -> {dir=, drive=, ro=}
H.EVQ = {}                -- queued events (os.queueEvent)
H.SCRIPT = {}             -- scripted external events / functions
H.INPUT = {}              -- scripted read() lines
H.timers = {}
H.clock = 0
H.nextTimer = 1
H.peripherals = {}        -- name -> {type=, methods=}
H.httpmap = {}            -- url prefix -> real dir
H.httplog = {}

local rawtype = type
local function tname(v) return rawtype(v) end
local function expect(n, v, ...)
  local ts = {...}
  for _, t in ipairs(ts) do if rawtype(v) == t then return v end end
  error(("bad argument #%d (%s expected, got %s)"):format(n, table.concat(ts, " or "), v == nil and "nil" or rawtype(v)), 3)
end
H.expect = expect

local function missing(ns)
  return setmetatable({}, { __index = function(t, k) error("MOCK-MISSING: " .. ns .. "." .. tostring(k), 2) end })
end

table.unpack = table.unpack or unpack
table.pack = table.pack or function(...) return { n = select('#', ...), ... } end

local _fmt = string.format
function string.format(f, ...)
  local a = { ... }
  for i = 1, select('#', ...) do local t = rawtype(a[i]) if t ~= "number" and t ~= "string" then a[i] = tostring(a[i]) end end
  return _fmt(f, unpack(a, 1, select('#', ...)))
end

-- ------------------------------------------------------------ colors
local names = { "white","orange","magenta","lightBlue","yellow","lime","pink","gray","lightGray","cyan","purple","blue","brown","green","red","black" }
colors = {}
for i, n in ipairs(names) do colors[n] = 2 ^ (i - 1) end
colors.grey = colors.gray; colors.lightGrey = colors.lightGray
function colors.combine(...) local r = 0 for _, c in ipairs({...}) do r = r + c end return r end
function colors.toBlit(c) expect(1, c, "number") return ("%x"):format(math.floor(math.log(c) / math.log(2) + 0.5)) end
function colors.fromBlit(s) return 2 ^ tonumber(s, 16) end
function colors.packRGB(r, g, b) return math.floor(r*255)*65536 + math.floor(g*255)*256 + math.floor(b*255) end
function colors.test(a, b) return math.floor(a / b) % 2 == 1 end
colours = {}
for k, v in pairs(colors) do colours[k] = v end
colours.grey = colors.gray; colours.lightGrey = colors.lightGray

-- ------------------------------------------------------------ keys
keys = { backspace=14, tab=15, q=16, w=17, e=18, r=19, t=20, y=21, u=22, i=23, o=24, p=25, leftBracket=26, rightBracket=27,
  enter=28, leftCtrl=29, a=30, s=31, d=32, f=33, g=34, h=35, j=36, k=37, l=38, semiColon=39, apostrophe=40, grave=41,
  leftShift=42, backslash=43, z=44, x=45, c=46, v=47, b=48, n=49, m=50, comma=51, period=52, slash=53, rightShift=54,
  multiply=55, leftAlt=56, space=57, capsLock=58, f1=59,f2=60,f3=61,f4=62,f5=63,f6=64,f7=65,f8=66,f9=67,f10=68,
  numLock=69, scrollLock=70, numPad7=71, numPad8=72, numPad9=73, subtract=74, numPad4=75, numPad5=76, numPad6=77, add=78,
  numPad1=79, numPad2=80, numPad3=81, numPad0=82, decimal=83, f11=87, f12=88, numPadEnter=156, rightCtrl=157,
  numPadDivide=181, rightAlt=184, pause=197, home=199, up=200, pageUp=201, left=203, right=205, ["end"]=207, down=208,
  pageDown=209, insert=210, delete=211, one=2,two=3,three=4,four=5,five=6,six=7,seven=8,eight=9,nine=10,zero=11,minus=12,equals=13 }
keys.getName = function(c) for k, v in pairs(keys) do if v == c then return k end end end

-- ------------------------------------------------------------ bit32 (exact, via LuaJIT's bit library)
do
  local bit = require("bit")
  local function u(x) if x < 0 then return x + 4294967296 end return x end
  bit32 = {}
  function bit32.band(...) return u(bit.band(...)) end
  function bit32.bor(...) return u(bit.bor(...)) end
  function bit32.bxor(...) return u(bit.bxor(...)) end
  function bit32.bnot(a) return u(bit.bnot(a)) end
  function bit32.lshift(a, n) if n >= 32 then return 0 end if n < 0 then return bit32.rshift(a, -n) end return u(bit.lshift(a, n)) end
  function bit32.rshift(a, n) if n >= 32 then return 0 end if n < 0 then return bit32.lshift(a, -n) end return u(bit.rshift(a, n)) end
  function bit32.arshift(a, n) return u(bit.arshift(a, n)) end
  function bit32.lrotate(a, n) return u(bit.rol(a, n % 32)) end
  function bit32.rrotate(a, n) return u(bit.ror(a, n % 32)) end
  function bit32.extract(n, f, w) w = w or 1 return bit32.band(bit32.rshift(n, f), 2 ^ w - 1) end
  function bit32.btest(...) return bit32.band(...) ~= 0 end
end

-- ------------------------------------------------------------ fs (sandboxed)
local function norm(path)
  expect(1, path, "string")
  local parts = {}
  for seg in path:gmatch("[^/\\]+") do
    if seg == ".." then
      if #parts == 0 or parts[#parts] == ".." then table.insert(parts, "..") else table.remove(parts) end
    elseif seg ~= "." and seg ~= "" then table.insert(parts, seg) end
  end
  return table.concat(parts, "/")
end
fs = {}
function fs.combine(base, ...)
  expect(1, base, "string")
  local p = base
  for i, v in ipairs({...}) do expect(i + 1, v, "string") p = p .. "/" .. v end
  return norm(p)
end
function fs.getName(p) p = norm(p) if p == "" then return "root" end return p:match("([^/]*)$") end
function fs.getDir(p) p = norm(p) if p == "" then return ".." end local d = p:match("^(.*)/[^/]*$") return d or "" end

local function resolve(path)
  local p = norm(path)
  if p:sub(1, 2) == ".." then error(path .. ": Invalid Path", 3) end
  local first, rest = p:match("^([^/]*)/?(.*)$")
  if first == "rom" then return H.ROM .. (rest ~= "" and "/" .. rest or ""), { drive = "rom", ro = true, root = rest == "" }, p end
  local m = H.mounts[first]
  if m then return m.dir .. (rest ~= "" and "/" .. rest or ""), { drive = m.drive, ro = m.ro, root = rest == "" }, p end
  return H.SB .. (p ~= "" and "/" .. p or ""), { drive = "hdd", ro = false, root = false }, p
end
local py = PY
local function real_exists(rp) return py.exists(rp) end
function fs.exists(p) local rp = resolve(p) return py.exists(rp) end
function fs.isDir(p) local rp = resolve(p) return py.isdir(rp) end
function fs.isReadOnly(p) local _, m = resolve(p) return m.ro end
function fs.getDrive(p) local rp, m = resolve(p) if not py.exists(rp) then return nil end return m.drive end
function fs.getSize(p) local rp = resolve(p) if not py.exists(rp) then error(p .. ": No such file", 2) end return py.size(rp) end
function fs.getFreeSpace(p) return 1000000 end
function fs.getCapacity(p) return 1000000 end
function fs.isDriveRoot(p) local _, m = resolve(p) return m.root or norm(p) == "" end
function fs.list(p)
  local rp, m, n = resolve(p)
  if not py.isdir(rp) then error(p .. ": Not a directory", 2) end
  local out = {}
  for _, e in ipairs(py.listdir(rp)) do table.insert(out, e) end
  if n == "" then
    local have = {}
    for _, e in ipairs(out) do have[e] = true end
    if not have.rom then table.insert(out, "rom") end
    for name in pairs(H.mounts) do if not have[name] then table.insert(out, name) end end
  end
  table.sort(out)
  return out
end
function fs.makeDir(p)
  local rp, m = resolve(p)
  if m.ro then error(p .. ": Access denied", 2) end
  if py.exists(rp) and not py.isdir(rp) then error(p .. ": File exists", 2) end
  py.mkdirs(rp)
end
function fs.delete(p)
  local rp, m = resolve(p)
  if m.ro or m.root or norm(p) == "" then error(p .. ": Access denied", 2) end
  if py.exists(rp) then py.rm(rp) end
end
function fs.copy(a, b)
  local ra, ma = resolve(a); local rb, mb = resolve(b)
  if not py.exists(ra) then error(a .. ": No such file", 2) end
  if py.exists(rb) then error(b .. ": File exists", 2) end
  if mb.ro then error(b .. ": Access denied", 2) end
  py.mkdirs(py.dirname(rb))
  if H.quota and py.used() + py.size(ra) > H.quota then error(b .. ": Out of space", 2) end
  py.copy(ra, rb)
end
function fs.move(a, b)
  local ra, ma = resolve(a); local rb, mb = resolve(b)
  if not py.exists(ra) then error(a .. ": No such file", 2) end
  if py.exists(rb) then error(b .. ": File exists", 2) end
  if ma.ro or mb.ro then error("Access denied", 2) end
  py.mkdirs(py.dirname(rb)); py.move(ra, rb)
end
function fs.find(pattern)
  local out = {}
  local function walk(dir)
    for _, e in ipairs(fs.list(dir)) do
      local full = fs.combine(dir, e)
      table.insert(out, full)
      if fs.isDir(full) and full ~= "rom" then walk(full) end
    end
  end
  walk("")
  local lp = "^" .. norm(pattern):gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0"):gsub("%*", "[^/]*"):gsub("%?", "[^/]") .. "$"
  local res = {}
  for _, f in ipairs(out) do if f:match(lp) then table.insert(res, f) end end
  return res
end
function fs.complete() return {} end
function fs.attributes(p) local rp = resolve(p) if not py.exists(rp) then error(p .. ": No such file", 2) end return { size = py.size(rp), isDir = py.isdir(rp), isReadOnly = false, created = 0, modified = 0 } end

local function mkhandle(f, mode)
  local h = {}
  local closed = false
  local function chk() if closed then error("attempt to use a closed file", 3) end end
  if mode:sub(1, 1) == "r" then
    local data = f:read("*a") f:close()
    local pos = 1
    function h.readAll() chk() if pos > #data then return nil end local s = data:sub(pos) pos = #data + 1 return s end
    function h.readLine(wt)
      chk() if pos > #data then return nil end
      local e = data:find("\n", pos, true)
      local line
      if e then line = data:sub(pos, wt and e or e - 1) pos = e + 1 else line = data:sub(pos) pos = #data + 1 end
      return (line:gsub("\r$", ""))
    end
    function h.read(n)
      chk() if pos > #data then return nil end
      if n == nil then local c = data:sub(pos, pos) pos = pos + 1 return (mode:find("b") and c:byte() or c) end
      local s = data:sub(pos, pos + n - 1) pos = pos + #s return s
    end
    function h.lines() return function() return h.readLine() end end
    function h.seek(w, o) if w == "set" then pos = (o or 0) + 1 elseif w == "end" then pos = #data + 1 + (o or 0) else pos = pos + (o or 0) end return pos - 1 end
    function h.close() closed = true end
  else
    function h.write(s)
      chk()
      if rawtype(s) ~= "string" and rawtype(s) ~= "number" then error(("bad argument #1 (string expected, got %s)"):format(s == nil and "nil" or rawtype(s)), 2) end
      f:write(s)
    end
    function h.writeLine(s) chk() f:write(tostring(s) .. "\n") end
    function h.flush() chk() f:flush() end
    function h.close() if not closed then closed = true f:close() end end
  end
  return h
end
function fs.open(path, mode)
  expect(1, path, "string"); expect(2, mode, "string")
  local rp, m = resolve(path)
  local c = mode:sub(1, 1)
  if c == "r" then
    if not py.exists(rp) or py.isdir(rp) then return nil, path .. ": No such file" end
    return mkhandle(io.open(rp, "rb"), mode)
  elseif c == "w" or c == "a" then
    if m.ro then return nil, path .. ": Access denied" end
    if py.isdir(rp) then return nil, path .. ": Cannot write to directory" end
    local dir = py.dirname(rp)
    if not py.isdir(dir) then table.insert(H.log, "implicit-mkdir for " .. path) py.mkdirs(dir) end
    local f = io.open(rp, c == "w" and "wb" or "ab")
    if not f then return nil, path .. ": Access denied" end
    return mkhandle(f, mode)
  end
  error("Unsupported mode", 2)
end

-- ------------------------------------------------------------ loading
local _load = load
function load(chunk, name, mode, env)
  local f, e
  if rawtype(chunk) == "string" then f, e = loadstring(chunk, name) else f, e = _load(chunk, name) end
  if f and env then setfenv(f, env) end
  return f, e
end
function loadfile(path, mode, env)
  if rawtype(mode) == "table" then env = mode end
  local h = fs.open(path, "r")
  if not h then return nil, path .. ": File not found" end
  local src = h.readAll() or "" h.close()
  return load(src, "@" .. path, "t", env or _G)
end
function dofile(path)
  expect(1, path, "string")
  local f, e = loadfile(path, nil, _G)
  if not f then error(e, 2) end
  return f()
end
function os.run(env, path, ...)
  setmetatable(env, { __index = _G })
  local f, e = loadfile(path, nil, env)
  if not f then print(e) return false end
  local ok, err = pcall(f, ...)
  if not ok then if err and err ~= "" then print(err) end return false end
  return true
end

-- ------------------------------------------------------------ term / windows
local function newBuf(w, h)
  local b = { w = w, h = h, cx = 1, cy = 1, fg = colors.white, bg = colors.black, blink = false, visible = true, lines = {}, fgs = {}, bgs = {}, isCol = true, palette = {} }
  for y = 1, h do b.lines[y] = {} b.fgs[y] = {} b.bgs[y] = {} for x = 1, w do b.lines[y][x] = " " b.fgs[y][x] = "0" b.bgs[y][x] = "f" end end
  return b
end
local TermObj = {}
TermObj.__index = TermObj
local function mkterm(w, h)
  local b = setmetatable(newBuf(w, h), TermObj)
  local t = { buf = b }
  for name, fn in pairs(TermObj) do
    if rawtype(fn) == "function" then t[name] = function(...) return fn(b, ...) end end
  end
  return t
end
H.mkterm = mkterm
local function hex(c) return colors.toBlit(c) end
function TermObj:getSize() return self.w, self.h end
function TermObj:setCursorPos(x, y) expect(1, x, "number") expect(2, y, "number") self.cx, self.cy = math.floor(x), math.floor(y) end
function TermObj:getCursorPos() return self.cx, self.cy end
function TermObj:setCursorBlink(b) expect(1, b, "boolean") self.blink = b end
function TermObj:getCursorBlink() return self.blink end
function TermObj:setTextColor(c) expect(1, c, "number") if c < 1 or c > 32768 then error("Colour out of range", 2) end self.fg = c end
function TermObj:setBackgroundColor(c) expect(1, c, "number") if c < 1 or c > 32768 then error("Colour out of range", 2) end self.bg = c end
function TermObj:getTextColor() return self.fg end
function TermObj:getBackgroundColor() return self.bg end
function TermObj:isColor() return self.isCol end
function TermObj:setPaletteColor(i, r, g, b) self.palette[i] = { r, g, b } end
function TermObj:getPaletteColor(i) local p = self.palette[i] or { 0, 0, 0 } return p[1], p[2], p[3] end
function TermObj:write(s)
  if rawtype(s) == "number" then s = tostring(s) end
  expect(1, s, "string")
  local y = self.cy
  if y >= 1 and y <= self.h then
    for i = 1, #s do
      local x = self.cx + i - 1
      if x >= 1 and x <= self.w then self.lines[y][x] = s:sub(i, i) self.fgs[y][x] = hex(self.fg) self.bgs[y][x] = hex(self.bg) end
    end
  end
  self.cx = self.cx + #s
end
function TermObj:blit(s, f, b)
  expect(1, s, "string") expect(2, f, "string") expect(3, b, "string")
  if #s ~= #f or #s ~= #b then error("Arguments must be the same length", 2) end
  local y = self.cy
  if y >= 1 and y <= self.h then
    for i = 1, #s do
      local x = self.cx + i - 1
      if x >= 1 and x <= self.w then self.lines[y][x] = s:sub(i, i) self.fgs[y][x] = f:sub(i, i) self.bgs[y][x] = b:sub(i, i) end
    end
  end
  self.cx = self.cx + #s
end
function TermObj:clearLine() local y = self.cy if y >= 1 and y <= self.h then for x = 1, self.w do self.lines[y][x] = " " self.fgs[y][x] = hex(self.fg) self.bgs[y][x] = hex(self.bg) end end end
function TermObj:clear() for y = 1, self.h do for x = 1, self.w do self.lines[y][x] = " " self.fgs[y][x] = hex(self.fg) self.bgs[y][x] = hex(self.bg) end end end
function TermObj:scroll(n)
  expect(1, n, "number")
  local nl, nf, nb = {}, {}, {}
  for y = 1, self.h do
    local sy = y + n
    if sy >= 1 and sy <= self.h then nl[y], nf[y], nb[y] = self.lines[sy], self.fgs[sy], self.bgs[sy]
    else nl[y], nf[y], nb[y] = {}, {}, {} for x = 1, self.w do nl[y][x] = " " nf[y][x] = hex(self.fg) nb[y][x] = hex(self.bg) end end
  end
  self.lines, self.fgs, self.bgs = nl, nf, nb
end
function TermObj:getLine(y) local t, f, b = {}, {}, {} for x = 1, self.w do t[x] = self.lines[y][x] f[x] = self.fgs[y][x] b[x] = self.bgs[y][x] end return table.concat(t), table.concat(f), table.concat(b) end
function TermObj:setVisible(v) self.visible = v end
function TermObj:isVisible() return self.visible end
function TermObj:redraw() end
function TermObj:restoreCursor() end
function TermObj:getPosition() return self.px or 1, self.py or 1 end
function TermObj:reposition(x, y, w, h) self.px, self.py = x, y if w then self.w, self.h = w, h end end
TermObj.setTextColour, TermObj.setBackgroundColour = TermObj.setTextColor, TermObj.setBackgroundColor
TermObj.getTextColour, TermObj.getBackgroundColour = TermObj.getTextColor, TermObj.getBackgroundColor
TermObj.isColour = TermObj.isColor
TermObj.setPaletteColour, TermObj.getPaletteColour = TermObj.setPaletteColor, TermObj.getPaletteColor
function TermObj:dump()
  local out = {}
  for y = 1, self.h do out[y] = table.concat(self.lines[y]):gsub("%s+$", "") end
  return table.concat(out, "\n")
end

H.native = mkterm(tonumber(os.getenv("CC_W") or "") or 51, tonumber(os.getenv("CC_H") or "") or 19)
H.current = H.native
term = {}
local passthru = { "getSize","setCursorPos","getCursorPos","setCursorBlink","getCursorBlink","setTextColor","setBackgroundColor","getTextColor",
  "getBackgroundColor","isColor","write","blit","clear","clearLine","scroll","setTextColour","setBackgroundColour","getTextColour","getBackgroundColour",
  "isColour","setPaletteColor","getPaletteColor","setPaletteColour","getPaletteColour" }
for _, n in ipairs(passthru) do term[n] = function(...) return H.current[n](...) end end
function term.current() return H.current end
function term.native() return H.native end
function term.redirect(t)
  expect(1, t, "table")
  if t == term then error("term is not a recommended redirect target, try term.current() instead", 2) end
  for _, n in ipairs({ "write","blit","setCursorPos","getCursorPos","setTextColor","setBackgroundColor","getSize","clear","clearLine","scroll","setCursorBlink","getCursorBlink","isColor","getTextColor","getBackgroundColor","setPaletteColor","getPaletteColor","setTextColour","setBackgroundColour","getTextColour","getBackgroundColour","isColour","setPaletteColour","getPaletteColour" }) do
    if rawtype(t[n]) ~= "function" then t[n] = function() error("Redirect object is missing method " .. n .. ".", 2) end end
  end
  local old = H.current H.current = t return old
end
function term.setTextScale() end

window = {}
function window.create(parent, x, y, w, h, vis)
  expect(1, parent, "table") expect(2, x, "number") expect(3, y, "number") expect(4, w, "number") expect(5, h, "number")
  local t = mkterm(w, h) t.buf.px, t.buf.py = x, y t.buf.parent = parent if vis == false then t.buf.visible = false end
  return t
end

-- print / write / read
local function termWrite(text)
  local w, h = term.getSize()
  local n = 0
  text = tostring(text)
  while #text > 0 do
    local x, y = term.getCursorPos()
    local nl = text:find("\n", 1, true)
    local chunk = text
    if nl then chunk = text:sub(1, nl - 1) end
    local room = w - x + 1
    if #chunk > room and room > 0 then chunk = chunk:sub(1, room) end
    if #chunk > 0 then term.write(chunk) end
    text = text:sub(#chunk + 1)
    if text:sub(1, 1) == "\n" then text = text:sub(2) x = 1 end
    if #text > 0 or nl then
      local _, y2 = term.getCursorPos()
      if y2 >= h then term.scroll(1) term.setCursorPos(1, h) else term.setCursorPos(1, y2 + 1) end
      n = n + 1
    end
  end
  return n
end
function write(s) expect(1, s, "string", "number") return termWrite(s) end
function print(...)
  local t = {}
  for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
  local s = table.concat(t, "\t")
  termWrite(s)
  local x, y = term.getCursorPos() local _, h = term.getSize()
  if y >= h then term.scroll(1) term.setCursorPos(1, h) else term.setCursorPos(1, y + 1) end
  term.setCursorPos(1, select(2, term.getCursorPos()))
end
function printError(...) print(...) end
function read(replace, history, complete, default)
  local line = table.remove(H.INPUT, 1)
  if line == nil then error("MOCK: read() called with no scripted input left", 2) end
  termWrite(replace and string.rep(replace, #line) or line)
  local _, y = term.getCursorPos() local _, h = term.getSize()
  if y >= h then term.scroll(1) term.setCursorPos(1, h) else term.setCursorPos(1, y + 1) end
  term.setCursorPos(1, select(2, term.getCursorPos()))
  return line
end

-- ------------------------------------------------------------ os / events
os.version = function() return "CraftOS 1.8" end
os.getComputerID = function() return 1 end
local label = nil
os.getComputerLabel = function() return label end
os.setComputerLabel = function(l) label = l end
os.computerID, os.computerLabel = os.getComputerID, os.getComputerLabel
local realclock = os.clock
os.clock = function() return H.clock end
os.time = function() return 12.5 end
os.day = function() return 1 end
os.epoch = function(k) return math.floor(os.time and (1.7e12 + H.clock * 1000)) end
function os.queueEvent(name, ...) expect(1, name, "string") table.insert(H.EVQ, { name, ... }) end
function os.startTimer(t) expect(1, t, "number") local id = H.nextTimer H.nextTimer = id + 1 H.timers[id] = H.clock + t return id end
function os.cancelTimer(id) H.timers[id] = nil end
function os.startAlarm() return 0 end
function os.cancelAlarm() end
function os.reboot() error({ __exit = "reboot" }, 0) end
function os.shutdown() error({ __exit = "shutdown" }, 0) end
function os.pullEventRaw(filter)
  return coroutine.yield(filter)
end
function os.pullEvent(filter)
  while true do
    local ev = { coroutine.yield(filter) }
    if ev[1] == "terminate" then error("Terminated", 0) end
    if filter == nil or ev[1] == filter then return unpack(ev) end
  end
end
function sleep(t)
  local id = os.startTimer(t or 0)
  while true do local _, tid = os.pullEvent("timer") if tid == id then return end end
end
os.sleep = sleep

-- ------------------------------------------------------------ peripheral
peripheral = {}
function peripheral.getNames() local n = {} for k in pairs(H.peripherals) do n[#n + 1] = k end table.sort(n) return n end
function peripheral.isPresent(n) return H.peripherals[n] ~= nil end
function peripheral.getType(n)
  if rawtype(n) == "table" then
    if n.__name and H.peripherals[n.__name] then return H.peripherals[n.__name].type end
    error("bad argument #1 (table is not a peripheral)", 2)
  end
  expect(1, n, "string")
  local p = H.peripherals[n] if p then return p.type end
end
function peripheral.getName(o) return o and o.__name end
function peripheral.wrap(n) local p = H.peripherals[n] if not p then return nil end local o = p.methods or {} o.__name = n return o end
function peripheral.find(t, filter)
  local out = {}
  for _, n in ipairs(peripheral.getNames()) do
    if H.peripherals[n].type == t then local w = peripheral.wrap(n) if not filter or filter(n, w) then out[#out + 1] = w end end
  end
  return unpack(out)
end

-- ------------------------------------------------------------ textutils
local function ser(v, indent)
  local t = rawtype(v)
  if t == "table" then
    local parts = {}
    local n = #v
    for i = 1, n do parts[#parts + 1] = ser(v[i]) end
    local keys_ = {}
    for k in pairs(v) do if not (rawtype(k) == "number" and k >= 1 and k <= n and math.floor(k) == k) then keys_[#keys_ + 1] = k end end
    table.sort(keys_, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys_) do
      local ks = (rawtype(k) == "string" and k:match("^[%a_][%w_]*$")) and k or ("[" .. ser(k) .. "]")
      parts[#parts + 1] = ks .. "=" .. ser(v[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "string" then return ("%q"):format(v):gsub("\\\n", "\\n")
  elseif t == "number" or t == "boolean" then return tostring(v)
  elseif t == "nil" then return "nil"
  else error("Cannot serialize type " .. t, 3) end
end
local function jenc(v)
  local t = rawtype(v)
  if t == "table" then
    local n = #v
    if n > 0 or next(v) == nil then
      local p = {} for i = 1, n do p[i] = jenc(v[i]) end return "[" .. table.concat(p, ",") .. "]"
    end
    local ks = {} for k in pairs(v) do ks[#ks + 1] = tostring(k) end table.sort(ks)
    local p = {} for _, k in ipairs(ks) do p[#p + 1] = jenc(k) .. ":" .. jenc(v[k]) end
    return "{" .. table.concat(p, ",") .. "}"
  elseif t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) local m = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" } return m[c] or ("\\u%04x"):format(c:byte()) end) .. '"'
  elseif t == "number" or t == "boolean" then return tostring(v)
  else return "null" end
end
local function jdec(s)
  local i = 1
  local function ws() i = s:find("[^ \t\r\n]", i) or #s + 1 end
  local val
  local function str()
    local j = i + 1 local out = {}
    while true do
      local c = s:sub(j, j)
      if c == '"' then i = j + 1 return table.concat(out) end
      if c == "\\" then local n = s:sub(j + 1, j + 1) local m = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" } out[#out + 1] = m[n] or n j = j + 2
      else out[#out + 1] = c j = j + 1 end
      if j > #s then error("unterminated string") end
    end
  end
  function val()
    ws() local c = s:sub(i, i)
    if c == "{" then
      i = i + 1 local o = {} ws()
      if s:sub(i, i) == "}" then i = i + 1 return o end
      while true do ws() local k = str() ws() if s:sub(i, i) ~= ":" then error("expected :") end i = i + 1 o[k] = val() ws()
        local d = s:sub(i, i) i = i + 1 if d == "}" then return o elseif d ~= "," then error("expected , or }") end end
    elseif c == "[" then
      i = i + 1 local a = {} ws()
      if s:sub(i, i) == "]" then i = i + 1 return a end
      while true do a[#a + 1] = val() ws() local d = s:sub(i, i) i = i + 1 if d == "]" then return a elseif d ~= "," then error("expected , or ]") end end
    elseif c == '"' then return str()
    elseif s:sub(i, i + 3) == "true" then i = i + 4 return true
    elseif s:sub(i, i + 4) == "false" then i = i + 5 return false
    elseif s:sub(i, i + 3) == "null" then i = i + 4 return nil
    else local n = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i) if not n or n == "" then error("bad json at " .. i) end i = i + #n return tonumber(n) end
  end
  return val()
end
textutils = {}
function textutils.serialize(v) return ser(v) end
function textutils.unserialize(s)
  expect(1, s, "string")
  local f = loadstring("return " .. s) if not f then return nil end
  setfenv(f, {}) local ok, r = pcall(f) if ok then return r end return nil
end
textutils.serialise, textutils.unserialise = textutils.serialize, textutils.unserialize
function textutils.serializeJSON(v) return jenc(v) end
textutils.serialiseJSON = textutils.serializeJSON
function textutils.unserializeJSON(s) expect(1, s, "string") local ok, r = pcall(jdec, s) if ok then return r end return nil, r end
textutils.unserialiseJSON = textutils.unserializeJSON
function textutils.formatTime(t, h24) local h = math.floor(t) local m = math.floor((t - h) * 60) return ("%d:%02d"):format(h, m) end
function textutils.tabulate() end
function textutils.pagedPrint(t) print(t) end
function textutils.slowPrint(t) print(t) end
function textutils.urlEncode(s) return (s:gsub("[^%w%-_%.~]", function(c) return ("%%%02X"):format(c:byte()) end)) end
function textutils.empty_json_array() return {} end

-- ------------------------------------------------------------ parallel
parallel = {}
local function runPar(all, ...)
  local fns = {...}
  local cos, filters, alive = {}, {}, #fns
  for i, f in ipairs(fns) do cos[i] = coroutine.create(f) end
  local ev = {}
  while true do
    for i, co in ipairs(cos) do
      if co and (filters[i] == nil or filters[i] == ev[1] or ev[1] == "terminate") then
        local ok, r = coroutine.resume(co, unpack(ev))
        if not ok then error(r, 0) end
        if coroutine.status(co) == "dead" then
          cos[i] = false alive = alive - 1
          if not all then return i end
        else filters[i] = r end
      end
    end
    if all and alive == 0 then return end
    ev = { coroutine.yield() }
  end
end
function parallel.waitForAny(...) return runPar(false, ...) end
function parallel.waitForAll(...) return runPar(true, ...) end

-- ------------------------------------------------------------ http
local function mkresp(body, code)
  local pos = 1
  return {
    readAll = function() if pos > #body then return nil end local r = body:sub(pos) pos = #body + 1 return r end,
    readLine = function() if pos > #body then return nil end local e = body:find("\n", pos, true) local l if e then l = body:sub(pos, e - 1) pos = e + 1 else l = body:sub(pos) pos = #body + 1 end return l end,
    read = function(n) if pos > #body then return nil end local s = body:sub(pos, pos + (n or 1) - 1) pos = pos + #s return s end,
    getResponseCode = function() return code, "x" end,
    close = function() end,
  }
end
http = {}
function http.get(url, headers)
  if rawtype(url) == "table" then url = url.url end
  expect(1, url, "string")
  table.insert(H.httplog, url)
  for prefix, dir in pairs(H.httpmap) do
    if url:sub(1, #prefix) == prefix then
      local rel = url:sub(#prefix + 1):gsub("%%20", " ")
      local rp = dir .. "/" .. rel
      if py.exists(rp) and not py.isdir(rp) then return mkresp(py.readfile(rp), 200) end
      return nil, "Not Found", mkresp("404: Not Found", 404)
    end
  end
  return nil, "Could not connect"
end
http.checkURL = function() return true end

-- ------------------------------------------------------------ misc stubs
settings = { get = function(_, d) return d end, set = function() end, save = function() end, load = function() end, getNames = function() return {} end }
redstone = missing("redstone"); rs = redstone
rednet = { open = function() end, close = function() end, isOpen = function() return false end, host = function() end, unhost = function() end,
  lookup = function() return nil end, send = function() return true end, broadcast = function() return true end,
  receive = function(_, t) if t then sleep(t) end return nil end }
disk = missing("disk")
fs.isDriveRoot = fs.isDriveRoot

-- ------------------------------------------------------------ shell (program-env only!)
local shellDir, shellPath, running = "", ".:/rom/programs", "shell"
local aliases = {}
local shell = {}
H.shell = shell
function shell.dir() return shellDir end
function shell.setDir(d) expect(1, d, "string") shellDir = norm(d) end
function shell.path() return shellPath end
function shell.setPath(p) expect(1, p, "string") shellPath = p end
function shell.resolve(p) expect(1, p, "string") local s = p:sub(1, 1) if s == "/" or s == "\\" then return norm(p) end return fs.combine(shellDir, p) end
function shell.getRunningProgram() return running end
function shell.setAlias(a, b) aliases[a] = b end
function shell.clearAlias(a) aliases[a] = nil end
function shell.aliases() return aliases end
function shell.exit() end
function shell.complete() return {} end
function shell.completeProgram() return {} end
function shell.setCompletionFunction() end
function shell.programs() return {} end
function shell.openTab() end
function shell.switchTab() end
function shell.resolveProgram(name)
  expect(1, name, "string")
  if aliases[name] then name = aliases[name] end
  for dir in shellPath:gmatch("[^:]+") do
    local base = dir == "." and shellDir or dir
    for _, cand in ipairs({ fs.combine(base, name), fs.combine(base, name .. ".lua") }) do
      if fs.exists(cand) and not fs.isDir(cand) then return cand end
    end
  end
  local direct = shell.resolve(name)
  for _, cand in ipairs({ direct, direct .. ".lua" }) do
    if fs.exists(cand) and not fs.isDir(cand) then return cand end
  end
  return nil
end
local function mkenv()
  local env = { shell = shell, multishell = nil }
  env.package = { path = "", loaded = {} }
  env.require = function(n) error("MOCK: require('" .. n .. "') not supported", 2) end
  return setmetatable(env, { __index = _G })
end
function shell.run(...)
  local parts = {...}
  local cmd = table.concat(parts, " ")
  local toks = {}
  for t in cmd:gmatch("%S+") do toks[#toks + 1] = t end
  if #toks == 0 then return true end
  local prog = shell.resolveProgram(toks[1])
  if not prog then print("No such program") return false end
  local args = {}
  for i = 2, #toks do args[#args + 1] = toks[i] end
  local f, e = loadfile(prog, nil, mkenv())
  if not f then print(e) return false end
  local prev = running running = prog
  local ok, err = pcall(f, unpack(args))
  running = prev
  if not ok then
    if rawtype(err) == "table" and err.__exit then error(err, 0) end
    H.lastError = err
    if err and err ~= "" then print(tostring(err)) end
    return false
  end
  return true
end
function shell.execute(cmd, ...) return shell.run(cmd, ...) end
function H.runProgram(path, ...)
  local f, e = loadfile(path, nil, mkenv())
  if not f then error(e, 0) end
  local prev = running running = path
  local args = {...}
  local r = { pcall(f, unpack(args)) }
  running = prev
  return unpack(r)
end


-- Surface every error swallowed by pcall (the real cause of "Basalt crashes" being invisible).
H.caught = {}
do
  local _pcall, _xpcall = pcall, xpcall
  local function handler(e)
    if rawtype(e) == "table" and e.__exit then return e end
    local tb = debug.traceback(tostring(e), 2)
    return { __caught = true, msg = e, tb = tb }
  end
  function pcall(f, ...)
    local r = { _xpcall(f, handler, ...) }
    if r[1] then return unpack(r) end
    local e = r[2]
    if rawtype(e) == "table" and e.__caught then
      if H.trackCaught ~= false then table.insert(H.caught, e.tb) end
      return false, e.msg
    end
    return false, e
  end
end

-- mock /rom/programs/shell.lua: with arguments it runs them in a REAL shell environment, like CraftOS
__REAL_SHELL_RUN = function(...) return H.shell.run(...) end
do
  PY.mkdirs(H.ROM .. "/programs")
  PY.writefile(H.ROM .. "/programs/shell.lua", [[
local args = { ... }
if #args > 0 then __REAL_SHELL_RUN(table.unpack(args)) return end
print("CraftOS 1.8 (mock interactive shell)")
]])
end

-- ------------------------------------------------------------ driver
function H.nextEvent()
  if #H.EVQ > 0 then return table.remove(H.EVQ, 1) end
  if #H.SCRIPT > 0 then
    local e = table.remove(H.SCRIPT, 1)
    if rawtype(e) == "function" then e = e() end
    if e then H.clock = H.clock + ((e[1] == "mouse_click") and 0.6 or 0.02) return e end
    return H.nextEvent()
  end
  if H.idle and #H.idle > 0 and (H.idleForce or not next(H.timers)) then local f = table.remove(H.idle, 1) local e = f() if e then return e end return H.nextEvent() end
  local bestId, bestT
  for id, t in pairs(H.timers) do if not bestT or t < bestT then bestId, bestT = id, t end end
  if bestId then H.clock = math.max(H.clock, bestT) H.timers[bestId] = nil return { "timer", bestId } end
  return nil
end
-- Runs fn in a coroutine, feeding events. Returns status, detail.
function H.runCo(fn, maxSteps)
  local co = coroutine.create(fn)
  local ev = {}
  local steps = 0
  maxSteps = maxSteps or 20000
  while true do
    local res = { coroutine.resume(co, unpack(ev)) }
    if not res[1] then
      local err = res[2]
      if rawtype(err) == "table" and err.__exit then return err.__exit end
      return "error", tostring(err) .. "\n" .. debug.traceback(co)
    end
    if coroutine.status(co) == "dead" then return "done", res[2] end
    steps = steps + 1
    if steps > maxSteps then return "timeout", "event loop exceeded " .. maxSteps .. " steps" end
    local e = H.nextEvent()
    if not e then return "blocked", "program waiting for an event but none is scripted" end
    ev = e
    if H.trace then local t = {} for i = 1, #e do t[#t+1] = tostring(e[i]) end H.say('EVENT ->', table.concat(t, ',')) end
  end
end
-- screen helpers for scripted clicks
function H.find(text, minY)
  local t = H.current.buf
  for y = minY or 1, t.h do
    local line = table.concat(t.lines[y])
    local x = line:find(text, 1, true)
    if x then return x, y end
  end
end
function H.click(text, dx, minY, dy)
  return function()
    local x, y = H.find(text, minY)
    if not x then return { "mouse_click_missing", text } end
    return { "mouse_click", 1, x + (dx or 0), y + (dy or 0) }
  end
end
function H.clickUp(text, dx, minY, dy)
  return function()
    local x, y = H.find(text, minY)
    if not x then return nil end
    return { "mouse_up", 1, x + (dx or 0), y + (dy or 0) }
  end
end
function H.clickAt(x, y) return { { "mouse_click", 1, x, y }, { "mouse_up", 1, x, y } } end
function H.push(list) for _, e in ipairs(list) do table.insert(H.SCRIPT, e) end end
function H.typeStr(s)
  local out = {}
  for i = 1, #s do out[#out + 1] = { "char", s:sub(i, i) } end
  return out
end
H.dump = function() return H.current.dump() end
H.say = function(...) local t = {} for i = 1, select('#', ...) do t[#t+1] = tostring((select(i, ...))) end io.stdout:write(table.concat(t, ' ') .. '\n') io.stdout:flush() end
H.cleanupGlobals = nil
return H
