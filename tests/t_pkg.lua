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
H.idle = {
 function() H.push({{"mouse_click",1,2,19}}) end,
 function() H.push({{"mouse_click",1,6,5}}) end,
 function() end,
 function() H.say("STORE:\n"..H.dump()) H.push(H.clickAt(14,8)) end,
 function() H.say("SEL:\n"..H.dump()) H.push(H.clickAt(15,2)) end,
 function() H.say("INSTALLED:\n"..H.dump()) return {"terminate"} end }
local st, d = H.runCo(function()
  local ui = dofile("/lib/desktop.lua")
  local ok, r = pcall(ui.run) H.say("run ->", ok, r)
end, 60000)

H.say("ERR", #H.caught) for i,tb in ipairs(H.caught) do if not tb:find("not a peripheral") and i<9 then H.say(tb) end end