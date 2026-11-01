-- shared helpers for scenarios
local C = {}
function C.stage(realsrc, sbdest)   -- copy a real file/dir into sandbox path
  local rp = H.SB .. "/" .. sbdest
  PY.mkdirs(PY.dirname(rp))
  PY.copy(realsrc, rp)
end
function C.setupHttp()
  H.httpmap["https://raw.githubusercontent.com/yo-le-zz/NyxOS/main/"] = REPO
  -- fake NyxLoader (separate project): its webinstall drops a /startup.lua
  local fake = HARNESS_DIR .. "/fake_nyxloader"
  H.httpmap["https://raw.githubusercontent.com/yo-le-zz/NyxLoader/main/"] = fake
end
function C.runTo(fn, maxSteps)
  local st, d = H.runCo(fn, maxSteps)
  return st, d
end
function C.report(st, d)
  H.say("== status:", st, d and ("\n" .. tostring(d)) or "")
  H.say("== screen ==")
  H.say(H.dump())
  H.say("== end screen ==")
  if #H.log > 0 then H.say("== notes:", table.concat(H.log, "; ")) end
end
return C
