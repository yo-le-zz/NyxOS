-- /lib/ssh/copyid.lua : ssh-copy-id [user@]host
-- Adds your key to the server's ~/.ssh/authorized_keys (asks the password once).
-- The key is sent over the network in clear: on an untrusted network copy
-- ~/.ssh/id by disk instead.
local sshlib = dofile("/lib/ssh/sshlib.lua")
local nyxlib = dofile("/lib/nyxlib.lua")
local target = ...
if not target then print("Usage: ssh-copy-id [user@]host") return end
local me = nyxlib.loadSession().username or "root"
local ok, users = pcall(dofile, "/lib/users.lua")
local u = ok and users.find(me)
local home = u and u.home or ("/home/" .. me)
local secret, fp = sshlib.readKey(home)
if not secret then print("No key: run ssh-keygen first.") return end
-- the key is appended on the server by a command run through ssh
shell.run("/lib/ssh/ssh.lua", target, "ssh-authorize " .. fp .. " " .. secret)
