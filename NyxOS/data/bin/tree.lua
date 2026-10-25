-- /bin/tree.lua : shows a folder's file tree

local args = {...}

local root = shell.dir()
local maxDepth = nil

local i = 1
while i <= #args do
    local a = args[i]
    if a == "-L" then
        maxDepth = tonumber(args[i + 1])
        i = i + 1
    else
        root = a
    end
    i = i + 1
end

root = shell.resolve(root)

if not fs.exists(root) then
    print("Path not found: " .. root)
    return
end

if not fs.isDir(root) then
    print(root)
    return
end

local dirCount, fileCount = 0, 0

local function walk(path, prefix, depth)
    if maxDepth and depth > maxDepth then
        return
    end
    local entries = fs.list(path)
    table.sort(entries)
    for idx, name in ipairs(entries) do
        local full = fs.combine(path, name)
        local isLast = (idx == #entries)
        local branch = isLast and "`-- " or "|-- "
        if fs.isDir(full) then
            dirCount = dirCount + 1
            print(prefix .. branch .. name .. "/")
            local newPrefix = prefix .. (isLast and "    " or "|   ")
            walk(full, newPrefix, depth + 1)
        else
            fileCount = fileCount + 1
            print(prefix .. branch .. name)
        end
    end
end

print(root)
walk(root, "", 1)
print("")
print(dirCount .. " folder(s), " .. fileCount .. " file(s)")
