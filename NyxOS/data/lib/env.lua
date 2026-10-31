-- /lib/env.lua : environment variables
--
--   local env = dofile("/lib/env.lua")
--   env.get("HOME")   env.set("NAME", "value")   env.unset("NAME")
--   env.list()        env.expand("echo $HOME ${USER} ~/x")
--   env.persist("NAME", "value" [, true])   -- ~/.profile (true = /etc/environment)
--
-- Variables live in _G.NYX_ENV (shared by every program of the session).
-- They are loaded from /etc/environment and ~/.profile (lines "NAME=value"
-- or "export NAME=value", "#" comments) the first time they are used, and
-- built-ins (HOME, USER, HOSTNAME, PWD, PATH, LANG, SHELL) are refreshed
-- on every read. A "\$" in a command stays a literal "$".

local env = {}

local GLOBAL_FILE = "/etc/environment"

local function trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end

local function session()
    local okN, nyxlib = pcall(dofile, "/lib/nyxlib.lua")
    if not okN then return nil, "/home" end
    local okS, s = pcall(nyxlib.loadSession)
    local name = okS and type(s) == "table" and s.username or nil
    if not name then return nil, "/home" end
    local okU, users = pcall(dofile, "/lib/users.lua")
    local user = okU and users.find and users.find(name)
    return name, (user and user.home) or ("/home/" .. name)
end

local function store()
    if type(_G.NYX_ENV) ~= "table" then _G.NYX_ENV = { vars = {}, loaded = false } end
    return _G.NYX_ENV
end

local function parseFile(path, into)
    if not fs.exists(path) or fs.isDir(path) then return end
    local f = fs.open(path, "r")
    if not f then return end
    for line in (f.readAll() or ""):gmatch("[^\r\n]+") do
        line = trim(line)
        if line ~= "" and line:sub(1, 1) ~= "#" then
            line = line:gsub("^export%s+", "")
            local k, v = line:match("^([%a_][%w_]*)%s*=%s*(.*)$")
            if k then
                v = trim(v)
                if #v >= 2 and ((v:sub(1, 1) == '"' and v:sub(-1) == '"') or (v:sub(1, 1) == "'" and v:sub(-1) == "'")) then
                    v = v:sub(2, -2)
                end
                into[k] = v
            end
        end
    end
    f.close()
end

local function builtins()
    local user, home = session()
    local out = { HOME = home, USER = user or "guest", LOGNAME = user or "guest", SHELL = "/bin/shell" }
    pcall(function() out.HOSTNAME = dofile("/lib/nyxlib.lua").getHostname() end)
    pcall(function() out.PWD = "/" .. shell.dir() end)
    pcall(function() out.PATH = shell.path() end)
    pcall(function()
        local cfg = dofile("/lib/nyxlib.lua").loadTable("/etc/nyx-config.lua")
        out.LANG = cfg.lang or "en"
    end)
    return out, home
end

-- (Re)loads /etc/environment and ~/.profile (session values are kept)
function env.load()
    local st = store()
    local b, home = builtins()
    local fresh = {}
    parseFile(GLOBAL_FILE, fresh)
    parseFile(home .. "/.profile", fresh)
    for k, v in pairs(fresh) do
        if st.vars[k] == nil or not st.loaded then st.vars[k] = v end
    end
    st.loaded = true
    return st.vars
end

local function ensure()
    local st = store()
    if not st.loaded then env.load() end
    return st
end

function env.get(name)
    local st = ensure()
    if st.vars[name] ~= nil then return st.vars[name] end
    local b = builtins()
    return b[name]
end

function env.set(name, value)
    if not tostring(name):match("^[%a_][%w_]*$") then return false, "invalid name" end
    ensure().vars[name] = tostring(value)
    return true
end

function env.unset(name)
    ensure().vars[name] = nil
    store().removed = store().removed or {}
    store().removed[name] = true
end

-- all variables, built-ins included, sorted by name
function env.list()
    local st = ensure()
    local b = builtins()
    local all = {}
    for k, v in pairs(b) do all[k] = v end
    for k, v in pairs(st.vars) do all[k] = v end
    local names = {}
    for k in pairs(all) do names[#names + 1] = k end
    table.sort(names)
    local out = {}
    for _, k in ipairs(names) do out[#out + 1] = { k, all[k] } end
    return out
end

-- Rewrites file lines: sets (value) or removes (nil) NAME
local function editFile(path, name, value)
    local lines, found = {}, false
    if fs.exists(path) and not fs.isDir(path) then
        local f = fs.open(path, "r")
        for line in (f.readAll() or ""):gmatch("[^\r\n]+") do
            local k = line:gsub("^%s*export%s+", ""):match("^%s*([%a_][%w_]*)%s*=")
            if k == name then
                found = true
                if value ~= nil then lines[#lines + 1] = "export " .. name .. "=" .. value end
            else
                lines[#lines + 1] = line
            end
        end
        f.close()
    end
    if not found and value ~= nil then lines[#lines + 1] = "export " .. name .. "=" .. value end
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
    local f, err = fs.open(path, "w")
    if not f then return false, tostring(err or "cannot write " .. path) end
    f.write(table.concat(lines, "\n") .. "\n")
    f.close()
    return true
end

-- Saves NAME=value in ~/.profile (or /etc/environment when `global`);
-- value = nil removes it.
function env.persist(name, value, global)
    local _, home = session()
    return editFile(global and GLOBAL_FILE or (home .. "/.profile"), name, value)
end

-- Replaces $NAME, ${NAME} and a leading "~" (HOME); "\$" stays "$".
function env.expand(text)
    text = tostring(text or "")
    if not text:find("[$~]") then return text end
    text = text:gsub("\\%$", "\1")
    text = text:gsub("%${([%a_][%w_]*)}", function(n) return env.get(n) or "" end)
    text = text:gsub("%$([%a_][%w_]*)", function(n) return env.get(n) or "" end)
    text = text:gsub("(%s)~(/)", function(a, b) return a .. (env.get("HOME") or "~") .. b end)
    text = text:gsub("(%s)~(%s)", function(a, b) return a .. (env.get("HOME") or "~") .. b end)
    text = text:gsub("(%s)~$", function(a) return a .. (env.get("HOME") or "~") end)
    text = text:gsub("^~/", (env.get("HOME") or "~"):gsub("%%", "%%%%") .. "/")
    text = text:gsub("\1", "$")
    return text
end

return env
