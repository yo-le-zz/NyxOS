-- /bin/deluser.lua : deletes a NyxOS user
-- Usage: deluser <name>
-- Restricted to administrators. Refuses to delete the last admin.

local nyxlib = dofile("/lib/nyxlib.lua")
local users = dofile("/lib/users.lua")
local permissions = dofile("/lib/permissions.lua")

local ok, err = permissions.requirePrivileged("deleting users")
if not ok then
    print(err)
    return
end

local session = nyxlib.loadSession()
local me = session.username and users.find(session.username) or nil

local args = { ... }
local name = args[1]
if not name then
    print("Usage: deluser <name>")
    return
end

local target = users.find(name)
if not target then
    print("Unknown user: " .. name)
    return
end

if target.admin and not users.hasOtherAdmin(name) then
    print("Not allowed: this would remove the system's last administrator.")
    return
end

if name == me.username then
    print("You can't delete your own account while logged in.")
    return
end

if users.remove(name) then
    print("User '" .. name .. "' deleted (its /home folder is kept).")
else
    print("Deletion failed.")
end
