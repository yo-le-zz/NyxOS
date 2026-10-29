-- /bin/apps.lua : default desktop apps
--   apps                 lists the apps and whether they are enabled
--   apps enable <id>     shows the app on the desktop
--   apps disable <id>    hides it
local nyxlib = dofile("/lib/nyxlib.lua")
local args = { ... }
local cfg = nyxlib.loadTable("/etc/nyx-config.lua")
cfg.apps = type(cfg.apps) == "table" and cfg.apps or {}

local ids = {}
if fs.exists("/lib/apps") then
    for _, f in ipairs(fs.list("/lib/apps")) do
        local id = f:match("^(.+)%.lua$")
        if id then ids[#ids + 1] = id end
    end
end
table.sort(ids)

if (args[1] == "enable" or args[1] == "disable") and args[2] then
    local ok = false
    for _, id in ipairs(ids) do if id == args[2] then ok = true end end
    if not ok then printError("apps: unknown app '" .. args[2] .. "'") return end
    cfg.apps[args[2]] = (args[1] == "enable")
    nyxlib.saveTable("/etc/nyx-config.lua", cfg)
    print(args[2] .. (cfg.apps[args[2]] and ": enabled" or ": disabled") .. " (restart the desktop)")
    return
end
for _, id in ipairs(ids) do
    print(string.format("  %-12s %s", id, cfg.apps[id] == false and "disabled" or "enabled"))
end
print("Usage: apps enable|disable <id>")
