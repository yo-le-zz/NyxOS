-- /lib/specs.lua : machine specifications (shown by `specs` and by the
-- desktop's Task Manager).
--
-- specs.collect() -> ordered list of { label, value } rows, built only from
-- APIs that exist on every CC: Tweaked version (anything missing is simply
-- skipped or shown as "?").

local specs = {}

local function safe(fn, default)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return default
end

local function fmtBytes(n)
    if type(n) ~= "number" then return "?" end
    if n >= 1048576 then return string.format("%.2f MB", n / 1048576) end
    if n >= 1024 then return string.format("%.1f KB", n / 1024) end
    return n .. " B"
end

local function fmtDuration(sec)
    sec = math.floor(sec)
    local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
    local out = {}
    if d > 0 then out[#out + 1] = d .. "d" end
    if d > 0 or h > 0 then out[#out + 1] = h .. "h" end
    out[#out + 1] = m .. "m"
    out[#out + 1] = (sec % 60) .. "s"
    return table.concat(out, " ")
end

specs.formatBytes = fmtBytes
specs.formatDuration = fmtDuration

function specs.collect()
    local rows = {}
    local function add(label, value) rows[#rows + 1] = { label, tostring(value) } end

    add("Computer", "#" .. safe(os.getComputerID, "?") .. (safe(os.getComputerLabel) and (" \"" .. os.getComputerLabel() .. "\"") or ""))
    add("Type", safe(function()
        if turtle then return "Turtle" end
        if pocket then return "Pocket computer" end
        return term.isColor() and "Advanced computer" or "Computer"
    end, "Computer"))
    add("Host", safe(function() return _HOST end, "ComputerCraft"))
    add("CraftOS", safe(os.version, "?"))
    add("Lua", safe(function() return _VERSION end, "?"))

    local w, h = safe(function() return term.getSize() end, 0), 0
    local okSize, tw, th = pcall(term.getSize)
    if okSize then w, h = tw, th end
    add("Screen", w .. "x" .. h .. (safe(term.isColor, false) and " (colour)" or " (monochrome)"))

    -- Storage
    local cap = safe(function() return fs.getCapacity("/") end)
    local free = safe(function() return fs.getFreeSpace("/") end)
    if cap and free then
        add("Storage", fmtBytes(cap - free) .. " used / " .. fmtBytes(cap))
        add("Free", fmtBytes(free))
    elseif free then
        add("Free", fmtBytes(free))
    end

    -- Adaptive limits (see /lib/resources.lua)
    local b = safe(function() return dofile("/lib/resources.lua").budget() end)
    if b then add("Resources", b.tier .. " tier, " .. b.pressure .. " space") end

    -- Memory (the Lua heap is the only RAM a program can see)
    if collectgarbage then
        local okGc, kb = pcall(collectgarbage, "count")
        if okGc and type(kb) == "number" then add("Lua heap", string.format("%.0f KB", kb)) end
    end

    -- Network
    add("HTTP", http and "enabled" or "disabled")
    local modems = {}
    local screens, other = 0, {}
    for _, name in ipairs(safe(peripheral.getNames, {})) do
        local t = safe(function() return peripheral.getType(name) end, "?")
        if t == "modem" then
            local wireless = safe(function() return peripheral.call(name, "isWireless") end, false)
            modems[#modems + 1] = name .. (wireless and " (wireless)" or " (wired)")
        elseif t == "monitor" then
            screens = screens + 1
        else
            other[#other + 1] = t .. ":" .. name
        end
    end
    add("Modems", #modems > 0 and table.concat(modems, ", ") or "none")
    add("Monitors", screens)
    add("Peripherals", #other > 0 and table.concat(other, ", ") or "none")
    local accel = safe(function() return peripheral.find("cryptographic_accelerator") end)
    add("Crypto accel.", accel and "yes" or "no")

    -- Time
    add("Uptime (CC)", fmtDuration(safe(os.clock, 0)))
    add("Time", safe(function() return os.date("%d/%m/%Y %H:%M:%S") end, "?"))

    -- NyxOS
    local release = safe(function()
        local f = fs.open("/etc/nyx-release", "r")
        local line = f.readLine()
        f.close()
        return line
    end, "NyxOS")
    add("System", release)
    local services = safe(function() return dofile("/lib/services.lua") end)
    if services then
        local n = #safe(function() return services.processes() end, {})
        add("Processes", n)
    end
    return rows
end

return specs
