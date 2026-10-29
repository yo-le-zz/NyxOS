-- /lib/i18n.lua : language packs
--
--   local t = dofile("/lib/i18n.lua").t
--   print(t("Delete"))                 --> "Supprimer" in French
--   print(t("Delete %s ?", name))      --> string.format is applied when arguments are given
--
-- The English text is the key. A pack is a file /etc/lang/<code>.lua that
-- returns { _name = "Francais", _code = "fr", ["Delete"] = "Supprimer", ... };
-- strings missing from a pack fall back to English. The active language is
-- `lang` in /etc/nyx-config.lua (set it in Settings > General or with the
-- `lang` command). Other packages can ship their own packs: put
-- /etc/lang/<code>.lua next to the system ones (keys are merged, see
-- i18n.extend).

local i18n = {}

i18n.dir = "/etc/lang"
local active = "en"
local strings = {}
local extra = {}

local function readTable(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local content = f.readAll()
    f.close()
    -- data files are written with textutils.serialize ({...}); packs are
    -- Lua chunks ("return {...}"): accept both
    local ok, data = pcall(textutils.unserialize, content)
    if ok and type(data) == "table" then return data end
    local fn = load(content, path, "t", {})
    if fn then
        local ok2, res = pcall(fn)
        if ok2 and type(res) == "table" then return res end
    end
    return nil
end

function i18n.pack(code, dir)
    return readTable((dir or i18n.dir) .. "/" .. tostring(code) .. ".lua")
end

-- Available packs: { { code = "fr", name = "Francais" }, ... } (English first)
function i18n.list(dir)
    dir = dir or i18n.dir
    local out = { { code = "en", name = "English" } }
    if fs.exists(dir) and fs.isDir(dir) then
        for _, file in ipairs(fs.list(dir)) do
            local code = file:match("^([%w_%-]+)%.lua$")
            if code and code ~= "en" then
                local pack = i18n.pack(code, dir)
                if pack then out[#out + 1] = { code = code, name = pack._name or code } end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.code == "en" then return true end
        if b.code == "en" then return false end
        return a.code < b.code
    end)
    return out
end

-- Selects a language (and optionally the folder holding the packs)
function i18n.use(code, dir)
    if dir then i18n.dir = dir end
    code = code or "en"
    active = code
    strings = (code ~= "en" and i18n.pack(code)) or {}
    for _, add in pairs(extra) do
        for k, v in pairs(add[code] or {}) do strings[k] = v end
    end
    return active
end

-- Reads the language from /etc/nyx-config.lua
function i18n.load()
    local code = "en"
    local cfg = readTable("/etc/nyx-config.lua")
    if cfg and type(cfg.lang) == "string" then code = cfg.lang end
    return i18n.use(code)
end

-- Lets a package add strings: i18n.extend("mypkg", { fr = { ["Hello"] = "Bonjour" } })
function i18n.extend(name, byLang)
    extra[name] = byLang
    i18n.use(active)
end

function i18n.current() return active end

function i18n.t(text, ...)
    local out = strings[text] or text
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, out, ...)
        if ok then return formatted end
    end
    return out
end

i18n.load()
return i18n
