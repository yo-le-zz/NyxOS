-- /lib/display.lua
-- Manages display output on an external screen (monitor).
--
-- Automatically detects a connected monitor (regardless of which side or
-- network name it's on: "top", "left", "monitor_0", ...), determines
-- whether it's an Advanced Monitor (colour) or a standard Monitor, then
-- redirects the terminal to it. If no monitor is found, NyxOS keeps using
-- the computer's native screen as normal.

local nyxdisplay = {}

local CONFIG_PATH = "/etc/nyx-display.lua"

local function loadConfig()
    if not fs.exists(CONFIG_PATH) then
        return {}
    end
    local f = fs.open(CONFIG_PATH, "r")
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialize, content)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end

local function saveConfig(cfg)
    local f = fs.open(CONFIG_PATH, "w")
    f.write(textutils.serialize(cfg))
    f.close()
end

nyxdisplay.loadConfig = loadConfig
nyxdisplay.saveConfig = saveConfig

-- Looks for a "monitor"-type peripheral, regardless of which side or
-- network name it's connected on (automatic position detection).
-- Returns the monitor object and its name/side.
function nyxdisplay.findMonitor()
    if not peripheral then
        return nil
    end
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "monitor" then
            local mon = peripheral.wrap(name)
            if mon then
                return mon, name
            end
        end
    end
    return nil
end

-- Detects the monitor, initialises it (text scale, colours) and
-- redirects the current terminal to it. quiet=true suppresses log
-- messages. Returns ok, side, isAdvanced
function nyxdisplay.setup(quiet)
    local mon, name = nyxdisplay.findMonitor()
    if not mon then
        return false
    end

    local isAdvanced = false
    local ok = pcall(function()
        isAdvanced = mon.isColour()
    end)
    if not ok then
        isAdvanced = false
    end

    local cfg = loadConfig()
    cfg.side = name
    cfg.advanced = isAdvanced
    cfg.scale = cfg.scale or (isAdvanced and 0.5 or 1)
    saveConfig(cfg)

    pcall(mon.setTextScale, cfg.scale)
    term.redirect(mon)

    local palette = colors or colours
    if palette then
        pcall(term.setBackgroundColor, palette.black)
        pcall(term.setTextColor, palette.white)
    end
    term.clear()
    term.setCursorPos(1, 1)

    if not quiet then
        print("Screen detected: " .. name ..
            (isAdvanced and " (Advanced Monitor)" or " (standard Monitor)"))
    end

    return true, name, isAdvanced
end

return nyxdisplay
