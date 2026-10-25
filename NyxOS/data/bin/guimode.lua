-- /bin/guimode.lua : shows or changes the graphical interface mode
-- Usage:
--   guimode                shows the current setting
--   guimode on|off          enables/disables the graphical interface
--   guimode shell|desktop    picks which graphical UI boots by default
--                            (only matters when the interface is on)

local nyxlib = dofile("/lib/nyxlib.lua")
local args = { ... }

local cfg = nyxlib.loadTable("/etc/nyx-config.lua")

if not args[1] then
    print("Graphical interface: " .. (nyxlib.guiEnabled() and "on" or "off"))
    print("UI mode: " .. (cfg.uiMode or "shell"))
    print("Usage: guimode on|off|shell|desktop")
    return
end

if args[1] == "on" or args[1] == "off" then
    cfg.gui = (args[1] == "on")
    nyxlib.saveTable("/etc/nyx-config.lua", cfg)
    print("Graphical interface " .. (cfg.gui and "enabled" or "disabled") .. ". Reboot to apply: reboot")
    return
end

if args[1] == "shell" or args[1] == "desktop" then
    cfg.uiMode = args[1]
    nyxlib.saveTable("/etc/nyx-config.lua", cfg)
    print("UI mode set to '" .. args[1] .. "'. Reboot to apply: reboot")
    return
end

print("Usage: guimode on|off|shell|desktop")
