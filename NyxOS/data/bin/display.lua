-- /bin/display.lua : manages the connected screen (monitor)
-- Usage:
--   display          shows the currently configured screen
--   display scan      re-runs detection (hot-plugged screen)
--   display scale <n> changes the connected screen's text scale

local nyxdisplay = dofile("/lib/display.lua")
local args = {...}

if args[1] == "scan" then
    local ok = nyxdisplay.setup(false)
    if not ok then
        print("No screen (monitor) detected.")
    end
    return
end

if args[1] == "scale" then
    local scale = tonumber(args[2])
    if not scale then
        print("Usage: display scale <number>")
        return
    end
    local mon = nyxdisplay.findMonitor()
    if not mon then
        print("No screen connected.")
        return
    end
    local cfg = nyxdisplay.loadConfig()
    cfg.scale = scale
    nyxdisplay.saveConfig(cfg)
    mon.setTextScale(scale)
    print("Text scale set to " .. scale .. ".")
    return
end

local cfg = nyxdisplay.loadConfig()
if cfg.side then
    print("Active screen    : " .. cfg.side)
    print("Type             : " .. (cfg.advanced and "Advanced Monitor (colour)" or "Standard Monitor"))
    print("Text scale       : " .. tostring(cfg.scale))
else
    print("No screen configured. Use 'display scan' to detect one.")
end
