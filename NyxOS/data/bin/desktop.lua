-- /bin/desktop.lua : launches the NyxOS graphical desktop
-- Usage: desktop

-- /lib/desktop.lua is loaded with dofile(), i.e. in the global
-- environment, where `shell` is not defined (only programs get it).
-- Publish it for the libraries (normally already done by /nyxos.lua).
if shell and not _G.shell then _G.shell = shell end

local desktop = dofile("/lib/desktop.lua")
local ok = desktop.run()
if not ok then
    print("Falling back to the standard shell.")
    shell.run("shell")
end
