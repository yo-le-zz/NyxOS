-- RedioNet Server - installer (NyxOS)
-- Installs into /lib/redionet-server and creates the `redionet-server`
-- command. (The previous installer copied every file of the package into
-- "/", which overwrote the computer's own /startup.lua and main.lua.)

local source = fs.getDir(shell.getRunningProgram())
local DEST = "/lib/redionet-server"

local function copyRecursive(from, to)
    if fs.isDir(from) then
        if not fs.exists(to) then fs.makeDir(to) end
        for _, file in ipairs(fs.list(from)) do
            copyRecursive(fs.combine(from, file), fs.combine(to, file))
        end
    else
        if fs.exists(to) then fs.delete(to) end
        fs.copy(from, to)
    end
end

copyRecursive(fs.combine(source, "main.lua"), DEST .. "/main.lua")
copyRecursive(fs.combine(source, "lib"), DEST .. "/lib")

-- Command + service-friendly entry point
local launcher = fs.open("redionet-server.lua", "w")
launcher.write('shell.run("' .. DEST .. '/main.lua", ...)\n')
launcher.close()

print("RedioNet Server installed.")
print("Run it with: redionet-server   (or: service start redionet)")
