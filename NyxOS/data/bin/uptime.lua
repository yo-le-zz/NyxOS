-- /bin/uptime.lua : shows elapsed time since boot

local BOOT_FILE = "/var/run/boot.time"

if not fs.exists(BOOT_FILE) then
    print("uptime: information unavailable (reboot to initialise it).")
    return
end

local f = fs.open(BOOT_FILE, "r")
local bootTime = tonumber(f.readAll())
f.close()

if not bootTime then
    print("uptime: information unavailable.")
    return
end

local elapsedMs = os.epoch("utc") - bootTime
local seconds = math.floor(elapsedMs / 1000)
local days = math.floor(seconds / 86400)
seconds = seconds % 86400
local hours = math.floor(seconds / 3600)
seconds = seconds % 3600
local minutes = math.floor(seconds / 60)
seconds = seconds % 60

local parts = {}
if days > 0 then table.insert(parts, days .. "d") end
if hours > 0 or days > 0 then table.insert(parts, hours .. "h") end
table.insert(parts, minutes .. "m")
table.insert(parts, seconds .. "s")

print("up " .. table.concat(parts, " "))
