-- /lib/ssh/keygen.lua : ssh-keygen  -- creates ~/.ssh/id (your secret key)
local sshlib = dofile("/lib/ssh/sshlib.lua")
local nyxlib = dofile("/lib/nyxlib.lua")
local me = nyxlib.loadSession().username
if not me then print("No active session.") return end
local ok, users = pcall(dofile, "/lib/users.lua")
local u = ok and users.find(me)
local home = u and u.home or ("/home/" .. me)
if not fs.exists(home) then print("ssh-keygen: no home folder") return end
local path = sshlib.keyPath(home)
if fs.exists(path) then
    local _, fp = sshlib.readKey(home)
    print("A key already exists (fingerprint " .. tostring(fp) .. "). Delete " .. path .. " to make a new one.")
    return
end
if not fs.exists(home .. "/.ssh") then fs.makeDir(home .. "/.ssh") end
local secret = sshlib.newSecret()
local f = fs.open(path, "w")
f.writeLine(secret)
f.close()
print("Key created: " .. path)
print("Fingerprint: " .. sshlib.fingerprint(secret))
print("Install it on a server with: ssh-copy-id user@host")
