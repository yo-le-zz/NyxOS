-- CCRF - ComputerCraftResetFactory
-- install.lua NyxOS

local function here()
    return fs.getDir(shell.getRunningProgram())
end

local base = here()

local LIB_DEST = "/usr/lib/ccrf"
local ETC_DEST = "/etc/ccrf"
local VAR_DEST = "/var/lib/ccrf"


local function ensureDir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end


ensureDir(LIB_DEST)
ensureDir(LIB_DEST .. "/lib")

ensureDir(ETC_DEST)

ensureDir(VAR_DEST)
ensureDir(VAR_DEST .. "/logs")


print("Installation de CCRF...")


local coreFiles = {
    { src = "ccrf.lua",            dest = LIB_DEST .. "/ccrf.lua" },
    { src = "uninstall.lua",       dest = LIB_DEST .. "/uninstall.lua" },

    { src = "lib/scanner.lua",     dest = LIB_DEST .. "/lib/scanner.lua" },
    { src = "lib/permissions.lua", dest = LIB_DEST .. "/lib/permissions.lua" },
    { src = "lib/ui.lua",          dest = LIB_DEST .. "/lib/ui.lua" },
}


for _, item in ipairs(coreFiles) do
    local srcPath = fs.combine(base, item.src)

    if not fs.exists(srcPath) then
        print("ERREUR : fichier manquant -> " .. item.src)
        return
    end

    if fs.exists(item.dest) then
        fs.delete(item.dest)
    end

    fs.copy(srcPath, item.dest)
    print("  " .. item.dest)
end


-- Configuration par défaut
local configSource = fs.combine(base, "config/config.json")
local configDest = ETC_DEST .. "/config/config.json"

ensureDir(ETC_DEST .. "/config")

if fs.exists(configDest) then
    print("  Configuration conservée.")
else
    if fs.exists(configSource) then
        fs.copy(configSource, configDest)
        print("  Configuration installée.")
    else
        local f = fs.open(configDest, "w")
        f.write(textutils.serialiseJSON({
            password = "",
            blacklist = {}
        }))
        f.close()

        print("  Configuration par défaut créée.")
    end
end


-- Log conservé
if not fs.exists(VAR_DEST .. "/logs/reset.log") then
    local f = fs.open(VAR_DEST .. "/logs/reset.log", "w")
    f.write("")
    f.close()
end


-- Création de la commande ccrf
local launcher = fs.open("ccrf.lua", "w")

launcher.write(
[[
local args = { ... }

if args[1] == "uninstall" then
    shell.run("/usr/lib/ccrf/uninstall.lua")
else
    shell.run("/usr/lib/ccrf/ccrf.lua", ...)
end
]]
)

launcher.close()


print("")
print("Installation terminee !")
print("Commande : ccrf")