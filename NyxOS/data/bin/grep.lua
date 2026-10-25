-- /bin/grep.lua : searches for text within a file
-- Usage: grep <pattern> <file>

local args = {...}
local pattern = args[1]
local file = args[2]

if not pattern or not file then
    print("Usage: grep <pattern> <file>")
    return
end

local path = shell.resolve(file)
if not fs.exists(path) or fs.isDir(path) then
    print("grep: file not found: " .. file)
    return
end

local f = fs.open(path, "r")
local lineNum = 0
local line = f.readLine()
while line do
    lineNum = lineNum + 1
    if line:find(pattern) then
        print(lineNum .. ": " .. line)
    end
    line = f.readLine()
end
f.close()
