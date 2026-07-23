-- /bin/tail.lua : affiche les N dernieres lignes d'un fichier
-- Usage : tail [-n N] <fichier>

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
    print("Usage : tail [-n N] <fichier>")
    return
end

local path = shell.resolve(file)
if not fs.exists(path) or fs.isDir(path) then
    print("tail : fichier introuvable : " .. file)
    return
end

local f = fs.open(path, "r")
local lines = {}
local line = f.readLine()
while line do
    table.insert(lines, line)
    line = f.readLine()
end
f.close()

local start = math.max(1, #lines - n + 1)
for j = start, #lines do
    print(lines[j])
end
