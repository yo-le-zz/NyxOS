-- Files: browse, rename, create and delete files and folders.
local icon = dofile("/lib/icon.lua")
return {
    id = "files",
    name = "Files",
    system = true,
    color = "yellow",
    icon = icon.builtin.folder,
    build = function(area, ctx, startDir)
        local t, palette, accent = ctx.t, ctx.palette, ctx.accent
        local nyxlib = dofile("/lib/nyxlib.lua")
        local aw, ah = area:getWidth(), area:getHeight()
        local home = ctx.home

        local currentDir = "/"
        if type(startDir) == "string" and fs.isDir(startDir) then
            currentDir = "/" .. fs.combine("", startDir)
        end
        local entries, selectedIndex = {}, nil
        local lastSel = { index = nil, at = 0 }

        local list = area:addList():setPosition(1, 2):setSize(aw, ah - 2)
            :setBackground(palette.gray):setForeground(palette.white)
            :setSelectedBackground(accent):setSelectedForeground(palette.black)
        local status = area:addLabel():setText(""):setForeground(palette.lightGray)
            :setPosition(2, ah):setSize(math.max(1, aw - 22), 1)

        local function selectedEntry()
            local e = selectedIndex and entries[selectedIndex]
            if not e or e.name == ".." then return nil end
            return e
        end
        local function typeColor(e)
            if e.dir then return palette.yellow end
            if e.name:match("%.lua$") then return palette.lime end
            if e.name:match("%.nyx$") then return palette.cyan end
            if e.name:match("%.json$") or e.name:match("%.txt$") or e.name:match("%.md$") then return palette.lightBlue end
            return palette.white
        end

        local function refresh()
            list:clear()
            entries = {}
            selectedIndex = nil
            if currentDir ~= "/" then table.insert(entries, { name = "..", dir = true }) end
            local names = fs.list(currentDir)
            table.sort(names, function(a, b)
                local da, db = fs.isDir(fs.combine(currentDir, a)), fs.isDir(fs.combine(currentDir, b))
                if da ~= db then return da end
                return a:lower() < b:lower()
            end)
            for _, name in ipairs(names) do
                local full = "/" .. fs.combine(currentDir, name)
                table.insert(entries, { name = name, dir = fs.isDir(full), full = full })
            end
            for _, e in ipairs(entries) do
                local label = e.name == ".." and "  ..  (up)" or ((e.dir and " [DIR]  " or "        ") .. e.name)
                if e.full and not e.dir then
                    label = label .. "  " .. nyxlib.formatSize(fs.getSize(e.full))
                end
                list:addItem({ text = label, fg = e.name == ".." and palette.lightGray or typeColor(e),
                    selectedFg = palette.black })
            end
            ctx.setTitle(currentDir)
            status:setText(t("%d item(s)", #names))
        end

        local function goUp()
            if currentDir == "/" then return end
            local parent = fs.getDir(currentDir)
            currentDir = (parent == "" or parent == "..") and "/" or ("/" .. parent)
            refresh()
        end

        local function openEntry(e)
            if e.name == ".." then goUp()
            elseif e.dir then currentDir = e.full; refresh()
            elseif e.name:match("%.lua$") then ctx.openTerminal(e.full)
            elseif e.name:match("%.nyx$") then ctx.openTerminal("nyx " .. e.full)
            elseif e.name:match("%.txt$") or e.name:match("%.md$") or e.name:match("%.json$") then
                ctx.launch("Code Editor", e.full)
            else status:setText((e.full .. " (" .. nyxlib.formatSize(fs.getSize(e.full)) .. ")"):sub(1, aw - 22)) end
        end

        -- one click selects, a second click on the same row opens it
        list:onSelect(function(self, index)
            selectedIndex = index
            local e = entries[index]
            if not e then return end
            local now = os.epoch("utc")
            if lastSel.index == index and now - lastSel.at < 700 then
                lastSel = { index = nil, at = 0 }
                openEntry(e)
                return
            end
            lastSel = { index = index, at = now }
            status:setText((e.full or e.name):sub(1, math.max(1, aw - 22)))
        end)

        local x = 1
        local function button(bw, text, bg, fg, fn)
            area:addButton():setText(text):setPosition(x, 1):setSize(bw, 1)
                :setBackground(bg):setForeground(fg):onClick(fn)
            x = x + bw + 1
        end
        local function sized(label) return " " .. label .. " " end
        local lg = palette.lightGray
        button(#sized(t("Up")), sized(t("Up")), lg, palette.black, goUp)
        button(#sized(t("Open")), sized(t("Open")), lg, palette.black, function()
            local e = selectedEntry(); if e then openEntry(e) end
        end)
        button(#sized("+" .. t("Dir")), sized("+" .. t("Dir")), palette.green, palette.black, function()
            ctx.dialog({ title = "New folder", text = "Name:", input = "New Folder", onOk = function(v)
                v = ctx.validName(v)
                if not v then ctx.message("Error", "Invalid name.") return end
                local dest = fs.combine(currentDir, v)
                if fs.exists(dest) then ctx.message("Error", t("%s already exists.", v)) return end
                local okMk, errMk = pcall(fs.makeDir, dest)
                if not okMk then ctx.message("Error", tostring(errMk)) end
                refresh()
            end })
        end)
        button(#sized("+" .. t("File")), sized("+" .. t("File")), palette.green, palette.black, function()
            ctx.dialog({ title = "New file", text = "Name:", input = "new.txt", onOk = function(v)
                v = ctx.validName(v)
                if not v then ctx.message("Error", "Invalid name.") return end
                local dest = fs.combine(currentDir, v)
                if fs.exists(dest) then ctx.message("Error", t("%s already exists.", v)) return end
                local f = fs.open(dest, "w")
                if f then f.close() else ctx.message("Error", t("Cannot create %s", v)) end
                refresh()
            end })
        end)
        button(#sized(t("Rename")), sized(t("Rename")), palette.orange, palette.black, function()
            local e = selectedEntry()
            if not e then status:setText(t("Select a file or folder first.")) return end
            ctx.dialog({ title = "Rename", text = t("New name for %s", e.name), input = e.name, onOk = function(v)
                v = ctx.validName(v)
                if not v then ctx.message("Error", "Invalid name.") return end
                local dest = fs.combine(fs.getDir(e.full), v)
                if fs.exists(dest) then ctx.message("Error", t("%s already exists.", v)) return end
                local okMv, errMv = pcall(fs.move, e.full, dest)
                if not okMv then ctx.message("Error", tostring(errMv)) end
                refresh()
            end })
        end)
        button(#sized(t("Delete")), sized(t("Delete")), palette.red, palette.white, function()
            local e = selectedEntry()
            if not e then status:setText(t("Select a file or folder first.")) return end
            ctx.confirm("Delete", t("Delete %s ?", e.name), function()
                local okDel, errDel = pcall(fs.delete, e.full)
                if not okDel then ctx.message("Error", tostring(errDel)) end
                refresh()
            end)
        end)

        local homeLabel, deskLabel = " " .. t("Home") .. " ", " " .. t("Desktop") .. " "
        area:addButton():setText(deskLabel):setPosition(aw - #deskLabel + 1, ah):setSize(#deskLabel, 1)
            :setBackground(palette.lightBlue):setForeground(palette.black)
            :onClick(function()
                local d = home .. "/Desktop"
                if not fs.exists(d) then pcall(fs.makeDir, d) end
                currentDir = d
                refresh()
            end)
        area:addButton():setText(homeLabel):setPosition(aw - #deskLabel - #homeLabel, ah):setSize(#homeLabel, 1)
            :setBackground(palette.lightBlue):setForeground(palette.black)
            :onClick(function() currentDir = fs.exists(home) and home or "/"; refresh() end)
        refresh()
    end,
}
