-- /bin/lang.lua : language packs
--   lang                 shows the current language and the installed packs
--   lang set <code>      switches the language (applies to new windows / next boot)
local i18n = dofile("/lib/i18n.lua")
local nyxlib = dofile("/lib/nyxlib.lua")
local args = { ... }

if args[1] == "set" and args[2] then
    local found = false
    for _, p in ipairs(i18n.list()) do
        if p.code == args[2] then found = true end
    end
    if not found then
        printError("lang: no language pack '" .. args[2] .. "' (see: lang)")
        return
    end
    local cfg = nyxlib.loadTable("/etc/nyx-config.lua")
    cfg.lang = args[2]
    nyxlib.saveTable("/etc/nyx-config.lua", cfg)
    i18n.use(args[2])
    print(i18n.t("Language set. Restart the desktop to apply it everywhere."))
    return
end

print("Language: " .. i18n.current())
for _, p in ipairs(i18n.list()) do
    print(string.format("  %-6s %s%s", p.code, p.name, p.code == i18n.current() and "  *" or ""))
end
print("Usage: lang set <code>")
