-- /lib/nyxscript.lua : interpreter for the .nyx scripting language
--
-- .nyx is NyxOS's own automation language -- a small mix of shell
-- scripting (running commands, variables) and old-style batch
-- scripting (labels + goto for control flow), designed to be easy to
-- read and write by hand. See docs/NYX_SCRIPTING.md for the full
-- reference and examples.
--
-- This is intentionally NOT the same thing as /lib/nyxapi.lua: nyxapi
-- is a Lua library third-party .lua *programs* call into; .nyx is a
-- standalone scripting language end users write automation scripts in,
-- the same way you'd write a .sh or .bat file.

local nyxscript = {}

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function splitWords(line)
    local words = {}
    for w in line:gmatch("%S+") do
        table.insert(words, w)
    end
    return words
end

-- Expands $NAME and %NAME% references against the script's variables.
local function expand(line, vars)
    line = line:gsub("%%([%w_]+)%%", function(name)
        return vars[name] or ""
    end)
    line = line:gsub("%$([%w_]+)", function(name)
        return vars[name] or ""
    end)
    return line
end

local function compareValues(a, op, b)
    if op == "==" then return a == b end
    if op == "!=" then return a ~= b end
    if op == ">" then return (tonumber(a) or 0) > (tonumber(b) or 0) end
    if op == "<" then return (tonumber(a) or 0) < (tonumber(b) or 0) end
    if op == ">=" then return (tonumber(a) or 0) >= (tonumber(b) or 0) end
    if op == "<=" then return (tonumber(a) or 0) <= (tonumber(b) or 0) end
    return false
end

-- Runs a .nyx script (its raw text). `vars` optionally seeds initial
-- variables (e.g. script arguments as $1, $2, ...). Returns ok, exitCode.
function nyxscript.run(source, vars, depth)
    depth = depth or 0
    if depth > 10 then
        return false, "call depth exceeded (possible infinite 'call' loop)"
    end
    vars = vars or {}

    local rawLines = {}
    for line in (source .. "\n"):gmatch("(.-)\n") do
        table.insert(rawLines, line)
    end

    -- First pass: index label lines ("label NAME" or "NAME:")
    local labels = {}
    for i, line in ipairs(rawLines) do
        local trimmed = trim(line)
        local labelName = trimmed:match("^label%s+([%w_]+)%s*$") or trimmed:match("^([%w_]+):%s*$")
        if labelName then
            labels[labelName] = i
        end
    end

    local i = 1
    while i <= #rawLines do
        local raw = rawLines[i]
        local line = trim(raw)

        if line == "" or line:sub(1, 1) == "#" or line:sub(1, 2) == "::" then
            -- comment / blank line
        elseif line:match("^label%s+([%w_]+)%s*$") or line:match("^[%w_]+:%s*$") then
            -- label declaration, nothing to execute
        else
            line = expand(line, vars)
            local words = splitWords(line)
            local keyword = words[1]

            if keyword == "set" then
                local name = words[2]
                local value = trim(line:match("^set%s+[%w_]+%s+(.*)$") or "")
                if name then vars[name] = value end

            elseif keyword == "echo" then
                print(trim(line:sub(5)))

            elseif keyword == "wait" then
                sleep(tonumber(words[2]) or 1)

            elseif keyword == "exit" then
                return true, tonumber(words[2]) or 0

            elseif keyword == "goto" then
                local target = words[2]
                if labels[target] then
                    i = labels[target]
                else
                    return false, "unknown label: " .. tostring(target)
                end

            elseif keyword == "if" then
                -- if <a> <op> <b> goto <label>
                local a, op, b, gotoKw, target = words[2], words[3], words[4], words[5], words[6]
                if gotoKw == "goto" and compareValues(a, op, b) then
                    if labels[target] then
                        i = labels[target]
                    else
                        return false, "unknown label: " .. tostring(target)
                    end
                end

            elseif keyword == "call" then
                local path = words[2]
                if path and fs.exists(shell.resolve(path)) then
                    local f = fs.open(shell.resolve(path), "r")
                    local sub = f.readAll()
                    f.close()
                    local ok, err = nyxscript.run(sub, {}, depth + 1)
                    if not ok then
                        print("nyx: error in " .. path .. ": " .. tostring(err))
                    end
                else
                    print("nyx: script not found: " .. tostring(path))
                end

            else
                -- Anything else is a NyxOS/CraftOS command line.
                shell.run(line)
            end
        end

        i = i + 1
    end

    return true, 0
end

function nyxscript.runFile(path, args)
    local resolved = shell.resolve(path)
    if not fs.exists(resolved) then
        return false, "File not found: " .. path
    end
    local f = fs.open(resolved, "r")
    local source = f.readAll()
    f.close()

    local vars = {}
    if args then
        for idx, a in ipairs(args) do
            vars[tostring(idx)] = a
        end
    end

    return nyxscript.run(source, vars)
end

return nyxscript
