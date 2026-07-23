-- /bin/find.lua : recherche des fichiers par nom (motif avec '*')
-- Usage : find [dossier] -name <motif>

local args = {...}
local root = shell.dir()
local pattern = nil

local i = 1
while i <= #args do
    if args[i] == "-name" then
        pattern = args[i + 1]
        i = i + 1
    else
        root = args[i]
    end
    i = i + 1
end

if not pattern then
    print("Usage : find [dossier] -name <motif>")
    return
end

root = shell.resolve(root)

local escaped = pattern:gsub("[%(%)%.%%%+%-%[%]%^%$%?]", "%%%1")
local luaPattern = "^" .. escaped:gsub("%*", ".*") .. "$"

local function walk(path)
    if not fs.exists(path) then return end
    if fs.isDir(path) then
        for _, name in ipairs(fs.list(path)) do
            walk(fs.combine(path, name))
        end
    else
        if fs.getName(path):match(luaPattern) then
            print(path)
        end
    end
end

walk(root)
