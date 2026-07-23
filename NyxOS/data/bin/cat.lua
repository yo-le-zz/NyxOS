-- /bin/cat.lua : affiche le contenu d'un ou plusieurs fichiers

local args = {...}

if #args == 0 then
    print("Usage : cat <fichier> [fichier2 ...]")
    return
end

for _, name in ipairs(args) do
    local path = shell.resolve(name)
    if not fs.exists(path) or fs.isDir(path) then
        print("cat : fichier introuvable : " .. name)
    else
        local f = fs.open(path, "r")
        print(f.readAll())
        f.close()
    end
end
