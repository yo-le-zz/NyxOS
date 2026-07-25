-- /bin/desktop.lua : launches the NyxOS graphical desktop
-- Usage: desktop

local desktop = dofile("/lib/desktop.lua")
local ok = desktop.run()
if not ok then
    print("Falling back to the standard shell.")
    shell.run("/bin/shell")
end
