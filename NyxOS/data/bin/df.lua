-- /bin/df.lua : shows available disk space

local nyxlib = dofile("/lib/nyxlib.lua")

print(string.format("%-20s %10s %10s", "Mount point", "Free", "Capacity"))

local function printRoot(path)
    local free = fs.getFreeSpace(path)
    local capacity = fs.getCapacity and fs.getCapacity(path) or nil
    print(string.format("%-20s %10s %10s", path, nyxlib.formatSize(free), nyxlib.formatSize(capacity)))
end

printRoot("/")

-- Mounted disks/floppies (e.g. connected disk drives)
for _, name in ipairs(fs.list("/")) do
    local path = "/" .. name
    if fs.isDir(path) and fs.isDriveRoot and fs.isDriveRoot(path) then
        printRoot(path)
    end
end
