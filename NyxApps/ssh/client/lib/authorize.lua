-- /lib/ssh/authorize.lua : ssh-authorize <fingerprint> <secret>
-- Run on the server (by ssh-copy-id): adds a key to the current user's authorized_keys.
local sshlib = dofile("/lib/ssh/sshlib.lua")
local nyxlib = dofile("/lib/nyxlib.lua")
local fp, secret = ...
local me = nyxlib.loadSession().username
if not me or not fp or not secret then print("Usage: ssh-authorize <fingerprint> <secret>") return end
if sshlib.fingerprint(secret) ~= fp then print("ssh-authorize: fingerprint does not match the key") return end
local users = dofile("/lib/users.lua")
local u = users.find(me)
local home = u and u.home or ("/home/" .. me)
local ok, why = sshlib.addAuthorized(home, secret)
print(ok and ("Key added for " .. me .. (why and (" (" .. why .. ")") or "")) or ("ssh-authorize: " .. tostring(why)))
