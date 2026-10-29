-- Terminal: the graphical shell (same UI as the boot shell), in a window.
local icon = dofile("/lib/icon.lua")
return {
    id = "terminal",
    name = "Terminal",
    system = true,
    multi = true,   -- several terminal windows may be open at once
    color = "cyan",
    icon = icon.builtin.terminal,
    build = function(area, ctx, initialCommand)
        local shellui = dofile("/lib/shellui.lua")
        local controller = shellui.mount(ctx.basalt, area, {
            header = false,
            onExit = function() ctx.closeWindow() end,
        })
        if type(initialCommand) == "string" and initialCommand ~= "" and controller then
            controller.execute(initialCommand)
        end
    end,
}
