-- /bin/touch.lua : cree un fichier vide s'il n'existe pas

local args = {...}

if #args == 0 then
    print("Usage : touch <fichier> [fichier2 ...]")
    return
end

for _, name in ipairs(args) do
    local path = shell.resolve(name)
    if not fs.exists(path) then
        local f = fs.open(path, "w")
        f.close()
    end
end
