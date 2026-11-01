H.idleForce = false
local function host(path) local f = assert(H.hostloadfile(path)) return f() end
local C = host(HARNESS_DIR .. "/common.lua")
C.stage(REPO .. "/NyxOS/data/lib", "lib") C.stage(REPO .. "/NyxOS/data/bin", "bin") C.stage(REPO .. "/NyxOS/data/etc", "etc")
C.stage(REPO .. "/NyxApps/python/client", "pkgpy") C.stage(REPO .. "/NyxApps/c/client", "pkgc")
local function w(p,s) local f=fs.open(p,"w") f.write(s) f.close() end
w("a.py","# hi\nprint('hello py')\n") w("b.c",'int main(){ printf("hello c\\n"); return 0; }')
H.runCo(function()
  for _,x in ipairs({{"pkgpy/install.lua"},{"pkgc/install.lua"},{"bin/interpreters.lua"},{"bin/run.lua","a.py"},{"bin/run.lua","b.c"},{"bin/run.lua","zz.rb"}}) do
    local ok,e=H.runProgram(table.unpack(x)) H.say(x[1],ok,e)
  end
  H.runProgram("pkgpy/uninstall.lua") H.runProgram("bin/interpreters.lua")
end, 20000)
H.say(H.dump())
