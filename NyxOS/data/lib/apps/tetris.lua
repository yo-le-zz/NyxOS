-- Tetris: left/right (A/D) move, up (W) rotate, down (S) soft drop, space hard drop, P pause.
local SHAPES = {
    { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 } },   -- I
    { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },   -- O
    { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 1, 1 } },   -- T
    { { 1, 0 }, { 2, 0 }, { 0, 1 }, { 1, 1 } },   -- S
    { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 2, 1 } },   -- Z
    { { 0, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } },   -- J
    { { 2, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } },   -- L
}
local COLORS = { "b", "4", "a", "5", "e", "3", "1" }   -- canvas hex colours (see canvas.lua)

return {
    id = "tetris",
    name = "Tetris",
    multi = true,
    size = { 34, 22 },
    icon = {
        palette = { c = "cyan", y = "yellow", p = "purple", k = "black", g = "gray" },
        pixels = {
            "gggggggggggggggg",
            "gkkkkkkkkkkkkkkg",
            "gkkkkccckkkkkkkg",
            "gkkkkkkkkkpkkkkg",
            "gkkkkkkkkpppkkkg",
            "gkkkyykkkkkkkkkg",
            "gkkkyykkcccckkkg",
            "gkkkkkkkkkkkkkkg",
            "gggggggggggggggg",
        },
    },
    build = function(area, ctx)
        local t = ctx.t
        local cv = dofile("/lib/canvas.lua")
        local aw, ah = area:getWidth(), area:getHeight()
        local W, H = 10, math.min(20, ah - 1)
        local img = area:addImage():setPosition(1, 2):setSize(W * 2 + 2, H)
        local info = area:addLabel():setText(""):setPosition(1, 1):setSize(aw, 1)
            :setBackground(ctx.palette.gray):setForeground(ctx.palette.white)
        local side = area:addLabel():setText(""):setPosition(W * 2 + 4, 2):setSize(math.max(1, aw - W * 2 - 4), 6)
        local board, piece, px, py, score, lines, dead, paused, nextId
        local function cells(p, x, y)
            local out = {}
            for _, c in ipairs(p.cells) do out[#out + 1] = { x + c[1], y + c[2] } end
            return out
        end
        local function fits(p, x, y)
            for _, c in ipairs(cells(p, x, y)) do
                if c[1] < 1 or c[1] > W or c[2] > H then return false end
                if c[2] >= 1 and board[c[2]][c[1]] ~= 0 then return false end
            end
            return true
        end
        local function spawn()
            local id = nextId or math.random(#SHAPES)
            nextId = math.random(#SHAPES)
            local cs = {}
            for i, c in ipairs(SHAPES[id]) do cs[i] = { c[1], c[2] } end
            piece = { id = id, cells = cs }
            px, py = 4, 0
            if not fits(piece, px, py) then dead = true end
        end
        local function reset()
            board = {}
            for y = 1, H do board[y] = {} for x = 1, W do board[y][x] = 0 end end
            score, lines, dead, paused, nextId = 0, 0, false, false, nil
            spawn()
        end
        local function rotate()
            local rc = {}
            local maxy = 0
            for _, c in ipairs(piece.cells) do maxy = math.max(maxy, c[2]) end
            for i, c in ipairs(piece.cells) do rc[i] = { maxy - c[2], c[1] } end
            local test = { cells = rc }
            for _, kick in ipairs({ 0, -1, 1, -2, 2 }) do
                if fits(test, px + kick, py) then piece.cells = rc px = px + kick return end
            end
        end
        local function lock()
            for _, c in ipairs(cells(piece, px, py)) do
                if c[2] >= 1 then board[c[2]][c[1]] = piece.id end
            end
            local cleared = 0
            local y = H
            while y >= 1 do
                local full = true
                for x = 1, W do if board[y][x] == 0 then full = false break end end
                if full then
                    table.remove(board, y)
                    local row = {} for x = 1, W do row[x] = 0 end
                    table.insert(board, 1, row)
                    cleared = cleared + 1
                else
                    y = y - 1
                end
            end
            lines = lines + cleared
            score = score + ({ 0, 100, 300, 500, 800 })[cleared + 1]
            spawn()
        end
        local function drop()
            if fits(piece, px, py + 1) then py = py + 1 return true end
            lock() return false
        end
        local function draw()
            local c = cv.new(W * 2 + 2, H, "f")
            for y = 1, H do
                c:rect(1, y, 1, 1, "7") c:rect(W * 2 + 2, y, 1, 1, "7")
                for x = 1, W do
                    local v = board[y][x]
                    if v ~= 0 then c:rect(x * 2, y, 2, 1, COLORS[v]) end
                end
            end
            if not dead then
                for _, cc in ipairs(cells(piece, px, py)) do
                    if cc[2] >= 1 then c:rect(cc[1] * 2, cc[2], 2, 1, COLORS[piece.id]) end
                end
            else
                local msg = " " .. t("Game over - Enter") .. " "
                c:put(math.max(1, math.floor((W * 2 + 2 - #msg) / 2)), math.floor(H / 2), msg, "f", "e")
            end
            if paused then
                local msg = " " .. t("Paused") .. " "
                c:put(math.max(1, math.floor((W * 2 + 2 - #msg) / 2)), math.floor(H / 2), msg, "f", "4")
            end
            img:setBimg(c:bimg())
            info:setText(string.format(" %s %d   Lines %d   [P] %s", t("Score"), score, lines, t("pause")))
        end
        local function onKey(key)
            local k = keys.getName and keys.getName(key) or ""
            if dead then
                if key == keys.enter then reset() end
            elseif k == "p" then paused = not paused
            elseif paused then
            elseif key == keys.left or k == "a" then if fits(piece, px - 1, py) then px = px - 1 end
            elseif key == keys.right or k == "d" then if fits(piece, px + 1, py) then px = px + 1 end
            elseif key == keys.up or k == "w" then rotate()
            elseif key == keys.down or k == "s" then drop() score = score + 1
            elseif key == keys.space then while drop() do score = score + 2 end
            end
            draw()
        end
        local function hook(key) if ctx.isActive() then onKey(key) end end
        ctx.basalt.onEvent("key", hook)
        ctx.onClose(function() ctx.basalt.removeEvent("key", hook) end)
        ctx.setTitle("Tetris")
        reset()
        draw()
        ctx.basalt.schedule(function()
            while true do
                sleep(math.max(0.08, 0.6 - lines * 0.02))
                if not ctx.alive() then return end
                if ctx.isActive() and not dead and not paused then drop() draw() end
            end
        end)
    end,
}
