-- /lib/serverui.lua : text dashboard of the Server profile (no Basalt needed)
--
--   Up/Down choose a service   S start   X stop   E enable/disable autostart
--   L logs   N network   T shell   R reboot   Q shutdown
local serverui = {}

local palette = colors or colours

local function safe(fn, default)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return default
end

local function put(x, y, text, fg, bg)
    term.setCursorPos(x, y)
    if bg then term.setBackgroundColor(bg) end
    if fg then term.setTextColor(fg) end
    term.write(text)
end

local function fmtUp(sec)
    sec = math.floor(sec)
    return string.format("%dh %02dm %02ds", math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
end

function serverui.run()
    local services = safe(function() return dofile("/lib/services.lua") end)
    local nyxlib = dofile("/lib/nyxlib.lua")
    local view, sel, message = "services", 1, ""
    local list = {}

    local function reload()
        list = services and safe(function() return services.list() end, {}) or {}
        if sel > #list then sel = math.max(1, #list) end
    end

    local function draw()
        local w, h = term.getSize()
        term.setBackgroundColor(palette.black)
        term.clear()
        put(1, 1, string.rep(" ", w), palette.black, palette.cyan)
        put(2, 1, "NyxOS Server - " .. tostring(safe(nyxlib.getHostname, "nyxos")), palette.black, palette.cyan)
        local ip = safe(function() return dofile("/lib/netstack.lua").myIp() end, nil)
        local up = fmtUp(os.clock())
        local right = (ip and ("IP " .. ip .. "  ") or "") .. "up " .. up
        put(math.max(20, w - #right), 1, right, palette.black, palette.cyan)
        term.setBackgroundColor(palette.black)

        if view == "services" then
            put(1, 3, "Services", palette.yellow)
            put(1, 4, string.format("%-14s %-9s %-6s %s", "NAME", "STATE", "BOOT", "DESCRIPTION"), palette.gray)
            local top = 5
            local rows = h - 7
            local first = math.max(1, math.min(sel - rows + 1, #list - rows + 1))
            if #list == 0 then put(2, top, "No service registered (apt install a server package).", palette.lightGray) end
            for i = first, math.min(#list, first + rows - 1) do
                local def = list[i]
                local st = safe(function() return services.status(def.name).state end, "stopped")
                local line = string.format("%-14s %-9s %-6s %s", def.name:sub(1, 14), tostring(st):sub(1, 9),
                    def.autostart and "auto" or "-", tostring(def.description or ""))
                local y = top + i - first
                if i == sel then put(1, y, (line .. string.rep(" ", w)):sub(1, w), palette.black, palette.lime)
                else put(1, y, line:sub(1, w), st == "running" and palette.lime or palette.white, palette.black) end
                term.setBackgroundColor(palette.black)
            end
        elseif view == "logs" then
            put(1, 3, "System log (last lines)", palette.yellow)
            local lines = safe(function() return dofile("/lib/logger.lua").tail(h - 6) end, {})
            for i, line in ipairs(lines) do put(1, 3 + i, tostring(line):sub(1, w), palette.lightGray, palette.black) end
        elseif view == "network" then
            put(1, 3, "Network", palette.yellow)
            local cfg = safe(function() return dofile("/lib/netstack.lua").config() end, {})
            local y = 4
            for _, key in ipairs({ "ip", "mask", "gateway", "dns", "mode" }) do
                if cfg[key] ~= nil then put(2, y, string.format("%-9s %s", key, tostring(cfg[key])), palette.white, palette.black) y = y + 1 end
            end
            local cap, free = safe(function() return fs.getCapacity("/") end, 0), safe(function() return fs.getFreeSpace("/") end, 0)
            put(2, y + 1, string.format("Storage   %d KB free of %d KB", math.floor(free / 1024), math.floor(cap / 1024)), palette.white)
        end
        put(1, h - 1, (" " .. message):sub(1, w), palette.orange, palette.black)
        put(1, h, string.rep(" ", w), palette.white, palette.gray)
        put(2, h, "S start  X stop  E boot  L logs  N net  V services  T shell  R reboot  Q off", palette.white, palette.gray)
    end

    reload()
    local timer = os.startTimer(2)
    draw()
    while true do
        local e, a = os.pullEvent()
        if e == "timer" and a == timer then
            reload() timer = os.startTimer(2) draw()
        elseif e == "key" then
            local def = list[sel]
            if a == keys.up then sel = math.max(1, sel - 1)
            elseif a == keys.down then sel = math.min(math.max(1, #list), sel + 1)
            elseif a == keys.s and def and services then
                local ok, err = services.start(def.name)
                message = ok and ("Started " .. def.name) or tostring(err)
            elseif a == keys.x and def and services then
                local pid
                for _, p in ipairs(safe(function() return services.processes() end, {})) do
                    if p.name == def.name and p.kind == "service" then pid = p.pid end
                end
                if pid then services.kill(pid) message = "Stopped " .. def.name
                else message = def.name .. " is not running" end
            elseif a == keys.e and def and services then
                services.setAutostart(def.name, not def.autostart)
                message = def.name .. ": boot start " .. (def.autostart and "disabled" or "enabled")
                reload()
            elseif a == keys.l then view = "logs"
            elseif a == keys.n then view = "network"
            elseif a == keys.v then view = "services"
            elseif a == keys.t then
                term.setBackgroundColor(palette.black) term.setTextColor(palette.white) term.clear() term.setCursorPos(1, 1)
                print("Type 'exit' to come back to the dashboard.")
                shell.run("shell")
            elseif a == keys.r then os.reboot()
            elseif a == keys.q then os.shutdown() end
            draw()
        end
    end
end

return serverui
