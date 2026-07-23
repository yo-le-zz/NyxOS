-- CCRF - uninstall.lua
-- Nettoyage avant suppression par NyxOS

local BASE = "/usr/lib/ccrf"

local permissions = dofile(BASE .. "/lib/permissions.lua")

local config = permissions.loadConfig()

if not permissions.checkPassword(config) then
    print("Mot de passe incorrect.")
    return
end

print("Nettoyage de CCRF...")

-- Supprimer uniquement les données temporaires
if fs.exists("/var/lib/ccrf") then
    fs.delete("/var/lib/ccrf")
end

print("Nettoyage termine.")