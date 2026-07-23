-- /bin/users.lua : liste les utilisateurs configures sur cet ordinateur

local nyxlib = dofile("/lib/nyxlib.lua")
local users = dofile("/lib/users.lua")

local session = nyxlib.loadSession()
local list = users.load()

if #list == 0 then
    print("Aucun utilisateur configure.")
    return
end

for _, u in ipairs(list) do
    local marker = (session.username == u.username) and " (connecte)" or ""
    local role = u.admin and " [admin]" or ""
    print("  " .. u.username .. role .. marker)
end
