-- /lib/capture.lua : run a shell command and capture what it prints
--
-- Used by the graphical shell (/lib/shellui.lua) and the desktop's
-- terminal app (/lib/desktop.lua), which both show a command's output in
-- a Basalt text box instead of on the real terminal.
--
-- How it works: the command runs with the terminal redirected to an
-- invisible `window` (a complete, real terminal object that keeps a
-- character buffer), then the buffer is read back line by line. This
-- replaces two hand-written fake terminals that
--   * never inserted line breaks (every print() ended up on ONE line),
--   * lacked methods such as isColor(), so many programs crashed, and
--   * restored the terminal with `term.redirect(term.redirect)` (the
--     function itself instead of the previous terminal), which raised
--     "bad argument #1 (table expected, got function)" after EVERY
--     command and killed the whole Basalt interface.
--
-- Limits: a command that waits for keyboard input (read(), a full-screen
-- editor...) cannot be driven from a text box -- run those from the plain
-- shell instead. Output is capped at MAX_LINES lines.

local capture = {}

local MAX_LINES = 400

-- Returns the lines currently held by a window buffer, without the blank
-- tail and without trailing spaces.
local function readLines(win, upTo)
    local lines = {}
    for y = 1, upTo do
        local text = win.getLine(y)
        lines[#lines + 1] = (text or ""):gsub("%s+$", "")
    end
    while #lines > 0 and lines[#lines] == "" do
        lines[#lines] = nil
    end
    return lines
end

-- capture.run(cmd) -> output (string), err (string or nil)
--   output : everything the command printed, one "\n" per line
--   err    : set only if the command itself raised an error (a program
--            that merely fails and prints its own message is not an error
--            here -- that message is in `output`).
function capture.run(cmd)
    local parent = term.current()
    local width = parent.getSize()

    local okWin, win = pcall(window.create, parent, 1, 1, width, MAX_LINES, false)
    if not okWin or not win or type(win.getLine) ~= "function" then
        -- Very old CC:Tweaked without window.getLine: run the command on
        -- the real terminal instead of losing it.
        local ok, err = pcall(shell.run, cmd)
        return "", (not ok) and tostring(err) or nil
    end

    local previous = term.redirect(win)
    local ok, result = pcall(shell.run, cmd)
    local _, cursorY = win.getCursorPos()
    term.redirect(previous)

    local lines = readLines(win, math.min(MAX_LINES, cursorY))
    local text = table.concat(lines, "\n")

    if not ok then
        return text, tostring(result)
    end
    if result == false and text == "" then
        return "", "command failed: " .. tostring(cmd)
    end
    return text, nil
end

return capture
