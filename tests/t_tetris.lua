H.idleForce = true
local function host(path) local f = assert(H.hostloadfile(path)) return f() end
local C = host(HARNESS_DIR .. "/common.lua")
C.stage(REPO .. "/NyxOS/data/lib", "lib")
C.stage(REPO .. "/NyxOS/data/bin", "bin")
C.stage(REPO .. "/NyxOS/data/etc", "etc")
local f = fs.open("etc/passwd", "w") f.write(textutils.serialize({{username="alice",password="",home="/home/alice",admin=true}})) f.close()
fs.makeDir("home/alice") fs.makeDir("var/run") fs.makeDir("var/apt")
local nyxlib = dofile("/lib/nyxlib.lua") nyxlib.saveSession("alice")
local lst = {}
for i,n in ipairs({"ssh","cctchat","ccrf","redionet","foo","bar","baz","qux","zed"}) do lst[#lst+1]={name=n,version="1.0."..i,description="Package "..n,author="me"} end
f = fs.open("var/apt/store-cache.lua","w") f.write(textutils.serialize({at=os.epoch("utc"),list=lst})) f.close()
local apps = {"Tetris"}
local function rowOf(name)
  local y, ry, rc = 0
  for line in (H.dump().."\n"):gmatch("([^\n]*)\n") do
    y = y + 1
    local c = line:sub(1,40):find(name, 1, true) if c then ry, rc = y, c end
  end
  return ry, rc
end
H.idle = {}
local function add(f) H.idle[#H.idle+1] = f end
add(function() H.say("start") end)
for _, a in ipairs(apps) do
  add(function() H.push({{"mouse_click",1,2,19}}) end)
  add(function() local y, c = rowOf(a) H.say("row", a, y) if y then H.push({{"mouse_click",1,c+1,y}}) end end)
  add(function() end)
  for i=1,40 do add(function() local ks={keys.left,keys.up,keys.right,keys.space,keys.down,keys.a,keys.d,keys.w} H.push({{"key",ks[i%8+1]}}) end) end
  add(function() H.say("TETRIS:\n"..H.dump()) end)
  add(function() H.push({{"mouse_click",1,30,1}}) end)
  add(function() H.say(a..":\n"..H.dump()) H.push({{"mouse_click",1,40,1}}) end)
end
add(function() return {"terminate"} end)
local st, d = H.runCo(function()
  local ui = dofile("/lib/desktop.lua")
  local ok, r = pcall(ui.run) H.say("run ->", ok, r)
end, 60000)

H.say("ERR", #H.caught) for i,tb in ipairs(H.caught) do if not tb:find("not a peripheral") and not tb:find("specs.lua") then H.say(tb:sub(1,600)) end end
if fs.exists("/var/log/nyxos.log") then local f=fs.open("/var/log/nyxos.log","r") H.say(f.readAll():sub(-1500)) f.close() end
