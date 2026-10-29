-- Settings: general, language, account (password), look, default apps, system.
local icon = dofile("/lib/icon.lua")
return {
    id = "settings",
    name = "Settings",
    system = true,
    color = "purple",
    icon = icon.builtin.settings,
    build = function(area, ctx)
        local t, palette, accent = ctx.t, ctx.palette, ctx.accent
        local nyxlib = dofile("/lib/nyxlib.lua")
        local theme = dofile("/lib/theme.lua")
        local i18n = dofile("/lib/i18n.lua")
        local config = ctx.config
        local aw, ah = area:getWidth(), area:getHeight()
        local cw = math.min(aw - 2, 46)
        local cx = math.floor((aw - cw) / 2) + 1
        local ph = ah - 2
        local center = ctx.center

        local pgs, tabButtons = {}, {}
        local function newPage()
            local f = area:addFrame():setPosition(cx, 3):setSize(cw, ph):setBackground(ctx.bg)
            f:setVisible(false)
            table.insert(pgs, f)
            return f
        end
        local function showPage(i)
            for j, f in ipairs(pgs) do f:setVisible(j == i) end
            for j, b in ipairs(tabButtons) do
                b:setBackground(j == i and accent or (j % 2 == 0 and palette.gray or palette.lightGray))
                b:setForeground(j == i and palette.black or (j % 2 == 0 and palette.white or palette.black))
            end
        end
        local tabNames = { "General", "Language", "Account", "Look", "Apps", "Update", "System" }
        local tabX = cx
        local tabTotal = 0
        for _, name in ipairs(tabNames) do tabTotal = tabTotal + #t(name) end
        local roomy = (tabTotal + 2 * #tabNames <= aw - cx + 1)
        if not roomy then tabX = 1 end
        for i, name in ipairs(tabNames) do
            local label = roomy and (" " .. t(name) .. " ") or t(name)
            local b = area:addButton():setText(label):setPosition(tabX, 1):setSize(#label, 1)
            b:onClick(function() showPage(i) end)
            tabButtons[i] = b
            tabX = tabX + #label
        end

        local function section(parent, y, text, color)
            parent:addLabel():setText(center(text, cw)):setPosition(1, y):setSize(cw, 1)
                :setBackground(color or palette.gray):setForeground(palette.black)
        end
        local function field(parent, y, label, text, masked)
            parent:addLabel():setText(label):setForeground(palette.white):setPosition(1, y)
            local input = parent:addInput():setPosition(1, y + 1):setSize(cw, 1)
                :setBackground(palette.gray):setForeground(palette.white):setText(text or "")
            if masked then pcall(function() input:setReplaceChar("*") end) end
            return input
        end
        local function trimmed(v) return ctx.trim(v or "") end
        local function saveConfig(mutate)
            local cfg = nyxlib.loadTable("/etc/nyx-config.lua")
            mutate(cfg)
            nyxlib.saveTable("/etc/nyx-config.lua", cfg)
        end

        ---------------- General ----------------
        local gp = newPage()
        section(gp, 1, t("Computer"), palette.cyan)
        local hostInput = field(gp, 2, t("Hostname"), nyxlib.getHostname())
        section(gp, 5, t("Interface at boot"), palette.lime)
        local mode = config.uiMode or "shell"
        local modeLabel = gp:addLabel():setText(""):setForeground(palette.white):setPosition(1, 6):setSize(cw, 1)
        local function setModeLabel() modeLabel:setText((t("Current: %s", mode)):sub(1, cw)) end
        setModeLabel()
        gp:addLabel():setText(t("shell: graphical shell"):sub(1, cw)):setForeground(palette.lightGray):setPosition(1, 7)
        gp:addLabel():setText(t("desktop: this desktop"):sub(1, cw)):setForeground(palette.lightGray):setPosition(1, 8)
        gp:addLabel():setText(t("server: text shell + services"):sub(1, cw)):setForeground(palette.lightGray):setPosition(1, 9)
        local mx = 1
        for _, m in ipairs({ "shell", "desktop", "server" }) do
            gp:addButton():setText(" " .. m .. " "):setPosition(mx, 10):setSize(#m + 2, 1)
                :setBackground(palette.lightGray):setForeground(palette.black)
                :onClick(function() mode = m; setModeLabel() end)
            mx = mx + #m + 3
        end
        local gstatus = gp:addLabel():setText(""):setForeground(palette.lightGray):setPosition(1, 13):setSize(cw, 1)
        gp:addButton():setText(center(t("Save"), 12)):setPosition(1, 12):setSize(12, 1)
            :setBackground(accent):setForeground(palette.black)
            :onClick(function()
                local okHost = pcall(nyxlib.setHostname, hostInput:getText())
                saveConfig(function(cfg) cfg.uiMode = mode end)
                gstatus:setText((okHost and t("Saved. Boot mode applies at next reboot.") or t("Could not save the hostname.")):sub(1, cw))
            end)

        ---------------- Language ----------------
        local lp = newPage()
        section(lp, 1, t("Language pack"), palette.magenta)
        local packs = i18n.list()
        local langList = lp:addList():setPosition(1, 2):setSize(cw, math.max(3, math.min(#packs, 7)))
            :setBackground(palette.gray):setForeground(palette.white)
            :setSelectedBackground(accent):setSelectedForeground(palette.black)
        local langChoice = i18n.current()
        for i, p in ipairs(packs) do
            langList:addItem({ text = string.format(" %-6s %s", p.code, p.name),
                fg = palette.white, selectedFg = palette.black })
            if p.code == langChoice then pcall(function() langList:selectItem(i) end) end
        end
        langList:onSelect(function(self, index)
            if packs[index] then langChoice = packs[index].code end
        end)
        lp:addLabel():setText(t("Packs live in /etc/lang"):sub(1, cw)):setForeground(palette.lightGray):setPosition(1, 10)
        lp:addButton():setText(center(t("Apply"), 12)):setPosition(1, 11):setSize(12, 1)
            :setBackground(accent):setForeground(palette.black)
            :onClick(function()
                saveConfig(function(cfg) cfg.lang = langChoice end)
                ctx.restart()
            end)

        ---------------- Account ----------------
        local ap = newPage()
        local username = ctx.username
        section(ap, 1, t("Change password") .. (username and (" - " .. username) or ""), palette.orange)
        local oldInput = field(ap, 2, t("Current password"), "", true)
        local newInput = field(ap, 4, t("New password (empty = none)"), "", true)
        local confInput = field(ap, 6, t("Confirm new password"), "", true)
        local astatus = ap:addLabel():setText(""):setForeground(palette.lightGray):setPosition(1, 10):setSize(cw, 1)
        ap:addButton():setText(center(t("Change password"), 20)):setPosition(1, 9):setSize(20, 1)
            :setBackground(accent):setForeground(palette.black)
            :onClick(function()
                if not username then astatus:setText(t("No active session.")); return end
                local users = dofile("/lib/users.lua")
                if not users.checkPassword(username, oldInput:getText()) then
                    astatus:setForeground(palette.red); astatus:setText(t("Current password is wrong.")); return
                end
                local newPass = newInput:getText()
                if newPass ~= confInput:getText() then
                    astatus:setForeground(palette.red); astatus:setText(t("The two passwords differ.")); return
                end
                users.setPassword(username, newPass)
                oldInput:setText(""); newInput:setText(""); confInput:setText("")
                astatus:setForeground(palette.lime)
                astatus:setText(newPass == "" and t("Password removed.") or t("Password changed."))
            end)

        ---------------- Look ----------------
        local lkp = newPage()
        section(lkp, 1, t("Accent colour"), palette.magenta)
        local shown = math.min(#theme.presets, 5)
        local themeList = lkp:addList():setPosition(1, 2):setSize(cw, shown)
            :setBackground(palette.gray):setForeground(palette.black)
            :setSelectedBackground(palette.white):setSelectedForeground(palette.black)
        for _, p in ipairs(theme.presets) do
            themeList:addItem({ text = "  " .. p.name, bg = p.accent, fg = palette.black,
                selectedBg = p.accent, selectedFg = palette.white })
        end
        local chosen
        themeList:onSelect(function(self, index) chosen = theme.presets[index] end)

        local bgOptions = {
            { "Black", "black" }, { "Gray", "gray" }, { "Blue", "blue" }, { "Green", "green" },
            { "Purple", "purple" }, { "Brown", "brown" },
        }
        local lrow = 2 + shown
        section(lkp, lrow, t("Desktop background"), palette.lightBlue)
        local bgChoice = config.desktopBg or "black"
        local bgLabel = lkp:addLabel():setText(t("Current: %s", bgChoice)):setForeground(palette.white):setPosition(1, lrow + 1):setSize(cw, 1)
        local bx, by2 = 1, lrow + 2
        for _, opt in ipairs(bgOptions) do
            local label = " " .. t(opt[1]) .. " "
            if bx + #label > cw then bx = 1; by2 = by2 + 1 end
            lkp:addButton():setText(label):setPosition(bx, by2):setSize(#label, 1)
                :setBackground(palette[opt[2]] or palette.gray)
                :setForeground(opt[2] == "black" and palette.white or palette.black)
                :onClick(function() bgChoice = opt[2]; bgLabel:setText(t("Current: %s", bgChoice)) end)
            bx = bx + #label + 1
        end
        lkp:addButton():setText(center(t("Apply"), 10)):setPosition(1, math.min(by2 + 2, ph)):setSize(10, 1)
            :setBackground(accent):setForeground(palette.black)
            :onClick(function()
                if chosen then theme.save({ name = chosen.name, accent = chosen.accent }) end
                saveConfig(function(cfg) cfg.desktopBg = bgChoice end)
                ctx.restart()
            end)

        ---------------- Apps ----------------
        local appsPage = newPage()
        section(appsPage, 1, t("Default apps"), palette.green)
        local enabled = {}
        local optional = {}
        for _, mod in ipairs(ctx.appModules) do
            if not mod.system then optional[#optional + 1] = mod end
        end
        for _, mod in ipairs(optional) do
            enabled[mod.id] = (type(config.apps) ~= "table") or config.apps[mod.id] ~= false
        end
        local rowY = 2
        for _, mod in ipairs(optional) do
            local box
            local function label() return (enabled[mod.id] and "[x] " or "[ ] ") .. t(mod.name) end
            box = appsPage:addButton():setText(label()):setPosition(1, rowY):setSize(cw, 1)
                :setBackground(palette.gray):setForeground(palette.white)
                :onClick(function()
                    enabled[mod.id] = not enabled[mod.id]
                    box:setText(label())
                end)
            rowY = rowY + 1
        end
        appsPage:addButton():setText(center(t("Apply"), 12)):setPosition(1, math.min(rowY + 1, ph)):setSize(12, 1)
            :setBackground(accent):setForeground(palette.black)
            :onClick(function()
                saveConfig(function(cfg)
                    cfg.apps = type(cfg.apps) == "table" and cfg.apps or {}
                    for id, on in pairs(enabled) do cfg.apps[id] = on end
                end)
                ctx.restart()
            end)

        ---------------- System ----------------
        ---------------- Update ----------------
        local up = newPage()
        local updater = dofile("/lib/updater.lua")
        local ucfg = updater.config()
        section(up, 1, t("Updates"), palette.cyan)
        up:addLabel():setText(t("Repository (owner/name)")):setForeground(palette.white):setPosition(1, 2)
        local repoInput = up:addInput():setPosition(1, 3):setSize(cw, 1)
            :setBackground(palette.gray):setForeground(palette.white):setText(ucfg.repo)
        local autoOn = ucfg.auto
        local autoButton = up:addButton():setPosition(1, 5):setSize(cw, 1):setForeground(palette.black)
        local function paintAuto()
            autoButton:setText(center(t("Automatic check") .. ": " .. (autoOn and t("enabled") or t("disabled")), cw))
            autoButton:setBackground(autoOn and palette.lime or palette.lightGray)
        end
        paintAuto()
        autoButton:onClick(function() autoOn = not autoOn paintAuto() end)
        up:addLabel():setText(t("Hours between checks")):setForeground(palette.white):setPosition(1, 6)
        local hoursInput = up:addInput():setPosition(1, 7):setSize(8, 1)
            :setBackground(palette.gray):setForeground(palette.white):setText(tostring(ucfg.interval))
        local upStatus = up:addLabel():setText(""):setForeground(palette.lightGray):setPosition(1, 11):setSize(cw, 2)
        local function say(text, colour)
            upStatus:setText(tostring(text):sub(1, cw)):setForeground(colour or palette.lightGray)
        end
        local lastInfo = nil
        local function saveUpdate()
            local repo = trimmed(repoInput:getText())
            if not repo:match("^[%w%-%._]+/[%w%-%._]+$") then say(t("Invalid name."), palette.red) return false end
            local hours = tonumber(hoursInput:getText())
            if not hours or hours < 1 or hours > 720 then say(t("Hours between checks") .. " 1-720", palette.red) return false end
            local okSave = updater.setConfig("updateRepo", repo)
                and updater.setConfig("autoUpdate", autoOn)
                and updater.setConfig("updateInterval", math.floor(hours))
            say(okSave and t("Saved.") or t("Error"), okSave and palette.lime or palette.red)
            return okSave
        end
        up:addButton():setText(center(t("Apply"), 10)):setPosition(1, 9):setSize(10, 1)
            :setBackground(accent):setForeground(palette.black):onClick(saveUpdate)
        up:addButton():setText(center(t("Check now"), 14)):setPosition(12, 9):setSize(14, 1)
            :setBackground(palette.cyan):setForeground(palette.black):onClick(function()
                if not saveUpdate() then return end
                say(t("Checking..."))
                ctx.basalt.schedule(function()
                    local okC, info, err = ctx.try("updater", function() return updater.check(true) end)
                    if not okC or not info then say(t("Cannot check: %s", tostring(err or info)), palette.red) return end
                    lastInfo = info
                    if info.available then
                        say(t("NyxOS %s is available (you have %s).", info.latest, info.current), palette.yellow)
                    else
                        say(t("You are up to date (%s).", info.current), palette.lime)
                    end
                end)
            end)
        up:addButton():setText(center(t("Install"), 10)):setPosition(27, 9):setSize(10, 1)
            :setBackground(palette.orange):setForeground(palette.black):onClick(function()
                if not lastInfo or not lastInfo.available then say(t("Check now"), palette.red) return end
                ctx.confirm("Update", t("NyxOS %s is available (you have %s). Install now?", lastInfo.latest, lastInfo.current),
                    function() ctx.runOnTerminal("nyxupdate install") end)
            end)

        local syp = newPage()
        section(syp, 1, t("About"), palette.yellow)
        local release = "NyxOS"
        if fs.exists("/etc/nyx-release") then
            local f = fs.open("/etc/nyx-release", "r")
            release = f.readLine() or release
            f.close()
        end
        local lines = {
            release,
            t("Hostname") .. " : " .. nyxlib.getHostname(),
            t("User") .. " : " .. tostring(username or "-"),
            t("Home") .. " : " .. ctx.home,
            "HTTP : " .. (http and t("enabled") or t("disabled")),
            t("Boot interface") .. " : " .. (config.uiMode or "shell"),
        }
        for i, line in ipairs(lines) do
            syp:addLabel():setText(line:sub(1, cw)):setForeground(palette.white):setPosition(1, 1 + i)
        end
        local tl = center(t("Task Manager"), 16)
        syp:addButton():setText(tl):setPosition(1, 9):setSize(16, 1)
            :setBackground(palette.orange):setForeground(palette.black)
            :onClick(function() ctx.launch("Tasks") end)
        syp:addButton():setText(center(t("Packages"), 12)):setPosition(19, 9):setSize(12, 1)
            :setBackground(palette.green):setForeground(palette.black)
            :onClick(function() ctx.launch("Packages") end)
        syp:addButton():setText(center(t("Logs"), 10)):setPosition(1, 11):setSize(10, 1)
            :setBackground(palette.red):setForeground(palette.white)
            :onClick(function() ctx.launch("Logs") end)

        showPage(1)
    end,
}
