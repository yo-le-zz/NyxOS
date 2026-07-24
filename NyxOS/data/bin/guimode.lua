-- /bin/guimode.lua : shows or changes whether NyxOS boots with the
-- graphical interface (Basalt) or stays in text mode.
-- Usage:
--   guimode           shows the current setting
--   guimode on|off     enables/disables the graphical interface

local nyxlib = dofile("/lib/nyxlib.lua")
local args = { ... }

if not args[1] then
    print("Graphical interface: " .. (nyxlib.guiEnabled() and "on" or "off"))
    print("Usage: guimode on|off")
    return
end

if args[1] ~= "on" and args[1] ~= "off" then
    print("Usage: guimode on|off")
    return
end

local cfg = nyxlib.loadTable("/etc/nyx-config.lua")
cfg.gui = (args[1] == "on")
nyxlib.saveTable("/etc/nyx-config.lua", cfg)

print("Graphical interface " .. (cfg.gui and "enabled" or "disabled") .. ". Reboot to apply: reboot")
