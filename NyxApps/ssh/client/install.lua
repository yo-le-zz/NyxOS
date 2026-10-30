-- SSH package - installer (NyxOS)
local here = fs.getDir(shell.getRunningProgram())

fs.makeDir("/lib/ssh")
for _, name in ipairs({ "sshlib", "sshd", "ssh", "scp", "keygen", "copyid", "authorize" }) do
    local src = fs.combine(here, "lib/" .. name .. ".lua")
    local dst = "/lib/ssh/" .. name .. ".lua"
    if fs.exists(dst) then fs.delete(dst) end
    fs.copy(src, dst)
end

-- Commands (files written to "/" are moved to /bin by apt)
local commands = {
    ["ssh.lua"] = '/lib/ssh/ssh.lua',
    ["scp.lua"] = '/lib/ssh/scp.lua',
    ["ssh-keygen.lua"] = '/lib/ssh/keygen.lua',
    ["ssh-copy-id.lua"] = '/lib/ssh/copyid.lua',
    ["ssh-authorize.lua"] = '/lib/ssh/authorize.lua',
}
for file, program in pairs(commands) do
    local f = fs.open(file, "w")
    f.write('shell.run("' .. program .. '", ...)\n')
    f.close()
end
print("ssh installed: ssh, scp, ssh-keygen, ssh-copy-id. Server: service enable sshd")
