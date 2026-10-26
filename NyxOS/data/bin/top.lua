-- /bin/top.lua : live process list (refreshes every 2 seconds)
-- Usage: top        press Q to quit

local services = dofile("/lib/services.lua")
local procui = dofile("/lib/procui.lua")
local specs = dofile("/lib/specs.lua")

if not services.scheduler() then
    print("top: the scheduler is not running.")
    return
end

local timer = os.startTimer(0)
while true do
    local ev, a = os.pullEvent()
    if ev == "timer" and a == timer then
        term.clear()
        term.setCursorPos(1, 1)
        print("NyxOS top -- press Q to quit    heap " .. string.format("%.0f", collectgarbage("count")) .. " KB")
        print("")
        procui.print(procui.snapshot("all"))
        timer = os.startTimer(2)
    elseif ev == "char" and (a == "q" or a == "Q") then
        break
    end
end
term.clear()
term.setCursorPos(1, 1)
