-- /lib/monitorbridge.lua
--
-- Basalt only reacts to real "mouse_click" / "mouse_up" / "mouse_drag" /
-- "mouse_scroll" events. When the terminal has been redirected to an
-- Advanced Monitor (see /lib/display.lua), touching that monitor in-game
-- fires "monitor_touch" events instead -- which Basalt does not
-- understand out of the box. Without this fix, the graphical shell /
-- login screen / installer render correctly on the screen but never
-- respond to touch, and any code that assumes Basalt "works" ends up
-- reporting Basalt as unavailable when it actually just never receives
-- usable input.
--
-- monitorbridge.patch(basalt) wraps basalt.run so that, for the
-- duration of that run, "monitor_touch" events are translated into the
-- "mouse_click" + "mouse_up" pair Basalt expects (mirroring a real
-- click). It is safe to call this on the same basalt module more than
-- once -- it only patches once.

local monitorbridge = {}

function monitorbridge.patch(basalt)
    if not basalt or basalt._nyxMonitorBridged then
        return basalt
    end

    local originalRun = basalt.run
    if type(originalRun) ~= "function" then
        return basalt
    end

    basalt.run = function(...)
        local args = { ... }

        local function runBasalt()
            return originalRun(table.unpack(args))
        end

        local function translateTouches()
            while true do
                local _, side, x, y = os.pullEvent("monitor_touch")
                os.queueEvent("mouse_click", 1, x, y)
                os.queueEvent("mouse_up", 1, x, y)
            end
        end

        if not parallel then
            -- No parallel API available (should not happen on
            -- CC: Tweaked) -- fall back to the unpatched behaviour.
            return runBasalt()
        end

        return parallel.waitForAny(runBasalt, translateTouches)
    end

    basalt._nyxMonitorBridged = true
    return basalt
end

return monitorbridge
