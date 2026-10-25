local function isProtected(name)
    return name == "rom"
end

local function deleteRecursive(path)
    if isProtected(fs.getName(path)) then
        return
    end

    if fs.isDir(path) then
        for _, file in ipairs(fs.list(path)) do
            deleteRecursive(fs.combine(path, file))
        end
    end

    fs.delete(path)
end


print("Suppression du systeme...")

for _, file in ipairs(fs.list("/")) do
    if not isProtected(file) then
        deleteRecursive("/" .. file)
    end
end

print("Reset termine.")
print("Redemarrage...")

sleep(2)
os.reboot()