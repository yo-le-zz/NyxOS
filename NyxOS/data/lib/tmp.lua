-- /lib/tmp.lua : NyxOS temporary-file housekeeping
--
-- Centralizes the folders NyxOS treats as scratch space so that a clean
-- shutdown/reboot can wipe them, the same way /tmp is expected to be
-- cleared (or lives on tmpfs) on a real Linux system. CC:Tweaked gives
-- us no actual "run this on power-off" hook, so the guarantee here is
-- provided by the `shutdown`/`reboot` commands themselves (see
-- /bin/shutdown.lua, /bin/reboot.lua): always use those instead of the
-- raw os.shutdown()/os.reboot() to get a clean tmp wipe.

local tmp = {}

tmp.DIRS = {
    "/var/tmp",
    "/var/apt/tmp",
}

function tmp.ensure()
    for _, dir in ipairs(tmp.DIRS) do
        if not fs.exists(dir) then
            fs.makeDir(dir)
        end
    end
end

-- Wipes every registered tmp folder's *contents* (keeps the folders
-- themselves so nothing has to re-create them next boot).
function tmp.clean()
    for _, dir in ipairs(tmp.DIRS) do
        if fs.exists(dir) and fs.isDir(dir) then
            for _, name in ipairs(fs.list(dir)) do
                pcall(fs.delete, fs.combine(dir, name))
            end
        end
    end
end

return tmp
