-- /bin/sudo.lua : run a command with administrator privileges
-- Usage:
--   sudo <command> [args...]   run <command> with a temporary sudo session
--   sudo -v                    refresh/extend the current sudo session
--   sudo -k                    drop the current sudo session immediately

local nyxlib = dofile("/lib/nyxlib.lua")
local users = dofile("/lib/users.lua")
local permissions = dofile("/lib/permissions.lua")

local args = { ... }

local session = nyxlib.loadSession()
if not session.username then
    print("No active session (logged in via the recovery shell?).")
    return
end

local me = session.username

if args[1] == "-k" then
    permissions.revokeSudo(me)
    print("Sudo session dropped.")
    return
end

if not permissions.isSudoer(me) then
    print("Permission denied: " .. me .. " is not allowed to use sudo (see /etc/sudoers.lua).")
    return
end

local function ensureAuthenticated()
    if permissions.sudoActive(me) then
        permissions.grantSudo(me) -- sliding window, like real sudo
        return true
    end
    write("[sudo] password for " .. me .. ": ")
    local pass = read("*")
    if not users.checkPassword(me, pass) then
        print("Sorry, try again.")
        return false
    end
    permissions.grantSudo(me)
    return true
end

if args[1] == "-v" then
    if ensureAuthenticated() then
        print("Sudo session refreshed (" .. math.floor(permissions.DEFAULT_TIMEOUT / 1000) .. "s).")
    end
    return
end

if #args == 0 then
    print("Usage: sudo <command> [args...]")
    print("       sudo -v   (refresh session)")
    print("       sudo -k   (drop session)")
    return
end

if not ensureAuthenticated() then
    return
end

local command = args[1]
local cmdArgs = {}
for i = 2, #args do
    table.insert(cmdArgs, args[i])
end

shell.run(command, table.unpack(cmdArgs))
