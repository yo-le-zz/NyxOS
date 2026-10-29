-- /bin/resources.lua : shows how NyxOS adapts to the available storage
--   resources            capacity, free space, tier and the limits in use
--   resources cleanup    frees caches and temporary files
local res = dofile("/lib/resources.lua")
local args = { ... }

local function fmt(n)
    if n == math.huge then return "?" end
    if n >= 1024 * 1024 then return string.format("%.1f MB", n / 1024 / 1024) end
    return string.format("%.0f KB", n / 1024)
end

if args[1] == "cleanup" then
    local freed = res.cleanup(args[2] == "-a")
    print("Freed " .. fmt(freed) .. ". Free space: " .. fmt(res.free()))
    return
end

local b = res.budget(true)
print("Capacity : " .. fmt(b.capacity) .. "   Free: " .. fmt(b.free) .. "   (" .. b.pressure .. ")")
print("Tier     : " .. b.tier .. "   (recomputed every 30 s: a bigger disk is picked up without a reinstall)")
print("Log size : " .. fmt(b.logMax) .. "   Log view: " .. b.logView .. " lines")
print("Terminal : " .. b.shellLines .. " lines   History: " .. b.history)
print("Autosave : every " .. b.autosave .. " s   apt cache: " .. (b.treeCache and "on" or "off"))
print("Usage: resources cleanup [-a]")
