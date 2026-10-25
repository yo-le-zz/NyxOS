-- /bin/mkpkg.lua : instantly scaffolds a valid, empty NyxOS package
-- (app.json standard) so new NyxApps-style packages are quick to start.
-- Usage: mkpkg <name> [client|server|both]

local args = { ... }
local name = args[1]
local kind = args[2] or "client"

if not name then
    print("Usage: mkpkg <name> [client|server|both]")
    return
end

local root = shell.resolve(name)
if fs.exists(root) then
    print("'" .. name .. "' already exists.")
    return
end

fs.makeDir(root)

local function writeFile(path, content)
    local f = fs.open(path, "w")
    f.write(content)
    f.close()
end

local function scaffoldVariant(variantDir, kindLabel)
    fs.makeDir(variantDir)
    writeFile(fs.combine(variantDir, "install.lua"),
        "-- install.lua : write this package's files.\n" ..
        "-- A file written at the package root becomes a command (moved to /bin).\n" ..
        "local here = fs.getDir(shell.getRunningProgram())\n\n" ..
        "local cmd = fs.open(\"" .. name .. ".lua\", \"w\")\n" ..
        "cmd.write([[\n" ..
        "print(\"Hello from " .. name .. " (" .. kindLabel .. ")!\")\n" ..
        "]])\n" ..
        "cmd.close()\n\n" ..
        "print(\"" .. name .. " installed. Type '" .. name .. "' to run it.\")\n")
    writeFile(fs.combine(variantDir, "uninstall.lua"),
        "-- uninstall.lua : optional cleanup logic, run before the default\n" ..
        "-- apt remove/purge behaviour.\n" ..
        "print(\"" .. name .. " (" .. kindLabel .. ") cleaned up.\")\n")
end

local appType = {}
if kind == "both" then
    scaffoldVariant(fs.combine(root, "client"), "client")
    scaffoldVariant(fs.combine(root, "server"), "server")
    appType = { "client", "server" }
else
    scaffoldVariant(fs.combine(root, kind), kind)
    appType = { kind }
end

local appJson = {
    '{',
    '  "name": "' .. name .. '",',
    '  "version": "0.1.0",',
    '  "description": "",',
    '  "author": "",',
    '  "type": [' .. table.concat((function()
        local q = {}
        for _, t in ipairs(appType) do table.insert(q, '"' .. t .. '"') end
        return q
    end)(), ', ') .. '],',
}
for i, t in ipairs(appType) do
    local comma = (i < #appType) and ',' or ''
    table.insert(appJson, '  "' .. t .. '": {')
    table.insert(appJson, '    "entry": "' .. t .. '/' .. name .. '.lua",')
    table.insert(appJson, '    "installer": "' .. t .. '/install.lua",')
    table.insert(appJson, '    "uninstaller": "' .. t .. '/uninstall.lua"')
    table.insert(appJson, '  }' .. comma)
end
table.insert(appJson, '}')

writeFile(fs.combine(root, "app.json"), table.concat(appJson, "\n"))

print("Package scaffold created at " .. root .. "/")
print("  app.json" .. (kind == "both" and ", client/, server/" or (", " .. kind .. "/")))
print("Edit app.json + install.lua, then test with:")
print("  apt install " .. root)
