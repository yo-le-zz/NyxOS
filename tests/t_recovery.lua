-- recovery --boot rebuilds folders, boot.json, fallback startup when /boot is gone
H.idleForce = false
local function host(path) local f = assert(H.hostloadfile(path)) return f() end
local C = host(HARNESS_DIR .. "/common.lua")
C.stage(REPO .. "/NyxOS/data/bin", "bin")
local fails = 0
local function check(n, c) if not c then fails = fails + 1 end H.say(c and "PASS" or "FAIL", n) end
local function w(p,s) local f=fs.open(p,"w") f.write(s) f.close() end
w("startup.lua", 'shell.run("/boot/nyxloader/nyxloader.lua")')
w("nyxos.lua", "print('x')")
local saved = http
H.runCo(function()
  http = nil
  local ok, e = H.runProgram("bin/recovery.lua", "--boot")
  check("ran", ok)
  check("folders", fs.exists("/etc/apt") and fs.exists("/var/log") and fs.exists("/home") and fs.exists("/boot"))
  check("boot.json", fs.exists("/boot.json"))
  check("config", fs.exists("/etc/nyx-config.lua"))
  local f = fs.open("/startup.lua", "r") local s = f.readAll() f.close()
  check("fallback startup", s:find("nyxos.lua", 1, true) and not s:find("/boot/nyxloader", 1, true))
end, 50000)
http = saved
H.say(fails == 0 and "ALL PASS" or ("FAILURES: " .. fails))
