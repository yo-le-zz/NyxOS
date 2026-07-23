-- /bin/passwd.lua : change le mot de passe d'un utilisateur
-- Usage : passwd            (change son propre mot de passe)
--         passwd <nom>      (change le mot de passe d'un autre compte,
--                             reserve aux administrateurs)

local nyxlib = dofile("/lib/nyxlib.lua")
local users = dofile("/lib/users.lua")

local session = nyxlib.loadSession()
local me = session.username and users.find(session.username) or nil

local args = { ... }
local target = args[1]

if target and target ~= (me and me.username) then
    if not me or not me.admin then
        print("Permission refusee : seul un administrateur peut changer le mot de passe d'un autre utilisateur.")
        return
    end
    local user = users.find(target)
    if not user then
        print("Utilisateur inconnu : " .. target)
        return
    end
    write("Nouveau mot de passe pour " .. target .. " (vide pour aucun) : ")
    local newPass = read("*")
    write("Confirme : ")
    local confirm = read("*")
    if newPass ~= confirm then
        print("Les mots de passe ne correspondent pas.")
        return
    end
    users.setPassword(target, newPass)
    print("Mot de passe de '" .. target .. "' mis a jour.")
    return
end

if not me then
    print("Aucune session active (connecte via le shell de secours ?).")
    return
end

if me.password and me.password ~= "" then
    write("Mot de passe actuel : ")
    local current = read("*")
    -- Utilise users.checkPassword pour gérer les mots de passe hachés
    local users = dofile("/lib/users.lua")
    if not users.checkPassword(me.username, current) then
        print("Mot de passe incorrect.")
        return
    end
end

write("Nouveau mot de passe (vide pour aucun) : ")
local newPass = read("*")
write("Confirme : ")
local confirm = read("*")

if newPass ~= confirm then
    print("Les mots de passe ne correspondent pas.")
    return
end

users.setPassword(me.username, newPass)
print("Mot de passe mis a jour.")
