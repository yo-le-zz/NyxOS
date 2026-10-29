-- Calendar: month view, events saved per user in <home>/.calendar
return {
    id = "calendar",
    name = "Calendar",
    size = { 49, 12 },
    icon = {
        palette = { r = "red", w = "white", k = "gray", o = "orange", g = "lightGray" },
        pixels = {
            ".gggggggggggggg.",
            ".rrrrrrrrrrrrrr.",
            ".rrrrrrrrrrrrrr.",
            ".wwwwwwwwwwwwww.",
            ".wgwgwgwgwgwgww.",
            ".wwwwwwwwoowwww.",
            ".wgwgwgwgooggww.",
            ".wwwwwwwwwwwwww.",
            ".gggggggggggggg.",
        },
    },
    build = function(area, ctx)
        local t, palette, accent = ctx.t, ctx.palette, ctx.accent
        local nyxlib = dofile("/lib/nyxlib.lua")
        local aw, ah = area:getWidth(), area:getHeight()
        local path = ctx.home .. "/.calendar"
        local canSave = fs.exists(ctx.home)
        local events = canSave and nyxlib.loadTable(path) or {}

        local function save()
            if canSave then pcall(nyxlib.saveTable, path, events) end
        end

        local MONTHS = { "January", "February", "March", "April", "May", "June", "July",
            "August", "September", "October", "November", "December" }
        local DAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
        local mondayFirst = t("WEEK_STARTS_ON_MONDAY") == "yes"

        local function leap(y) return (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0 end
        local function daysIn(y, m)
            local d = { 31, leap(y) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
            return d[m]
        end
        local function weekday(y, m, d) -- 0 = Sunday
            local off = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
            if m < 3 then y = y - 1 end
            return (y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) + off[m] + d) % 7
        end
        local function key(y, m, d) return string.format("%04d-%02d-%02d", y, m, d) end

        local now = os.date("*t")
        local today = { y = now.year, m = now.month, d = now.day }
        local view = { y = today.y, m = today.m }
        local selected = { y = today.y, m = today.m, d = today.d }

        local monthLabel = area:addLabel():setText(""):setPosition(7, 1):setSize(18, 1)
            :setForeground(palette.white)
        local cellW = 4
        local gridX, gridY = 2, 3

        -- weekday header
        for i = 0, 6 do
            local idx = (mondayFirst and (i + 1) % 7 or i) + 1
            area:addLabel():setText(t(DAYS[idx]):sub(1, 3)):setPosition(gridX + i * cellW, 2)
                :setForeground(palette.lightGray)
        end

        local cells = {}
        local eventList, eventDays, dateLabel, input
        local entries = {}

        local function refreshEvents()
            local k = key(selected.y, selected.m, selected.d)
            entries = events[k] or {}
            eventList:clear()
            for _, text in ipairs(entries) do eventList:addItem(text) end
            local wd = weekday(selected.y, selected.m, selected.d)
            dateLabel:setText(string.format("%s %d %s %d", t(DAYS[wd + 1]), selected.d,
                t(MONTHS[selected.m]), selected.y):sub(1, aw - 30))
            ctx.setTitle(t("Calendar") .. " - " .. t(MONTHS[view.m]) .. " " .. view.y)
        end

        local function refreshGrid()
            monthLabel:setText(ctx.center(t(MONTHS[view.m]) .. " " .. view.y, 18))
            local first = weekday(view.y, view.m, 1)
            if mondayFirst then first = (first + 6) % 7 end
            local total = daysIn(view.y, view.m)
            for i = 1, 42 do
                local btn = cells[i]
                local day = i - first
                if day >= 1 and day <= total then
                    local isToday = (view.y == today.y and view.m == today.m and day == today.d)
                    local isSel = (view.y == selected.y and view.m == selected.m and day == selected.d)
                    local has = events[key(view.y, view.m, day)] ~= nil
                    local bg, fg = palette.gray, palette.white
                    if has then bg, fg = palette.orange, palette.black end
                    if isToday then bg, fg = accent, palette.black end
                    if isSel then bg, fg = palette.white, palette.black end
                    btn:setText(string.format("%2d", day)):setBackground(bg):setForeground(fg)
                    btn:setVisible(true)
                    btn.day = day
                else
                    btn:setVisible(false)
                    btn.day = nil
                end
            end
        end

        for i = 1, 42 do
            local col = (i - 1) % 7
            local row = math.floor((i - 1) / 7)
            local btn = area:addButton():setText(""):setPosition(gridX + col * cellW, gridY + row)
                :setSize(3, 1)
            btn:onClick(function(self)
                if self.day then
                    selected = { y = view.y, m = view.m, d = self.day }
                    refreshGrid()
                    refreshEvents()
                end
            end)
            cells[i] = btn
        end

        local function shift(delta)
            view.m = view.m + delta
            if view.m < 1 then view.m, view.y = 12, view.y - 1 end
            if view.m > 12 then view.m, view.y = 1, view.y + 1 end
            refreshGrid()
        end
        area:addButton():setText("<"):setPosition(2, 1):setSize(3, 1)
            :setBackground(palette.lightGray):setForeground(palette.black):onClick(function() shift(-1) end)
        area:addButton():setText(">"):setPosition(26, 1):setSize(3, 1)
            :setBackground(palette.lightGray):setForeground(palette.black):onClick(function() shift(1) end)
        area:addButton():setText(t("Today")):setPosition(2, ah):setSize(7, 1)
            :setBackground(accent):setForeground(palette.black):onClick(function()
                view = { y = today.y, m = today.m }
                selected = { y = today.y, m = today.m, d = today.d }
                refreshGrid()
                refreshEvents()
            end)

        -- right panel: events of the selected day
        local px = 31
        local pw = aw - px
        if pw >= 12 then
            dateLabel = area:addLabel():setText(""):setPosition(px, 1):setForeground(accent)
            eventList = area:addList():setPosition(px, 3):setSize(pw, math.max(2, ah - 7))
                :setBackground(palette.gray):setForeground(palette.white)
                :setSelectedBackground(accent):setSelectedForeground(palette.black)
            input = area:addInput():setPosition(px, ah - 3):setSize(pw, 1)
                :setBackground(palette.gray):setForeground(palette.white):setPlaceholder(t("New event..."))
            local function add()
                local text = (input:getText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if text == "" then return end
                local k = key(selected.y, selected.m, selected.d)
                events[k] = events[k] or {}
                table.insert(events[k], text)
                input:setText("")
                save()
                refreshGrid()
                refreshEvents()
            end
            input:onKey(function(self, k2)
                if k2 == keys.enter or k2 == keys.numPadEnter then add() end
            end)
            local chosen
            eventList:onSelect(function(self, index) chosen = index end)
            area:addButton():setText(t("Add")):setPosition(px, ah - 1):setSize(6, 1)
                :setBackground(palette.lime):setForeground(palette.black):onClick(add)
            area:addButton():setText(t("Delete")):setPosition(px + 7, ah - 1):setSize(math.max(6, pw - 7), 1)
                :setBackground(palette.red):setForeground(palette.white):onClick(function()
                    local k = key(selected.y, selected.m, selected.d)
                    if chosen and events[k] and events[k][chosen] then
                        table.remove(events[k], chosen)
                        if #events[k] == 0 then events[k] = nil end
                        chosen = nil
                        save()
                        refreshGrid()
                        refreshEvents()
                    end
                end)
        else
            dateLabel = area:addLabel():setText(""):setPosition(2, ah - 1)
            eventList = { clear = function() end, addItem = function() end }
        end
        if not canSave then
            area:addLabel():setText(t("Events are not saved (no home folder)."))
                :setPosition(12, ah):setForeground(palette.red)
        end
        refreshGrid()
        refreshEvents()
    end,
}
