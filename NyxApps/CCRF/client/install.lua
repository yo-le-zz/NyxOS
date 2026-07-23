-- CCRF - ComputerCraftResetFactory
-- install.lua : a lancer depuis la disquette (floppy disk)
-- Installe CCRF dans /ccrf_data et cree la commande unique "ccrf"
-- (ccrf = reset usine, ccrf config = configuration, ccrf uninstall = desinstalle)

local function here()
    return fs.getDir(shell.getRunningProgram())
end

local base = here()
local DEST = "/ccrf_data"

local function ensureDir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

ensureDir(DEST)
ensureDir(DEST .. "/lib")
ensureDir(DEST .. "/data")
ensureDir(DEST .. "/data/logs")

print("Installation de CCRF...")

-- Fichiers toujours reinstalles/ecrases (code du programme)
local coreFiles = {
    { src = "reset.lua",           dest = DEST .. "/reset.lua" },
    { src = "uninstall.lua",       dest = DEST .. "/uninstall.lua" },
    { src = "lib/scanner.lua",     dest = DEST .. "/lib/scanner.lua" },
    { src = "lib/permissions.lua", dest = DEST .. "/lib/permissions.lua" },
    { src = "lib/ui.lua",          dest = DEST .. "/lib/ui.lua" },
}

for _, item in ipairs(coreFiles) do
    local srcPath = fs.combine(base, item.src)
    if not fs.exists(srcPath) then
        print("ERREUR : fichier manquant sur la disquette -> " .. item.src)
        return
    end
    if fs.exists(item.dest) then
        fs.delete(item.dest)
    end
    fs.copy(srcPath, item.dest)
    print("  " .. item.dest .. " installe.")
end

-- Fichiers conserves s'ils existent deja (config utilisateur, logs)
-- pour ne pas ecraser une config existante lors d'une reinstallation
local preservedFiles = {
    { src = "config.json",         dest = DEST .. "/config.json" },
    { src = "data/logs/reset.log", dest = DEST .. "/data/logs/reset.log" },
}

for _, item in ipairs(preservedFiles) do
    if fs.exists(item.dest) then
        print("  " .. item.dest .. " deja present, conserve.")
    else
        local srcPath = fs.combine(base, item.src)
        if fs.exists(srcPath) then
            fs.copy(srcPath, item.dest)
        else
            local f = fs.open(item.dest, "w")
            f.write("")
            f.close()
        end
        print("  " .. item.dest .. " installe.")
    end
end

-- Commande racine unique, utilisable partout dans le systeme.
-- "ccrf uninstall" delegue vers uninstall.lua, tout le reste (rien, ou "config")
-- delegue vers reset.lua en transmettant les arguments.
local launcherCode = 'local args = { ... }\n'
    .. 'if args[1] == "uninstall" then\n'
    .. '    shell.run("' .. DEST .. '/uninstall.lua")\n'
    .. 'else\n'
    .. '    shell.run("' .. DEST .. '/reset.lua", ...)\n'
    .. 'end\n'

local f = fs.open("/ccrf", "w")
f.write(launcherCode)
f.close()

print("")
print("Installation terminee !")
print("Commandes disponibles : ccrf | ccrf config | ccrf uninstall")
