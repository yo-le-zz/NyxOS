-- /bin/adduser.lua : cree un nouvel utilisateur NyxOS
-- Usage : adduser <nom> [admin]
-- Reserve aux administrateurs.

local nyxlib = dofile("/lib/nyxlib.lua")
local users = dofile("/lib/users.lua")

local session = nyxlib.loadSession()
local me = session.username and users.find(session.username) or nil

if not me or not me.admin then
    print("Permission refusee : seul un administrateur peut creer des utilisateurs.")
    return
end

local args = { ... }
local name = args[1]
if not name then
    write("Nom du nouvel utilisateur : ")
    name = read()
end
if not name or name == "" then
    print("Nom d'utilisateur invalide.")
    return
end

local isAdmin = (args[2] == "admin")

write("Mot de passe pour " .. name .. " (optionnel) : ")
local password = read("*")

local ok, err = users.add(name, password, isAdmin)
if ok then
    print("Utilisateur '" .. name .. "' cree" .. (isAdmin and " (administrateur)" or "") .. ".")
else
    print("Echec : " .. tostring(err))
end
