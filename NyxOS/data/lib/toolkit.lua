-- /lib/toolkit.lua : global shared libraries ("apt tool install")
--
-- Some libraries (Basalt being the prime example) are big and used by
-- many different packages. Instead of every package bundling its own
-- private copy, `apt tool install <name>` installs the library once
-- into /lib/tools/<name>.lua, and any script can then pull it in with
-- `local basalt = toolkit.require("basalt")` -- a shared/global library,
-- the same idea as system-wide shared objects (.so/.dll) on a regular
-- OS, instead of every app statically linking its own copy.

local toolkit = {}

local TOOLS_DIR = "/lib/tools"
local cache = {}

local function ensureDir()
    if not fs.exists(TOOLS_DIR) then
        fs.makeDir(TOOLS_DIR)
    end
end

function toolkit.path(name)
    return fs.combine(TOOLS_DIR, name .. ".lua")
end

function toolkit.isInstalled(name)
    return fs.exists(toolkit.path(name))
end

function toolkit.list()
    ensureDir()
    local names = {}
    for _, filename in ipairs(fs.list(TOOLS_DIR)) do
        if filename:match("%.lua$") then
            table.insert(names, (filename:gsub("%.lua$", "")))
        end
    end
    table.sort(names)
    return names
end

-- Loads (and caches) a globally installed shared library by name.
-- Returns nil, error if it isn't installed.
function toolkit.require(name)
    if cache[name] then
        return cache[name]
    end
    local path = toolkit.path(name)
    if not fs.exists(path) then
        return nil, "Shared library '" .. name .. "' is not installed. Try: apt tool install " .. name
    end
    local ok, mod = pcall(dofile, path)
    if not ok then
        return nil, tostring(mod)
    end
    cache[name] = mod
    return mod
end

-- Installs a shared library. If `sourcePath` is given, that local file
-- is copied in; otherwise `url` is downloaded. As a convenience, if
-- neither is given and NyxOS already ships /lib/<name>.lua as a system
-- dependency (currently just "basalt"), that copy is reused so
-- `apt tool install basalt` works fully offline.
function toolkit.install(name, sourcePathOrUrl)
    ensureDir()
    local dest = toolkit.path(name)

    if sourcePathOrUrl and sourcePathOrUrl:match("^https?://") then
        local network = dofile("/lib/network.lua")
        local ok, err = network.download(sourcePathOrUrl, dest)
        if not ok then
            return false, err
        end
        cache[name] = nil
        return true
    end

    local source = sourcePathOrUrl
    if not source then
        if fs.exists("/lib/" .. name .. ".lua") then
            source = "/lib/" .. name .. ".lua"
        else
            return false, "No source given and no bundled /lib/" .. name .. ".lua found."
        end
    end

    source = shell and shell.resolve(source) or source
    if not fs.exists(source) then
        return false, "Source not found: " .. source
    end
    fs.copy(source, dest)
    cache[name] = nil
    return true
end

function toolkit.remove(name)
    local path = toolkit.path(name)
    if fs.exists(path) then
        fs.delete(path)
        cache[name] = nil
        return true
    end
    return false
end

return toolkit
