-- /bin/logs.lua : view the centralized NyxOS system log
-- Usage:
--   logs                 show the last 30 lines
--   logs -n <N>           show the last N lines
--   logs -t <tag>          show only lines from a given tag (e.g. "service")
--   logs -f                follow the log in real time (Ctrl+T / q to stop)

local logger = dofile("/lib/logger.lua")
local args = { ... }

local function printLines(lines)
    for _, line in ipairs(lines) do
        print(line)
    end
    if #lines == 0 then
        print("(log is empty)")
    end
end

if args[1] == "-t" and args[2] then
    printLines(logger.filterByTag(args[2]))
    return
end

if args[1] == "-n" and args[2] then
    printLines(logger.tail(tonumber(args[2]) or 30))
    return
end

if args[1] == "-f" then
    print("Following /var/log/nyxos.log -- press q to stop.")
    printLines(logger.tail(20))
    local lastCount = #logger.tail(100000)
    parallel.waitForAny(
        function()
            while true do
                sleep(1)
                local all = logger.tail(100000)
                if #all > lastCount then
                    for i = lastCount + 1, #all do
                        print(all[i])
                    end
                    lastCount = #all
                end
            end
        end,
        function()
            while true do
                local _, key = os.pullEvent("key")
                if key == keys.q then return end
            end
        end
    )
    return
end

printLines(logger.tail(30))
