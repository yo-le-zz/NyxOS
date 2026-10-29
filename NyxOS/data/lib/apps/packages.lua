-- Packages: installed packages (launch / update / remove) and registry browser.
local icon = dofile("/lib/icon.lua")
return {
    id = "packages",
    name = "Packages",
    system = true,
    color = "green",
    icon = icon.builtin.package,
    build = function(area, ctx)
        local t, palette, accent, basalt = ctx.t, ctx.palette, ctx.accent, ctx.basalt
        local nyxlib = dofile("/lib/nyxlib.lua")
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
        for i, name in ipairs({ "Installed", "Browse registry" }) do
            local label = " " .. t(name) .. " "
            local b = area:addButton():setText(label):setPosition(tx, 1):setSize(#label, 1)
            b:onClick(function() showPage(i) end)
            tabButtons[i] = b
            tx = tx + #label + 1
        end

        -------- installed
        local ip = newPage()
        local names, selectedName = {}, nil
        local list = ip:addList():setPosition(2, 1):setSize(aw - 2, ph - 6)
            :setBackground(palette.gray):setForeground(palette.white)
            :setSelectedBackground(accent):setSelectedForeground(palette.black)
        local info = ip:addTextBox():setPosition(2, ph - 4):setSize(aw - 2, 3)
            :setEditable(false):setBackground(palette.black):setForeground(palette.lightGray)

        local function refresh()
            list:clear()
            names = {}
            selectedName = nil
            local manifest = nyxlib.loadManifest()
            for name in pairs(manifest) do table.insert(names, name) end
            table.sort(names)
            for _, name in ipairs(names) do
                local e = manifest[name]
                local tag = e.removed and " (removed)" or (nyxlib.launcherFor(name, e) and "" or " (library)")
                list:addItem({ text = name .. "  v" .. tostring(e.version or "?") .. "  " .. tostring(e.variant or "") .. tag,
                    fg = e.removed and palette.lightGray or palette.white })
            end
            info:setText(#names == 0 and t("No package installed yet. Open the Browse tab.") or t("Select a package."))
        end
        list:onSelect(function(self, index)
            selectedName = names[index]
            local e = selectedName and nyxlib.loadManifest()[selectedName]
            if e then
                info:setText((e.description or "") .. "\nLaunch: " .. tostring(nyxlib.launcherFor(selectedName, e) or "-") ..
                    "   Service: " .. tostring(e.service or "-"))
            end
        end)
        refresh()

        local function need()
            if not selectedName then info:setText(t("Select a package first.")) end
            return selectedName
        end
        local by = ph - 1
        local x = 2
        local function button(label, bg, fg, fn, row)
            label = " " .. t(label) .. " "
            ip:addButton():setText(label):setPosition(x, row or by):setSize(#label, 1)
                :setBackground(bg):setForeground(fg):onClick(fn)
            x = x + #label + 1
        end
        button("Launch", palette.green, palette.black, function()
            local name = need(); if not name then return end
            local e = nyxlib.loadManifest()[name]
            local cmd = nyxlib.launcherFor(name, e)
            if cmd then ctx.runOnTerminal(cmd)
            elseif e and e.service then ctx.openTerminal("service start " .. e.service)
            else info:setText(t("%s has no launcher (it is a library).", name)) end
        end)
        button("Update", accent, palette.black, function()
            local n = need(); if n then ctx.openTerminal("apt update " .. n) end
        end)
        button("Remove", palette.red, palette.white, function()
            local n = need(); if not n then return end
            ctx.confirm("Remove", t("Remove %s ?", n), function() ctx.openTerminal("apt remove " .. n) end)
        end)
        button("Purge", palette.red, palette.white, function()
            local n = need(); if not n then return end
            ctx.confirm("Purge", t("Delete %s and its config?", n), function() ctx.openTerminal("apt purge " .. n) end)
        end)
        button("Refresh", palette.lightBlue, palette.black, refresh)

        -------- browse
        local bp = newPage()
        bp:addLabel():setText(t("Search:")):setForeground(palette.white):setPosition(2, 1)
        local searchLabel = #t("Search:")
        local searchInput = bp:addInput():setPosition(searchLabel + 3, 1):setSize(math.max(6, aw - searchLabel - 14), 1)
            :setBackground(palette.gray):setForeground(palette.white):setText("")
        local results, pick = {}, nil
        local blist = bp:addList():setPosition(2, 3):setSize(aw - 2, ph - 6)
            :setBackground(palette.gray):setForeground(palette.white)
            :setSelectedBackground(accent):setSelectedForeground(palette.black)
        local bstatus = bp:addLabel():setText(t("Type a name (empty = everything), then Search.")):setForeground(palette.lightGray)
            :setPosition(2, ph - 2):setSize(aw - 2, 1)
        blist:onSelect(function(self, index) pick = results[index] end)

        local searching = false
        local function search()
            if searching then return end
            searching = true
            bstatus:setText(t("Searching the registry..."))
            local q = ctx.trim(searchInput:getText())
            basalt.schedule(function()
                local out, err = dofile("/lib/capture.lua").run("apt search " .. (q ~= "" and q or "*"))
                searching = false
                blist:clear()
                results, pick = {}, nil
                for line in (out or ""):gmatch("[^\n]+") do
                    local name = line:match("^(%S+) v")
                    if name then
                        table.insert(results, name)
                        blist:addItem(line)
                    end
                end
                if #results > 0 then
                    bstatus:setText(t("%d package(s). Select one, then Install.", #results))
                else
                    bstatus:setText((err and tostring(err) or ((out and out ~= "") and out or t("No result."))):sub(1, aw - 4))
                end
            end)
        end
        local sl = " " .. t("Search") .. " "
        bp:addButton():setText(sl):setPosition(aw - #sl, 1):setSize(#sl, 1)
            :setBackground(accent):setForeground(palette.black):onClick(search)
        local il = " " .. t("Install") .. " "
        bp:addButton():setText(il):setPosition(2, ph - 1):setSize(#il, 1)
            :setBackground(palette.green):setForeground(palette.black)
            :onClick(function()
                if pick then ctx.openTerminal("apt install " .. pick)
                else bstatus:setText(t("Select a package first.")) end
            end)

        showPage(1)
    end,
}
