-- /lib/interpreters.lua : registry of external-language interpreters
--
-- /etc/interpreters.lua = { { name="python", ext="py", program="/lib/interp/python.lua" }, ... }
-- An interpreter program is run with: program <script> [args...]
-- See docs/INTERPRETERS.md for the contract.
local I = {}
local PATH = "/etc/interpreters.lua"

local function load()
    if not fs.exists(PATH) then return {} end
    local f = fs.open(PATH, "r") local s = f.readAll() f.close()
    local t = textutils.unserialize(s)
    return type(t) == "table" and t or {}
end

local function save(t)
    local f = fs.open(PATH, "w") f.write(textutils.serialize(t)) f.close()
end

function I.list() return load() end

local function norm(ext) return tostring(ext):gsub("^%.", ""):lower() end

function I.register(name, ext, program)
    assert(type(name) == "string" and name ~= "", "name required")
    assert(type(program) == "string" and program ~= "", "program required")
    ext = norm(ext)
    local t = load()
    for i = #t, 1, -1 do
        if t[i].name == name or t[i].ext == ext then table.remove(t, i) end
    end
    t[#t + 1] = { name = name, ext = ext, program = program }
    save(t)
    return true
end

function I.unregister(name)
    local t, n = load(), 0
    for i = #t, 1, -1 do
        if t[i].name == name then table.remove(t, i) n = n + 1 end
    end
    if n > 0 then save(t) end
    return n > 0
end

function I.forExt(ext)
    ext = norm(ext)
    for _, e in ipairs(load()) do if e.ext == ext then return e end end
end

function I.forFile(path)
    local ext = tostring(path):match("%.([%w_]+)$")
    return ext and I.forExt(ext) or nil
end

-- Runs a script with the interpreter matching its extension.
-- Returns ok, err.
function I.run(path, ...)
    local entry = I.forFile(path)
    if not entry then
        return false, "no interpreter for " .. tostring(path):match("%.[%w_]+$") or "this file"
    end
    if not fs.exists(entry.program) then
        return false, entry.name .. " is registered but " .. entry.program .. " is missing"
    end
    if not fs.exists(path) then return false, "no such file: " .. path end
    local sh = I.shell or shell
    local ok = sh.run(entry.program, path, ...)
    return ok and true or false, (not ok) and (entry.name .. " failed") or nil
end

return I
