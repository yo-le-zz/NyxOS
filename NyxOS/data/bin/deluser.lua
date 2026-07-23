-- /bin/deluser.lua : supprime un utilisateur NyxOS
-- Usage : deluser <nom>
-- Reserve aux administrateurs. Refuse de supprimer le dernier admin.

local nyxlib = dofile("/lib/nyxlib.lua")
local users = dofile("/lib/users.lua")

local session = nyxlib.loadSession()
local me = session.username and users.find(session.username) or nil

if not me or not me.admin then
    print("Permission refusee : seul un administrateur peut supprimer des utilisateurs.")
    return
end

local args = { ... }
local name = args[1]
if not name then
    print("Usage : deluser <nom>")
    return
end

local target = users.find(name)
if not target then
    print("Utilisateur inconnu : " .. name)
    return
end

if target.admin and not users.hasOtherAdmin(name) then
    print("Impossible : ce serait le dernier administrateur du systeme.")
    return
end

if name == me.username then
    print("Impossible de se supprimer soi-meme pendant qu'on est connecte.")
    return
end

if users.remove(name) then
    print("Utilisateur '" .. name .. "' supprime (son dossier /home est conserve).")
else
    print("Echec de la suppression.")
end
