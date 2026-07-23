local baseDir = fs.getDir(shell.getRunningProgram())

local LIB_DIR = "/lib/cctchat"
local ETC_DIR = "/etc/cctchat"


local function copyDir(src, dst)
    if not fs.exists(dst) then
        fs.makeDir(dst)
    end

    for _, name in ipairs(fs.list(src)) do
        local srcPath = fs.combine(src, name)
        local dstPath = fs.combine(dst, name)

        if fs.isDir(srcPath) then
            copyDir(srcPath, dstPath)
        else
            fs.copy(srcPath, dstPath)
        end
    end
end


print("Installation de CCTchat Client...")


-- Installation des libs
copyDir(
    fs.combine(baseDir, "libs"),
    LIB_DIR
)

-- Installation du programme principal
fs.copy(
    fs.combine(baseDir, "main.lua"),
    LIB_DIR .. "/main.lua"
)


-- Configuration
if not fs.exists(ETC_DIR) then
    fs.makeDir(ETC_DIR)
end


if not fs.exists(ETC_DIR .. "/config.lua") then
    local f = fs.open(ETC_DIR .. "/config.lua", "w")

    f.write([[
return {
    server = nil,
    username = nil
}
]])

    f.close()
end


-- Création commande NyxOS
local launcher = fs.open("cct-client.lua", "w")

launcher.write([[
shell.run("/lib/cctchat/cct-client.lua", ...)
]])

launcher.close()


print("CCTchat Client installé.")
print("Commande : cct-client")