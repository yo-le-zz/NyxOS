-- /bin/head.lua : affiche les N premieres lignes d'un fichier
-- Usage : head [-n N] <fichier>

local args = {...}
local n = 10
local file

local i = 1
while i <= #args do
    if args[i] == "-n" then
        n = tonumber(args[i + 1]) or n
        i = i + 1
    else
        file = args[i]
    end
    i = i + 1
end

if not file then
    print("Usage : head [-n N] <fichier>")
    return
end

local path = shell.resolve(file)
if not fs.exists(path) or fs.isDir(path) then
    print("head : fichier introuvable : " .. file)
    return
end

local f = fs.open(path, "r")
for _ = 1, n do
    local line = f.readLine()
    if not line then break end
    print(line)
end
f.close()
