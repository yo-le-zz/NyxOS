-- Packages: the NyxOS store. Cards with an icon per package, a registry
-- browser (apt search) and the installed packages, with their actions.
local icon = dofile("/lib/icon.lua")
return {
    id = "packages",
    name = "Packages",
    system = true,
    color = "green",
    icon = icon.builtin.package,
    size = { 74, 24 },
    build = function(area, ctx)
        local t, palette, accent, basalt = ctx.t, ctx.palette, ctx.accent, ctx.basalt
        local nyxlib = dofile("/lib/nyxlib.lua")
        local aw, ah = area:getWidth(), area:getHeight()

        local CW, CH = 15, 6
        local DETAIL = 6                               -- height of the detail panel
        local gridTop, gridH = 3, ah - 2 - DETAIL
        local cols = math.max(1, math.floor(aw / CW))
        local rowsN = math.max(1, math.floor(gridH / CH))
        local perPage = cols * rowsN
        local offsetX = math.floor((aw - cols * CW) / 2)

        local view = "store"           -- "store" | "installed"
        local items, page, selected = {}, 1, nil
        local storeCache, query = nil, ""
        local loading = false
        local refreshView
        local function center(text, w)
            text = tostring(text):sub(1, w)
            local l = math.floor((w - #text) / 2)
            return string.rep(" ", l) .. text .. string.rep(" ", w - #text - l)
        end
        local function wipe(parent, list)
            for _, el in ipairs(list) do pcall(parent.removeChild, parent, el) end
            for i = #list, 1, -1 do list[i] = nil end
        end
        local gridEls, actionEls = {}, {}

        ---------------- header: tabs + search
        local tabButtons = {}
        local function paintTabs()
            for _, b in ipairs(tabButtons) do
                local on = b.view == view
                b.btn:setBackground(on and accent or palette.gray):setForeground(on and palette.black or palette.white)
            end
        end
        local tx = 1
        for _, def in ipairs({ { "Store", "store" }, { "Installed", "installed" } }) do
            local label = " " .. t(def[1]) .. " "
            local b = area:addButton():setText(label):setPosition(tx, 1):setSize(#label, 1)
            tabButtons[#tabButtons + 1] = { btn = b, view = def[2] }
            tx = tx + #label + 1
        end
        local search = area:addInput():setPosition(tx + 1, 1):setSize(math.max(8, aw - tx - 11), 1)
            :setBackground(palette.gray):setForeground(palette.white):setPlaceholder(t("Search..."))
        local goLabel = " " .. t("Search") .. " "
        local goBtn = area:addButton():setText(goLabel):setPosition(aw - #goLabel + 1, 1):setSize(#goLabel, 1)
            :setBackground(accent):setForeground(palette.black)

        local status = area:addLabel():setText(""):setPosition(1, 2):setSize(math.max(1, aw - 14), 1)
            :setForeground(palette.lightGray)
        local grid = area:addFrame():setPosition(1, gridTop):setSize(aw, gridH):setBackground(ctx.bg)
        local detail = area:addFrame():setPosition(1, ah - DETAIL + 1):setSize(aw, DETAIL):setBackground(palette.gray)
        local pager = area:addLabel():setText(""):setPosition(aw - 12, 2):setSize(13, 1)
            :setForeground(palette.white)

        local dIcon = detail:addImage():setPosition(2, 2):setSize(8, 3)
        local dTitle = detail:addLabel():setText(""):setPosition(12, 1):setSize(aw - 12, 1)
            :setBackground(palette.gray):setForeground(accent)
        local dText = detail:addTextBox():setPosition(12, 2):setSize(aw - 12, 3)
            :setEditable(false):setBackground(palette.gray):setForeground(palette.white)
        local actionBar = detail:addFrame():setPosition(1, DETAIL):setSize(aw, 1):setBackground(palette.gray)

        ---------------- data
        local function manifestItems()
            local out = {}
            local manifest = nyxlib.loadManifest()
            local names = {}
            for name in pairs(manifest) do names[#names + 1] = name end
            table.sort(names)
            for _, name in ipairs(names) do
                local e = manifest[name]
                out[#out + 1] = {
                    name = name, version = e.version, description = e.description, author = e.author,
                    installed = not e.removed, removed = e.removed, entry = e,
                    icon = (icon.isPixel(e.icon) and e.icon) or icon.load(name) or icon.generate(name),
                    launch = nyxlib.launcherFor(name, e), service = e.service,
                }
            end
            return out
        end

        local function storeItems()
            local installed = nyxlib.loadManifest()
            local out = {}
            for _, p in ipairs(storeCache or {}) do
                local e = installed[p.name]
                local q = query:lower()
                if q == "" or p.name:lower():find(q, 1, true) or tostring(p.description or ""):lower():find(q, 1, true) then
                    out[#out + 1] = {
                        name = p.name, version = p.version, description = p.description, author = p.author,
                        installed = e and not e.removed or false,
                        updatable = e and not e.removed and tostring(e.version) ~= tostring(p.version) or false,
                        icon = (icon.isPixel(p.icon) and p.icon) or icon.generate(p.name),
                        launch = p.launch, service = p.service, variant = p.variant,
                    }
                end
            end
            return out
        end

        local function loadStore(force)
            if loading then return end
            local path = "/var/apt/store-cache.lua"
            if not force and storeCache then return end
            if not force and fs.exists(path) then
                local f = fs.open(path, "r")
                local okC, data = pcall(textutils.unserialize, f.readAll())
                f.close()
                if okC and type(data) == "table" and data.list and os.epoch("utc") - (data.at or 0) < 3600000 then
                    storeCache = data.list
                    return
                end
            end
            loading = true
            status:setText(t("Searching the registry..."))
            basalt.schedule(function()
                local tmp = "/tmp/store-search.lua"
                if not fs.exists("/tmp") then pcall(fs.makeDir, "/tmp") end
                if fs.exists(tmp) then pcall(fs.delete, tmp) end
                local out, err = dofile("/lib/capture.lua").run("apt search --out " .. tmp .. " *")
                loading = false
                if fs.exists(tmp) then
                    local f = fs.open(tmp, "r")
                    local okL, list = pcall(textutils.unserialize, f.readAll())
                    f.close()
                    pcall(fs.delete, tmp)
                    if okL and type(list) == "table" then
                        storeCache = list
                        local okR, res = pcall(dofile, "/lib/resources.lua")
                        if not okR or res.budget().treeCache then
                            local cf = fs.open(path, "w")
                            if cf then cf.write(textutils.serialize({ at = os.epoch("utc"), list = list })) cf.close() end
                        end
                    end
                end
                if not storeCache then
                    status:setText(((err and tostring(err)) or (out and out ~= "" and out) or t("No result.")):sub(1, aw))
                    storeCache = {}
                end
                if ctx.alive() then refreshView() end
            end)
        end

        ---------------- selection / actions
        local function describe()
            local it = selected
            wipe(actionBar, actionEls)
            if not it then
                dIcon:setBimg({ icon.build(icon.generate("?"), "gray") })
                dTitle:setText(t("Select a package."))
                dText:setText(view == "store" and t("Click a card for its details, double-click to install or launch.") or "")
                return
            end
            dIcon:setBimg({ icon.build(it.icon, "gray") })
            dTitle:setText((it.name .. "  v" .. tostring(it.version or "?")
                .. (it.author and ("  - " .. it.author) or "")):sub(1, aw - 13))
            local flags = {}
            if it.installed then flags[#flags + 1] = t("installed") end
            if it.updatable then flags[#flags + 1] = t("update available") end
            if it.removed then flags[#flags + 1] = t("removed") end
            if it.launch then flags[#flags + 1] = "$ " .. it.launch end
            if it.service then flags[#flags + 1] = "service " .. it.service end
            dText:setText(tostring(it.description or "") .. "\n" .. table.concat(flags, "   "))
            local x = 2
            local function act(label, bg, fg, fn)
                label = " " .. t(label) .. " "
                local b = actionBar:addButton():setText(label):setPosition(x, 1):setSize(#label, 1)
                    :setBackground(bg):setForeground(fg):onClick(fn)
                actionEls[#actionEls + 1] = b
                x = x + #label + 1
            end
            if not it.installed then
                act("Install", palette.green, palette.black, function() ctx.openTerminal("apt install " .. it.name) end)
            else
                if it.launch then
                    act("Launch", palette.green, palette.black, function() ctx.runOnTerminal(it.launch) end)
                elseif it.service then
                    act("Start service", palette.green, palette.black, function() ctx.openTerminal("service start " .. it.service) end)
                end
                act("Update", accent, palette.black, function() ctx.openTerminal("apt update " .. it.name) end)
                act("Remove", palette.orange, palette.black, function()
                    ctx.confirm("Remove", t("Remove %s ?", it.name), function() ctx.openTerminal("apt remove " .. it.name) end)
                end)
                act("Purge", palette.red, palette.white, function()
                    ctx.confirm("Purge", t("Delete %s and its config?", it.name), function() ctx.openTerminal("apt purge " .. it.name) end)
                end)
            end
            act("Refresh", palette.lightBlue, palette.black, function() refreshView(true) end)
        end

        local lastClick = { name = nil, at = 0 }
        local function defaultAction(it)
            if not it.installed then ctx.openTerminal("apt install " .. it.name)
            elseif it.launch then ctx.runOnTerminal(it.launch)
            elseif it.service then ctx.openTerminal("service start " .. it.service)
            else status:setText(t("%s has no launcher (it is a library).", it.name)) end
        end

        local cards = {}
        local function paintCards()
            for _, c in ipairs(cards) do
                local sel = selected and selected.name == c.item.name
                c.frame:setBackground(sel and accent or palette.gray)
                c.name:setBackground(sel and accent or palette.gray):setForeground(sel and palette.black or palette.white)
                c.sub:setBackground(sel and accent or palette.gray):setForeground(sel and palette.black or palette.lightGray)
            end
        end

        local function drawGrid()
            wipe(grid, gridEls)
            cards = {}
            local pages = math.max(1, math.ceil(#items / perPage))
            if page > pages then page = pages end
            pager:setText(string.format("< %d/%d >", page, pages))
            local first = (page - 1) * perPage
            for i = 1, perPage do
                local it = items[first + i]
                if not it then break end
                local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
                local f = grid:addFrame():setPosition(offsetX + col * CW + 1, row * CH + 1):setSize(CW - 1, CH - 1)
                    :setBackground(palette.gray)
                gridEls[#gridEls + 1] = f
                f:addImage():setPosition(4, 1):setSize(8, 3):setBimg({ icon.build(it.icon, "gray") })
                local nm = f:addLabel():setText(center(it.name, CW - 1)):setPosition(1, 4):setSize(CW - 1, 1)
                local sub = (it.updatable and t("update")) or (it.installed and (it.removed and t("removed") or t("installed"))) or ("v" .. tostring(it.version or "?"))
                local sb = f:addLabel():setText(center(sub, CW - 1)):setPosition(1, 5):setSize(CW - 1, 1)
                cards[#cards + 1] = { frame = f, name = nm, sub = sb, item = it }
                f:onClick(function()
                    local now = os.epoch("utc")
                    selected = it
                    paintCards()
                    describe()
                    if lastClick.name == it.name and now - lastClick.at < 700 then
                        lastClick = { name = nil, at = 0 }
                        defaultAction(it)
                    else
                        lastClick = { name = it.name, at = now }
                    end
                end)
            end
            paintCards()
        end

        refreshView = function(force)
            if view == "store" then
                loadStore(force)
                items = storeItems()
                if not loading then
                    status:setText(string.format("%d %s", #items, t("package(s)")))
                end
            else
                items = manifestItems()
                status:setText(#items == 0 and t("No package installed yet. Open the Store tab.") or string.format("%d %s", #items, t("package(s)")))
            end
            if selected then
                local keep
                for _, it in ipairs(items) do if it.name == selected.name then keep = it end end
                selected = keep
            end
            drawGrid()
            describe()
        end

        local function setView(v)
            view, page, selected = v, 1, nil
            paintTabs()
            refreshView(false)
        end
        for _, b in ipairs(tabButtons) do b.btn:onClick(function() setView(b.view) end) end
        local function doSearch()
            query = ctx.trim(search:getText() or "")
            page = 1
            refreshView(false)
        end
        goBtn:onClick(doSearch)
        search:onKey(function(self, key)
            if key == keys.enter or key == keys.numPadEnter then doSearch() end
        end)
        pager:onClick(function(self, btn, rx)
            local pages = math.max(1, math.ceil(#items / perPage))
            if rx <= 5 then page = page - 1 else page = page + 1 end
            if page < 1 then page = pages end
            if page > pages then page = 1 end
            drawGrid()
        end)

        ctx.setTitle(t("Packages"))
        paintTabs()
        refreshView(false)
    end,
}
