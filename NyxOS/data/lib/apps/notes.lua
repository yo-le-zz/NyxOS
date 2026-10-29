-- Notes: simple text notes stored in <home>/Notes/*.txt
return {
    id = "notes",
    name = "Notes",
    multi = true,
    icon = {
        palette = { y = "yellow", k = "#8a7a30", r = "red", g = "gray" },
        pixels = {
            "................",
            "..yyyyyyyyyyyy..",
            "..yrrrrrrrrrry..",
            "..yyyyyyyyyyyy..",
            "..ykkkkkkkkkyy..",
            "..yyyyyyyyyyyy..",
            "..ykkkkkkyyyyy..",
            "..yyyyyyyyyyyy..",
            "................",
        },
    },
    build = function(area, ctx)
        local t, palette, accent = ctx.t, ctx.palette, ctx.accent
        local aw, ah = area:getWidth(), area:getHeight()
        local dir = ctx.home .. "/Notes"
        if not fs.exists(ctx.home) then
            area:addLabel():setText(t("Notes need a home folder.")):setPosition(2, 3):setForeground(palette.red)
            return
        end
        if not fs.exists(dir) then ctx.safe("notes", fs.makeDir, dir) end

        ctx.setTitle(t("Notes"))

        local listW = math.min(18, math.floor(aw / 3))
        local list = area:addList():setPosition(1, 2):setSize(listW, ah - 2)
            :setBackground(palette.gray):setForeground(palette.white)
            :setSelectedBackground(accent):setSelectedForeground(palette.black)
        local box = area:addTextBox():setPosition(listW + 2, 2):setSize(aw - listW - 1, ah - 2)
            :setBackground(palette.black):setForeground(palette.white)
        local status = area:addLabel():setText(""):setPosition(1, ah):setSize(aw, 1)
            :setBackground(palette.gray):setForeground(palette.white)

        local names, current = {}, nil

        local function say(text) status:setText((" " .. text):sub(1, aw)) end
        local function saveCurrent()
            if current then
                local f = fs.open(dir .. "/" .. current, "w")
                if f then f.write(box:getText()) f.close() end
            end
        end
        local function refresh(select)
            list:clear()
            names = {}
            for _, name in ipairs(fs.list(dir)) do
                if not fs.isDir(dir .. "/" .. name) then names[#names + 1] = name end
            end
            table.sort(names)
            for _, name in ipairs(names) do list:addItem((name:gsub("%.txt$", ""))) end
            if select then
                for i, name in ipairs(names) do
                    if name == select then pcall(function() list:selectItem(i) end) end
                end
            end
        end
        local function open(name)
            saveCurrent()
            current = name
            local f = fs.open(dir .. "/" .. name, "r")
            box:setText(f and f.readAll() or "")
            if f then f.close() end
            say(name)
            ctx.focus(box)
        end
        list:onSelect(function(self, index)
            if names[index] and names[index] ~= current then open(names[index]) end
        end)

        local function toolbar(x, bw, text, bg, fg, fn)
            area:addButton():setText(text):setPosition(x, 1):setSize(bw, 1)
                :setBackground(bg):setForeground(fg):onClick(fn)
            return x + bw + 1
        end
        local x = 1
        x = toolbar(x, 7, t("New"), palette.lime, palette.black, function()
            ctx.dialog({ title = t("New note"), text = t("Name:"), input = t("My note"), onOk = function(value)
                value = tostring(value):gsub("^%s+", ""):gsub("%s+$", ""):gsub("[/\\]", "-")
                if value == "" then return end
                local name = value .. ".txt"
                if fs.exists(dir .. "/" .. name) then ctx.message(t("Error"), t("This note already exists.")) return end
                saveCurrent()
                local f = fs.open(dir .. "/" .. name, "w")
                if f then f.close() end
                refresh(name)
                open(name)
            end })
        end)
        x = toolbar(x, 7, t("Save"), accent, palette.black, function() saveCurrent() say(t("Saved.")) end)
        x = toolbar(x, 8, t("Rename"), palette.orange, palette.black, function()
            if not current then return end
            ctx.dialog({ title = t("Rename"), text = t("New name for %s", current), input = (current:gsub("%.txt$", "")),
                onOk = function(value)
                    value = tostring(value):gsub("^%s+", ""):gsub("%s+$", ""):gsub("[/\\]", "-")
                    if value == "" then return end
                    saveCurrent()
                    local name = value .. ".txt"
                    if fs.exists(dir .. "/" .. name) then ctx.message(t("Error"), t("This note already exists.")) return end
                    fs.move(dir .. "/" .. current, dir .. "/" .. name)
                    current = name
                    refresh(name)
                end })
        end)
        toolbar(x, 8, t("Delete"), palette.red, palette.white, function()
            if not current then return end
            local victim = current
            ctx.confirm(t("Delete"), t("Delete %s ?", victim), function()
                fs.delete(dir .. "/" .. victim)
                current = nil
                box:setText("")
                refresh()
                say(t("Deleted."))
            end)
        end)

        refresh()
        if #names == 0 then
            say(t("No notes yet. Press New."))
        else
            open(names[1])
            pcall(function() list:selectItem(1) end)
        end

        -- autosave every few seconds while the app is shown
        ctx.basalt.schedule(function()
            while true do
                sleep(3)
                if not ctx.alive() then saveCurrent() return end
                saveCurrent()
            end
        end)
    end,
}
