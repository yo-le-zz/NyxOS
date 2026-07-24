-- /bin/newterm.lua : opens a second NyxOS terminal
--
-- On an Advanced Computer, CC:Tweaked's native `multishell` API gives
-- real independent terminal tabs -- NyxOS uses that directly when
-- available. On a normal (non-Advanced) computer there is no such
-- thing as multiple terminals, so this explains the limitation instead
-- of pretending to open one.

local args = { ... }

if not multishell then
    print("newterm: multiple terminals need an Advanced Computer (multishell API).")
    return
end

local program = args[1] or "/bin/shell.lua"
if not fs.exists(program) and program == "/bin/shell.lua" then
    program = "shell" -- fall back to the default rom shell if NyxOS has no /bin/shell.lua
end

local id = multishell.launch({}, program, table.unpack(args, 2))
multishell.setTitle(id, "NyxOS")
multishell.setFocus(id)
print("Opened a new terminal (tab " .. id .. "). Ctrl+Tab / F1-F9 switch tabs.")
