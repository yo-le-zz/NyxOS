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

-- Keeps only the last `maxLines` lines of a terminal text. A text box that
-- keeps growing makes every redraw slower until the UI seems to ignore
-- new commands.
function capture.trim(text, maxLines)
    maxLines = maxLines or 300
    local count = 0
    for _ in text:gmatch("\n") do count = count + 1 end
    if count <= maxLines then return text end
    local drop = count - maxLines
    local pos = 1
    for _ = 1, drop do
        pos = text:find("\n", pos, true) + 1
    end
    return text:sub(pos)
end

-- True for the commands a text-box terminal handles itself.
function capture.isClear(cmd)
    cmd = (cmd or ""):match("^%s*(.-)%s*$")
    return cmd == "clear" or cmd == "cls"
end

function capture.isExit(cmd)
    return (cmd or ""):match("^%s*(.-)%s*$") == "exit"
end

-- capture.run(cmd [, ui]) -> output (string), err (string or nil)
--   output : everything the command printed, one "\n" per line
--   err    : set only if the command itself raised an error (a program
--            that merely fails and prints its own message is not an error
--            here -- that message is in `output`).
--   ui     : optional { prompt = function(textSoFar, maskChar) -> string }.
--            When a program asks for input (read(): a sudo password, an
--            "apt remove? (y/n)", ...) the command is paused and ui.prompt
--            is called with what has been printed so far; its return value
--            is what the program reads. Without `ui`, read() returns "".
--
-- The command runs in its own coroutine driven from here, with the
-- terminal redirected to the hidden window ONLY while it runs: between
-- two events the real terminal is back, so a Basalt UI that keeps
-- drawing while a long command waits is not painted into the buffer.
-- Call this from a coroutine that may yield (basalt.schedule(...)).
function capture.run(cmd, ui)
    local parent = term.current()
    local width = parent.getSize()

    local okWin, win = pcall(window.create, parent, 1, 1, width, MAX_LINES, false)
    if not okWin or not win or type(win.getLine) ~= "function" then
        -- Very old CC:Tweaked without window.getLine: run the command on
        -- the real terminal instead of losing it.
        local ok, err = pcall(shell.run, cmd)
        return "", (not ok) and tostring(err) or nil
    end

    local function snapshot()
        local _, cursorY = win.getCursorPos()
        return table.concat(readLines(win, math.min(MAX_LINES, cursorY)), "\n")
    end

    local PROMPT = {}
    local co
    local realRead = _G.read
    -- Replacement for the global read(): only for the command's own
    -- coroutine -- background jobs keep using the real one.
    _G.read = function(replaceChar, ...)
        if coroutine.running() == co then
            return coroutine.yield(PROMPT, replaceChar)
        end
        return realRead(replaceChar, ...)
    end

    co = coroutine.create(function() return shell.run(cmd) end)

    local ok, result = true, nil
    local filter = nil
    local event = {}
    local done = false
    while not done do
        local previous = term.redirect(win)
        local resumed, a, b = coroutine.resume(co, (table.unpack or unpack)(event))
        term.redirect(previous)

        if not resumed then
            ok, result = false, a
            done = true
        elseif coroutine.status(co) == "dead" then
            ok, result = true, a
            done = true
        elseif a == PROMPT then
            local text = ""
            if ui and ui.prompt then
                local pok, answer = pcall(ui.prompt, snapshot(), b)
                if not pok then
                    pcall(function() dofile("/lib/logger.lua").error("capture", "prompt failed: " .. tostring(answer)) end)
                    ok, result = false, "prompt failed: " .. tostring(answer)
                    done = true
                end
                text = pok and tostring(answer or "") or ""
            end
            -- the typed answer is part of what the command printed
            local previous2 = term.redirect(win)
            print(b and string.rep(b, #text) or text)
            term.redirect(previous2)
            event = { text }
            filter = nil
        else
            filter = a
            repeat
                event = { os.pullEventRaw() }
            until filter == nil or event[1] == filter or event[1] == "terminate"
            if event[1] == "terminate" then
                ok, result = false, "Terminated"
                done = true
            end
        end
    end
    _G.read = realRead

    local text = snapshot()
    if not ok then
        return text, tostring(result)
    end
    if result == false and text == "" then
        return "", "command failed: " .. tostring(cmd)
    end
    return text, nil
end

return capture
