-- /bin/users.lua : lists the users configured on this computer

local nyxlib = dofile("/lib/nyxlib.lua")
local users = dofile("/lib/users.lua")

local session = nyxlib.loadSession()
local list = users.load()

if #list == 0 then
    print("No users configured.")
    return
end

for _, u in ipairs(list) do
    local marker = (session.username == u.username) and " (logged in)" or ""
    local role = u.admin and " [admin]" or ""
    print("  " .. u.username .. role .. marker)
end
