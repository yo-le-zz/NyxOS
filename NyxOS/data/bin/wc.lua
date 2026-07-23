-- /bin/wc.lua : compte lignes/mots/caracteres d'un fichier
-- Usage : wc <fichier>

local args = {...}
local file = args[1]

if not file then
    print("Usage : wc <fichier>")
    return
end

local path = shell.resolve(file)
if not fs.exists(path) or fs.isDir(path) then
    print("wc : fichier introuvable : " .. file)
    return
end

local f = fs.open(path, "r")
local content = f.readAll()
f.close()

local lines = 0
for _ in content:gmatch("\n") do lines = lines + 1 end
local words = 0
for _ in content:gmatch("%S+") do words = words + 1 end
local chars = #content

print(lines .. " " .. words .. " " .. chars .. " " .. file)
