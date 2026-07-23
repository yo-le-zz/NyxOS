-- CCRF - lib/scanner.lua : parcours des fichiers/dossiers a supprimer

local scanner = {}

-- isProtectedFn(path) -> bool, fourni par l'appelant (voir lib/permissions.lua)
-- Retourne deux listes : files (fichiers) et dirs (dossiers, ajoutes apres
-- leurs enfants afin d'etre supprimes du plus profond au moins profond).
function scanner.scan(path, isProtectedFn)
    local files, dirs = {}, {}
    for _, name in ipairs(fs.list(path)) do
        local full = fs.combine(path, name)
        if not isProtectedFn(full) then
            if fs.isDir(full) then
                local subFiles, subDirs = scanner.scan(full, isProtectedFn)
                for _, f in ipairs(subFiles) do table.insert(files, f) end
                for _, d in ipairs(subDirs) do table.insert(dirs, d) end
                table.insert(dirs, full)
            else
                table.insert(files, full)
            end
        end
    end
    return files, dirs
end

return scanner
