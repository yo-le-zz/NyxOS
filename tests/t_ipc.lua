-- IPC queues + priority API
H.idleForce = false
local function host(path) local f = assert(H.hostloadfile(path)) return f() end
local C = host(HARNESS_DIR .. "/common.lua")
C.stage(REPO .. "/NyxOS/data/lib", "lib") C.stage(REPO .. "/NyxOS/data/bin", "bin") C.stage(REPO .. "/NyxOS/data/etc", "etc")
local fails = 0
local function check(name, cond) if not cond then fails = fails + 1 end H.say(cond and "PASS" or "FAIL", name) end
H.runCo(function()
  local ipc = dofile("/lib/ipc.lua")
  ipc.send("q", "a") ipc.send("q", "b")
  check("count", ipc.count("q") == 2)
  check("peek", ipc.peek("q") == "a")
  check("fifo", ipc.receive("q") == "a" and ipc.receive("q") == "b")
  check("empty", ipc.count("q") == 0)
  check("timeout", ipc.receive("q", 0.1) == nil)
  for i = 1, 300 do ipc.send("big", i) end
  check("cap 256", ipc.count("big") == 256 and ipc.peek("big") == 45)
  local sv = dofile("/lib/services.lua")
  _G.NYX_SCHED = { threads = { { pid = 7, co = coroutine.create(function() end) } }, pseudo = {}, nextPid = 8 }
  check("setNice ok", sv.setNice(7, 5) and _G.NYX_SCHED.threads[1].nice == 5)
  sv.setNice(7, 99) check("nice clamp", _G.NYX_SCHED.threads[1].nice == 19)
  check("setNice unknown", sv.setNice(99, 1) == false)
  _G.NYX_SCHED = nil
end, 20000)
H.say(fails == 0 and "ALL PASS" or ("FAILURES: " .. fails))
