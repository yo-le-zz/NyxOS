-- SSH package - uninstaller (NyxOS)
for _, path in ipairs({ "/lib/ssh", "/bin/ssh.lua", "/bin/scp.lua", "/bin/ssh-keygen.lua",
    "/bin/ssh-copy-id.lua", "/bin/ssh-authorize.lua" }) do
    if fs.exists(path) then fs.delete(path) print("Removed " .. path) end
end
print("ssh uninstalled (your ~/.ssh keys were kept).")
