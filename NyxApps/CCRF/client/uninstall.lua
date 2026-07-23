-- CCRF - ComputerCraftResetFactory
-- uninstall.lua : desinstalle CCRF proprement
-- Installe dans /ccrf_data/uninstall.lua, appelable via la commande "ccrf uninstall"

local BASE = "/ccrf_data"
local permissions = dofile(BASE .. "/lib/permissions.lua")

local config = permissions.loadConfig()

if not permissions.checkPassword(config) then
    print("Mot de passe incorrect.")
    return
end

write("Confirmer la desinstallation de CCRF ? (o/n) : ")
local answer = read()
if answer:lower() ~= "o" then
    print("Annule.")
    return
end

-- Supprime tout le dossier CCRF (lib/, data/, config.json, reset.lua, uninstall.lua)
if fs.exists(BASE) then
    fs.delete(BASE)
end

-- Supprime la commande racine unique
if fs.exists("/ccrf") then
    fs.delete("/ccrf")
end

print("CCRF a ete desinstalle.")
