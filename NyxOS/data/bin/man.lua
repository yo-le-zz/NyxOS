-- /bin/man.lua : shows help for NyxOS commands, with a real pager
-- (full scrolling, not just the last few lines).
-- Usage: man [command]

local nyxlib = dofile("/lib/nyxlib.lua")
local themeOk, theme = pcall(dofile, "/lib/theme.lua")
local palette = colors or colours

local pages = {
    tree = {
        "tree [-L depth] [path]",
        "Shows the file tree Unix `tree`-style, with the number of",
        "folders/files at the end.",
        "",
        "Examples:",
        "  tree",
        "  tree /home",
        "  tree -L 2 /",
    },
    apt = {
        "apt install|remove|purge|update|list|info|tool - NyxOS package manager.",
        "",
        "  apt install <name> [client|server]  install a NyxApps package",
        "  apt install <url|path>              install from install.lua",
        "  apt install ./disk                  install from a local folder",
        "  apt update [name]                   check for/apply updates",
        "  apt remove <package>                delete files, keep /etc",
        "  apt purge <package>                  delete everything, incl. /etc",
        "  apt list                            list installed packages",
        "  apt info <package>                  show details about a package",
        "  apt tool install <name> [url]       install a shared library",
        "  apt tool list                       list installed shared libraries",
        "  apt tool remove <name>              remove a shared library",
        "",
        "Packages follow the app.json standard (name, version, description,",
        "author, type, client/server entry+installer+uninstaller). See",
        "docs/PACKAGING.md to build your own packages.",
    },
    cat = { "cat <file...>", "Prints the contents of one or more files." },
    echo = { "echo <text>", "Prints the given text." },
    touch = { "touch <file>", "Creates an empty file if it doesn't exist." },
    pwd = { "pwd", "Prints the current folder." },
    whoami = { "whoami", "Prints the currently logged in user." },
    hostname = { "hostname [name]", "Shows or changes the computer's name." },
    uname = { "uname", "Prints system information." },
    date = { "date [format]", "Prints the date and time." },
    uptime = { "uptime", "Shows elapsed time since boot." },
    df = { "df", "Shows available disk space." },
    find = { "find [folder] -name <pattern>", "Searches for files." },
    grep = { "grep <pattern> <file>", "Searches for text within a file." },
    head = { "head [-n N] <file>", "Prints the first N lines." },
    tail = { "tail [-n N] <file>", "Prints the last N lines." },
    wc = { "wc <file>", "Counts lines/words/characters." },
    passwd = {
        "passwd [user]",
        "Changes a password. Without an argument: changes your own",
        "password (the old one is requested if there is one). With a",
        "username: changes another account's password, restricted to",
        "administrators.",
    },
    adduser = {
        "adduser <name> [admin]",
        "Creates a new NyxOS user (restricted to administrators).",
        "Add 'admin' at the end to make them an administrator.",
        "",
        "Examples:",
        "  adduser bob",
        "  adduser alice admin",
    },
    deluser = {
        "deluser <name>",
        "Deletes a NyxOS user (restricted to administrators).",
        "Refuses to delete the system's last administrator.",
    },
    users = { "users", "Lists the users configured on this computer." },
    display = { "display [scan|scale <n>]", "Manages the connected screen (monitor)." },
    neofetch = { "neofetch", "Shows a system summary with the NyxOS logo." },
    sudo = {
        "sudo <command> [args...]",
        "Runs a command with administrator privileges. Asks for your",
        "password once, then remembers it for a short time (a 'sudo",
        "session', like on Linux) so you don't need to retype it for",
        "every command.",
        "",
        "  sudo -k        drops the current sudo session immediately",
        "  sudo -v         refreshes/extends the current sudo session",
    },
    service = {
        "service <start|stop|restart|enable|disable|status|list|logs> [name]",
        "Controls NyxOS background services (daemons), similar to",
        "systemd/init.d on Linux. Enabled services are started",
        "automatically at boot, alongside the shell.",
        "",
        "Examples:",
        "  service list",
        "  service status heartbeat",
        "  service enable heartbeat",
    },
    nyx = {
        "nyx <script.nyx> [args...]",
        "Runs a .nyx automation script (see docs/NYX_SCRIPTING.md).",
        "A small mix of shell scripting and old-style batch scripting",
        "(labels + goto), meant to be easy to read and write by hand.",
    },
    mkpkg = {
        "mkpkg <name> [client|server|both]",
        "Instantly scaffolds a valid app.json package skeleton, ready",
        "to edit and install with 'apt install <path>'.",
    },
    reset = {
        "reset [--yes]",
        "Removes every package installed on top of the base system",
        "(restricted to administrators/sudo).",
    },
    recovery = {
        "recovery",
        "Repairs core system files (/bin, /lib, /startup.lua) from",
        "GitHub without touching users, config, or /home.",
    },
    newterm = {
        "newterm",
        "Opens a second terminal (Advanced Computer / multishell only).",
    },
    logs = {
        "logs [-n N] [-t tag] [-f]",
        "Shows the centralized NyxOS system log.",
    },
    db = {
        "db list|tables|dump|delete",
        "Inspects NyxOS mini-databases (/var/db).",
    },
    curl = { "curl <url> [-o file]", "Fetches a URL." },
    wget = { "wget <url> <file>", "Downloads a URL to a file." },
    net = {
        "net open|host|discover|send|dhcp",
        "rednet helper commands (see 'man net' in the source for details).",
    },
    machineid = { "machineid", "Shows this computer's NyxOS machine identity." },
    rm = {
        "rm [-r] [-f] [-i] <path...>",
        "Deletes files/folders. -r allows deleting a folder, -f skips",
        "confirmation, -i asks before every single deletion. Deleting",
        "a wildcard ('*') or several items always asks for a typed",
        "'yes' confirmation first, unless -f is given.",
    },
    dd = {
        "dd if=<source> of=<dest> [bs=<bytes>] [count=<n>]",
        "Low-level byte copy. Works with /dev/zero and /dev/null.",
        "Example: dd if=/dev/zero of=blank.bin bs=1024 count=10",
    },
    guimode = {
        "guimode [on|off|shell|desktop]",
        "Shows or changes whether NyxOS boots with the graphical",
        "interface (Basalt) or stays in text mode, and whether it",
        "boots into the plain graphical shell or the full desktop.",
        "Takes effect on the next reboot.",
    },
    desktop = {
        "desktop",
        "Launches the NyxOS graphical desktop: taskbar, desktop icons,",
        "a Windows-style file explorer, an embedded terminal, an apt",
        "front-end, and a task manager with power buttons. Set as the",
        "default boot UI with 'guimode desktop'.",
    },
    man = {
        "man <command>",
        "Shows a NyxOS command's help in a pager.",
        "",
        "Moving around the pager:",
        "  Up/Down or arrows    scroll one line",
        "  Space / Page Down     next page",
        "  Page Up               previous page",
        "  q or Enter            quit",
    },
}

local function sortedNames()
    local names = {}
    for name in pairs(pages) do table.insert(names, name) end
    table.sort(names)
    return names
end

-- Builds the full text (title + description) of a page for the pager,
-- as a list of lines.
local function pageLines(cmd)
    local body = pages[cmd]
    local lines = { cmd, string.rep("-", #cmd) }
    for _, l in ipairs(body) do
        table.insert(lines, l)
    end
    return lines
end

local function indexLines()
    local lines = { "Available NyxOS commands:", "" }
    for _, name in ipairs(sortedNames()) do
        table.insert(lines, "  " .. name)
    end
    table.insert(lines, "")
    table.insert(lines, "Use 'man <command>' for more details.")
    return lines
end

------------------------------------------------------------------
-- Pure text pager (reliable, always works): full line-by-line and
-- page-by-page scrolling via key events, instead of a plain `print`
-- that only showed the last few lines.
------------------------------------------------------------------
local function runTextPager(lines, accent)
    local w, h = term.getSize()
    local viewHeight = h - 1
    local offset = 0
    local maxOffset = math.max(0, #lines - viewHeight)

    local function draw()
        term.setBackgroundColor(palette.black)
        term.clear()
        for row = 1, viewHeight do
            local line = lines[offset + row]
            if line then
                term.setCursorPos(1, row)
                pcall(term.setTextColor, palette.white)
                term.write(line)
            end
        end
        term.setCursorPos(1, h)
        pcall(term.setTextColor, accent or palette.lightGray)
        term.clearLine()
        term.write("-- line " .. (offset + 1) .. "/" .. #lines ..
            " -- Up/Down scrolls, Space next page, q quits --")
        pcall(term.setTextColor, palette.white)
    end

    draw()
    while true do
        local event, key = os.pullEvent("key")
        if key == keys.q or key == keys.enter or key == keys.numPadEnter then
            break
        elseif key == keys.down then
            offset = math.min(maxOffset, offset + 1)
            draw()
        elseif key == keys.up then
            offset = math.max(0, offset - 1)
            draw()
        elseif key == keys.space or key == keys.pageDown then
            offset = math.min(maxOffset, offset + viewHeight)
            draw()
        elseif key == keys.pageUp then
            offset = math.max(0, offset - viewHeight)
            draw()
        end
    end
    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)
end

------------------------------------------------------------------
-- Graphical pager (Basalt), with a real scroll area. If Basalt is
-- absent or fails, falls back automatically to the text pager above.
------------------------------------------------------------------
local function runBasaltPager(lines, accent)
    if not fs.exists("/lib/basalt.lua") then
        return false
    end
    local ok, basalt = pcall(dofile, "/lib/basalt.lua")
    if not ok or not basalt then
        return false
    end
    local bridgeOk, bridge = pcall(dofile, "/lib/monitorbridge.lua")
    if bridgeOk and bridge then
        pcall(bridge.patch, basalt)
    end

    local ran = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)

        local scroll = main:addScrollFrame()
            :setBackground(palette.black)
            :setPosition(2, 2)
            :setSize("{parent.width - 2}", "{parent.height - 3}")
            :setScrollBarColor(accent or palette.lightGray)

        for i, line in ipairs(lines) do
            scroll:addLabel()
                :setText(line)
                :setForeground(palette.white)
                :setPosition(1, i)
        end

        local hint = main:addLabel()
            :setText("Up/Down or scroll wheel -- q or Enter to quit")
            :setForeground(accent or palette.lightGray)
            :setPosition(2, "{parent.height - 1}")

        local function onKey(_, key)
            if key == keys.q or key == keys.enter or key == keys.numPadEnter then
                basalt.stop()
            elseif key == keys.down then
                scroll:setOffsetY(scroll:getOffsetY() + 1)
            elseif key == keys.up then
                scroll:setOffsetY(math.max(0, scroll:getOffsetY() - 1))
            elseif key == keys.space or key == keys.pageDown then
                scroll:setOffsetY(scroll:getOffsetY() + (select(2, term.getSize())))
            elseif key == keys.pageUp then
                scroll:setOffsetY(math.max(0, scroll:getOffsetY() - (select(2, term.getSize()))))
            end
        end

        main:onKey(onKey)
        scroll:onScroll(function(self, direction)
            self:setOffsetY(math.max(0, self:getOffsetY() + direction))
        end)

        basalt.run()
    end)
    return ran
end

local function showPager(lines)
    local accent = nil
    if themeOk and theme then
        local ok, a = pcall(theme.accent)
        if ok then accent = a end
    end
    if not runBasaltPager(lines, accent) then
        runTextPager(lines, accent)
    end
end

------------------------------------------------------------------

local args = { ... }
local cmd = args[1]

if not cmd then
    showPager(indexLines())
    return
end

if pages[cmd] then
    showPager(pageLines(cmd))
else
    print("No manual page for '" .. cmd .. "'.")
end
