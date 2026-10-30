-- Browser: pages from the NyxOS network (http / https) and the real internet.
local icon = dofile("/lib/icon.lua")
return {
    id = "browser",
    name = "Browser",
    multi = true,
    color = "lightBlue",
    icon = {
        palette = { b = "blue", l = "lightBlue", w = "white", g = "green", k = "gray" },
        pixels = {
            "....bbbbbbbb....",
            "..bblllllllbbb..",
            ".blllgglllllllb.",
            ".bllgggglllwwlb.",
            "bllllgggllwwwllb",
            "blllllgglllwwllb",
            ".blllllllllllbb.",
            "..bbllllllbbb...",
            "....bbbbbbbb....",
        },
    },
    size = { 50, 17 },
    build = function(area, ctx, arg)
        local t, palette, accent = ctx.t, ctx.palette, ctx.accent
        local web = dofile("/lib/nyxhttp.lua")
        local aw, ah = area:getWidth(), area:getHeight()
        local history, pos, current, links = {}, 0, nil, {}

        local back = area:addButton():setText(" < "):setPosition(1, 1):setSize(3, 1)
            :setBackground(palette.lightGray):setForeground(palette.black)
        local input = area:addInput():setPosition(5, 1):setSize(aw - 11, 1)
            :setBackground(palette.gray):setForeground(palette.white):setText(type(arg) == "string" and arg or "http://")
        local go = area:addButton():setText(t("Go")):setPosition(aw - 5, 1):setSize(6, 1)
            :setBackground(accent):setForeground(palette.black)
        local page = area:addTextBox():setPosition(1, 2):setSize(aw, ah - 8)
            :setEditable(false):setBackground(palette.black):setForeground(palette.white)
        local list = area:addList():setPosition(1, ah - 5):setSize(aw, 5)
            :setBackground(palette.gray):setForeground(palette.cyan)
            :setSelectedBackground(accent):setSelectedForeground(palette.black)
        local status = area:addLabel():setText(""):setPosition(1, ah - 6):setSize(aw, 1)
            :setBackground(palette.gray):setForeground(palette.white)

        local function say(text) status:setText((" " .. text):sub(1, aw)) end

        local function show(res, url)
            local ct = tostring(res.headers["content-type"] or res.headers["Content-Type"] or "")
            local text, found, title
            if ct:find("html") or res.body:find("<[Hh][Tt][Mm][Ll]") or res.body:find("<[Bb][Oo][Dd][Yy]") then
                text, found, title = web.htmlToText(res.body)
            else
                text, found = res.body, {}
            end
            links = found
            page:setText(text)
            pcall(function() page:setScrollY(0) end)
            list:clear()
            for i, l in ipairs(links) do
                list:addItem({ text = string.format("[%d] %s", i, l.text:sub(1, 20)) .. "  " .. l.href, fg = palette.cyan, selectedFg = palette.black })
            end
            ctx.setTitle(t("Browser") .. " - " .. (title or url))
            say(string.format("%d  %s%s  %s", res.status, res.secure and "https " or "", res.via == "internet" and "internet" or "NyxOS", url))
        end

        local function load(url, noHistory)
            url = ctx.trim(url or "")
            if url == "" then return end
            if not url:match("^%a+://") then url = "http://" .. url end
            input:setText(url)
            say(t("Loading...") .. " " .. url)
            ctx.basalt.schedule(function()
                local okR, res, err = ctx.try("browser", function() return web.get(url, nil, 8) end)
                if not okR then say(t("Error")) return end
                if not res then
                    page:setText(t("Cannot load %s", url) .. "\n\n" .. tostring(err))
                    list:clear()
                    say(tostring(err))
                    return
                end
                if not noHistory then
                    while #history > pos do table.remove(history) end
                    history[#history + 1] = url
                    pos = #history
                end
                current = url
                show(res, url)
            end)
        end

        go:onClick(function() load(input:getText()) end)
        input:onKey(function(self, key)
            if key == keys.enter or key == keys.numPadEnter then load(input:getText()) end
        end)
        back:onClick(function()
            if pos > 1 then
                pos = pos - 1
                load(history[pos], true)
            end
        end)
        local lastPick = { i = nil, at = 0 }
        list:onSelect(function(self, index)
            local l = links[index]
            if not l or not current then return end
            local now = os.epoch("utc")
            if lastPick.i == index and now - lastPick.at < 700 then
                lastPick = { i = nil, at = 0 }
                load(web.resolveLink(current, l.href))
            else
                lastPick = { i = index, at = now }
                say(web.resolveLink(current, l.href) .. "  (" .. t("double-click to open") .. ")")
            end
        end)

        ctx.setTitle(t("Browser"))
        page:setText(t("Type an address (http://name/ or https://name/) and press Enter.\nNames come from /etc/hosts and the DNS server; other sites use the real internet if it is enabled."))
        if type(arg) == "string" and arg:match("%a+://") then load(arg) else ctx.focus(input) end
    end,
}
