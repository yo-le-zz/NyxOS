-- /bin/touch.lua : creates an empty file if it doesn't exist

local args = {...}

if #args == 0 then
    print("Usage: touch <file> [file2 ...]")
    return
end

for _, name in ipairs(args) do
    local path = shell.resolve(name)
    if not fs.exists(path) then
        local f = fs.open(path, "w")
        f.close()
    end
end
