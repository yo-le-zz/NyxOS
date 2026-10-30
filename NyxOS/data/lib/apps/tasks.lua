-- Task Manager: processes and services, machine specs, power.
local icon = dofile("/lib/icon.lua")
return {
    id = "tasks",
    name = "Tasks",
    system = true,
    color = "orange",
    icon = icon.builtin.tasks,
    build = function(area, ctx)
        local t, palette, accent = ctx.t, ctx.palette, ctx.accent
        local servicesOk, services = pcall(dofile, "/lib/services.lua")
        local procui = dofile("/lib/procui.lua")
        local aw, ah = area:getWidth(), area:getHeight()
        local ph = ah - 2

        local pgs, tabButtons = {}, {}
        local function newPage()
            local f = area:addFrame():setPosition(1, 3):setSize(aw, ph):setBackground(ctx.bg)
            f:setVisible(false)
            table.insert(pgs, f)
            return f
        end
        local function showPage(i)
            for j, f in ipairs(pgs) do f:setVisible(j == i) end
            for j, b in ipairs(tabButtons) do
                b:setBackground(j == i and accent or palette.gray)
                b:setForeground(j == i and palette.black or palette.white)
            end
        end
        local tx = 2
        for i, name in ipairs({ "Processes", "Specs", "Network", "Power" }) do
            local label = " " .. t(name) .. " "
            local b = area:addButton():setText(label):setPosition(tx, 1):setSize(#label, 1)
            b:onClick(function() showPage(i) end)
            tabButtons[i] = b
            tx = tx + #label + 1
        end

        ---------------- Processes ----------------
        local pp = newPage()
        local list = pp:addList():setPosition(2, 1):setSize(aw - 2, ph - 4)
            :setBackground(palette.gray):setForeground(palette.white)
            :setSelectedBackground(accent):setSelectedForeground(palette.black)
        local info = pp:addLabel():setText(""):setForeground(palette.lightGray):setPosition(2, ph - 2):setSize(aw - 2, 1)

        local rows, selected = {}, nil
        local kindColor = { shell = palette.cyan, service = palette.lime, job = palette.yellow,
            system = palette.lightGray, ui = palette.pink, app = palette.orange }
        local function refresh()
            list:clear()
            rows = {}
            local running = {}
            for _, p in ipairs((servicesOk and services) and services.processes() or {}) do
                table.insert(rows, p)
                if p.kind == "service" then running[p.name] = true end
            end
            -- desktop windows (apps)
            if ctx.windows then
                for _, w in ipairs(ctx.windows()) do
                    table.insert(rows, { pid = 0, name = w.title, kind = "app", state = w.minimized and "hidden" or "open",
                        user = ctx.username or "-", killable = true, win = w, description = t("Window: %s", w.app.name) })
                end
            end
            for _, def in ipairs((servicesOk and services) and services.list() or {}) do
                if not running[def.name] then
                    table.insert(rows, { pid = 0, name = def.name, kind = "service", state = "stopped",
                        user = "root", killable = false, description = def.description })
                end
            end
            for _, p in ipairs(rows) do
                list:addItem({
                    text = string.format("%-4s %-13s %-8s %s",
                        p.pid > 0 and p.pid or "-", tostring(p.name):sub(1, 13), p.kind, p.state),
                    fg = p.state == "stopped" and palette.lightGray or (kindColor[p.kind] or palette.white),
                })
            end
        end
        refresh()

        list:onSelect(function(self, index)
            selected = rows[index]
            if selected then
                info:setText(((selected.description or selected.cmd or "")):sub(1, aw - 4))
            end
        end)

        local function act(fn)
            if not selected then info:setText(t("Select a row first.")); return end
            local okAct, msg = pcall(fn, selected)
            info:setText(tostring(okAct and msg or (t("Error") .. ": " .. tostring(msg))):sub(1, aw - 4))
            refresh()
        end
        local x = 2
        local function button(label, bg, fg, row, fn)
            label = " " .. t(label) .. " "
            pp:addButton():setText(label):setPosition(x, row):setSize(#label, 1)
                :setBackground(bg):setForeground(fg):onClick(fn)
            x = x + #label + 1
        end
        local by = ph - 1
        button("Kill", palette.red, palette.white, by, function()
            act(function(p)
                if p.win then ctx.closeWin(p.win) return t("Closed.") end
                if not p.killable then return t("%s cannot be killed here.", p.name) end
                local _, msg = procui.killPid(p.pid)
                return msg
            end)
        end)
        button("Start", palette.green, palette.black, by, function()
            act(function(p)
                if p.kind ~= "service" then return t("Only services can be started.") end
                local pid, err = services.start(p.name)
                return pid and t("started %s (pid %d)", p.name, pid) or tostring(err)
            end)
        end)
        button("Stop", palette.orange, palette.black, by, function()
            act(function(p)
                if p.kind ~= "service" or p.pid == 0 then return t("Not a running service.") end
                local _, msg = procui.killPid(p.pid)
                return msg
            end)
        end)
        button("Enable", accent, palette.black, by, function()
            act(function(p)
                if p.kind ~= "service" then return t("Only services have autostart.") end
                services.setAutostart(p.name, true)
                return p.name .. ": autostart on"
            end)
        end)
        button("Disable", palette.gray, palette.white, by, function()
            act(function(p)
                if p.kind ~= "service" then return t("Only services have autostart.") end
                services.setAutostart(p.name, false)
                return p.name .. ": autostart off"
            end)
        end)
        x = 2
        button("Refresh", palette.lightBlue, palette.black, by + 1, function()
            refresh(); info:setText(t("Refreshed."))
        end)

        ---------------- Specs ----------------
        local sp = newPage()
        local specBox = sp:addTextBox():setPosition(2, 1):setSize(aw - 2, ph - 3)
            :setEditable(false):setBackground(palette.black):setForeground(palette.white)
        local function loadSpecs()
            local okSpecs, rowsOrErr = ctx.try("specs", function() return dofile("/lib/specs.lua").collect() end)
            local lines = {}
            if okSpecs and type(rowsOrErr) == "table" then
                for _, row in ipairs(rowsOrErr) do
                    lines[#lines + 1] = string.format("%-14s %s", row[1], row[2])
                end
            else
                lines[1] = t("Error") .. ": " .. tostring(rowsOrErr)
            end
            specBox:setText(table.concat(lines, "\n"))
        end
        loadSpecs()
        local rl = " " .. t("Refresh") .. " "
        sp:addButton():setText(rl):setPosition(2, ph - 1):setSize(#rl, 1)
            :setBackground(palette.lightBlue):setForeground(palette.black)
            :onClick(loadSpecs)

        ---------------- Network ----------------
        local np = newPage()
        local netBox = np:addTextBox():setPosition(2, 1):setSize(aw - 2, ph - 3)
            :setEditable(false):setBackground(palette.black):setForeground(palette.white)
        local function loadNet()
            local okN, lines = ctx.try("network", function()
                local net = dofile("/lib/netstack.lua")
                local cfg, out = net.config(), {}
                out[#out + 1] = string.format("%s  mask %s  (%s%s)", cfg.ip, cfg.mask, cfg.mode, cfg.leased and ", leased" or "")
                out[#out + 1] = "gateway " .. tostring(cfg.gateway or "-") .. "   dns " .. tostring(cfg.dns or "-")
                out[#out + 1] = (cfg.up and "up" or "DOWN") .. (cfg.forward and ", forwarding" or "")
                local ifs = net.interfaces()
                if #ifs == 0 then out[#out + 1] = "no modem" end
                for _, i in ipairs(ifs) do out[#out + 1] = i.name .. " " .. (i.wireless and "wireless" or "wired") .. " " .. (i.open and "open" or "closed") end
                local st = net.stats()
                out[#out + 1] = "packets rx " .. st.rx .. "  tx " .. st.tx
                out[#out + 1] = "-- listening"
                for _, l in ipairs(net.listeners()) do out[#out + 1] = tostring(l.port) .. "  " .. l.name end
                out[#out + 1] = "-- connections"
                for _, c in ipairs(net.connections()) do out[#out + 1] = c.peer .. ":" .. tostring(c.peerPort) .. " " .. c.role end
                return out
            end)
            netBox:setText(okN and table.concat(lines, "\n") or tostring(lines))
        end
        loadNet()
        local nl = " " .. t("Refresh") .. " "
        np:addButton():setText(nl):setPosition(2, ph - 1):setSize(#nl, 1)
            :setBackground(palette.lightBlue):setForeground(palette.black):onClick(loadNet)

        ---------------- Power ----------------
        local pw = newPage()
        pw:addLabel():setText(t("Power")):setForeground(accent):setPosition(2, 2)
        pw:addButton():setText(" " .. t("Reboot") .. " "):setPosition(2, 4):setSize(12, 3)
            :setBackground(palette.orange):setForeground(palette.black)
            :onClick(function() ctx.runOnTerminal("reboot") end)
        pw:addButton():setText(" " .. t("Shutdown") .. " "):setPosition(16, 4):setSize(14, 3)
            :setBackground(palette.red):setForeground(palette.white)
            :onClick(function() ctx.runOnTerminal("shutdown") end)

        showPage(1)
    end,
}
