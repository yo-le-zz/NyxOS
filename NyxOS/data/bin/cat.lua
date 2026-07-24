-- /bin/cat.lua : prints the contents of one or more files

local args = {...}

if #args == 0 then
    print("Usage: cat <file> [file2 ...]")
    return
end

for _, name in ipairs(args) do
    local path = shell.resolve(name)
    if not fs.exists(path) or fs.isDir(path) then
        print("cat: file not found: " .. name)
    else
        local f = fs.open(path, "r")
        print(f.readAll())
        f.close()
    end
end
