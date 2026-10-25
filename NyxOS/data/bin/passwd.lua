-- /bin/passwd.lua : changes a user's password
-- Usage: passwd            (changes your own password)
--        passwd <name>     (changes another account's password,
--                            restricted to administrators)

local nyxlib = dofile("/lib/nyxlib.lua")
local users = dofile("/lib/users.lua")
local permissions = dofile("/lib/permissions.lua")

local session = nyxlib.loadSession()
local me = session.username and users.find(session.username) or nil

local args = { ... }
local target = args[1]

if target and target ~= (me and me.username) then
    local ok, err = permissions.requirePrivileged("changing another user's password")
    if not ok then
        print(err)
        return
    end
    local user = users.find(target)
    if not user then
        print("Unknown user: " .. target)
        return
    end
    write("New password for " .. target .. " (empty for none): ")
    local newPass = read("*")
    write("Confirm: ")
    local confirm = read("*")
    if newPass ~= confirm then
        print("Passwords don't match.")
        return
    end
    users.setPassword(target, newPass)
    print("Password for '" .. target .. "' updated.")
    return
end

if not me then
    print("No active session (logged in via the recovery shell?).")
    return
end

if me.password and me.password ~= "" then
    write("Current password: ")
    local current = read("*")
    -- Use users.checkPassword to handle hashed passwords
    local users = dofile("/lib/users.lua")
    if not users.checkPassword(me.username, current) then
        print("Incorrect password.")
        return
    end
end

write("New password (empty for none): ")
local newPass = read("*")
write("Confirm: ")
local confirm = read("*")

if newPass ~= confirm then
    print("Passwords don't match.")
    return
end

users.setPassword(me.username, newPass)
print("Password updated.")
