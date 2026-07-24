-- /bin/wc.lua : counts lines/words/characters in a file
-- Usage: wc <file>

local args = {...}
local file = args[1]

if not file then
    print("Usage: wc <file>")
    return
end

local path = shell.resolve(file)
if not fs.exists(path) or fs.isDir(path) then
    print("wc: file not found: " .. file)
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
