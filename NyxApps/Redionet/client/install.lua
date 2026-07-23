local here = fs.getDir(shell.getRunningProgram())

local function copyRecursive(src, dst)
    if fs.isDir(src) then
        fs.makeDir(dst)

        for _, file in ipairs(fs.list(src)) do
            copyRecursive(
                fs.combine(src, file),
                fs.combine(dst, file)
            )
        end
    else
        fs.copy(src, dst)
    end
end


-- Installer les fichiers internes
fs.makeDir("/lib/redionet")

fs.copy(
    fs.combine(here, "client.lua"),
    "/lib/redionet/client.lua"
)

copyRecursive(
    fs.combine(here, "client_lib"),
    "/lib/redionet/client_lib"
)


-- Créer la commande NyxOS
local launcher = fs.open("redionet.lua", "w")
launcher.write([[
shell.run("/lib/redionet/client.lua")
]])
launcher.close()


print("RedioNet Client installé !")