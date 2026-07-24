-- /bin/adduser.lua : creates a new NyxOS user
-- Usage: adduser <name> [admin]
-- Restricted to administrators.

local nyxlib = dofile("/lib/nyxlib.lua")
local users = dofile("/lib/users.lua")
local permissions = dofile("/lib/permissions.lua")

local ok, err = permissions.requirePrivileged("creating users")
if not ok then
    print(err)
    return
end

local args = { ... }
local name = args[1]
if not name then
    write("New username: ")
    name = read()
end
if not name or name == "" then
    print("Invalid username.")
    return
end

local isAdmin = (args[2] == "admin")

write("Password for " .. name .. " (optional): ")
local password = read("*")

local ok, err = users.add(name, password, isAdmin)
if ok then
    print("User '" .. name .. "' created" .. (isAdmin and " (administrator)" or "") .. ".")
else
    print("Failed: " .. tostring(err))
end
