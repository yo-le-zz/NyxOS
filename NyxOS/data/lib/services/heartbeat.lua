-- Example NyxOS service: periodically logs a heartbeat line.
-- Demonstrates the shape every service's exec file must follow:
-- `return function(args) ... end`, running forever and yielding via
-- sleep()/os.pullEvent() so it cooperates with the scheduler.

return function(args)
    local logger = dofile("/lib/logger.lua")
    while true do
        logger.info("heartbeat", "still alive, uptime file present: " .. tostring(fs.exists("/var/run/boot.time")))
        sleep(300)
    end
end
