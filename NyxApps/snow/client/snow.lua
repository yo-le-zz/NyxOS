local w, h = term.getSize()
local flakes = {}
for i = 1, math.floor(w * h / 25) do
    flakes[i] = { x = math.random(w), y = math.random(h), s = math.random(1, 2) }
end
term.setBackgroundColor(colors.black)
term.clear()
local timer = os.startTimer(0.1)
while true do
    local e, a = os.pullEvent()
    if e == "key" or e == "mouse_click" or e == "terminate" then break end
    if e == "timer" and a == timer then
        for _, f in ipairs(flakes) do
            term.setCursorPos(f.x, f.y)
            term.write(" ")
            f.y = f.y + f.s
            f.x = f.x + math.random(-1, 1)
            if f.y > h then f.y = 1 f.x = math.random(w) end
            f.x = math.max(1, math.min(w, f.x))
            term.setCursorPos(f.x, f.y)
            term.setTextColor(f.s == 1 and colors.lightGray or colors.white)
            term.write(f.s == 1 and "." or "*")
        end
        timer = os.startTimer(0.1)
    end
end
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
