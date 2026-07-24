-- /bin/apt.lua : NyxOS package manager
--
-- Usage:
--   apt install <name> [client|server]   install a NyxApps package by
--                                         name, fetched directly from
--                                         github.com/yo-le-zz/NyxOS
--   apt install <url|path>               install any install.lua
--   apt install ./disk                   install from a local folder
--   apt update [name]                    check installed packages
--                                         against the registry, reinstall
--                                         anything with a newer version
--   apt remove <package> [--yes]         delete files, keep /etc
--   apt purge <package> [--yes]          delete everything, incl. /etc
--   apt list                             list installed packages
--   apt info <package>                   details about an installed pkg
--   apt search <term>                    search the NyxApps registry
--   apt tool install <name> [url]        install a shared/global library
--   apt tool list                        list installed shared libraries
--   apt tool remove <name>               remove a shared library
--
-- Packages follow the app.json standard:
--   { name, version, description, author,
--     type = {"client"} | {"server"} | {"client","server"},
--     client = { entry, installer, uninstaller },
--     server = { entry, installer, uninstaller } }
-- `entry` is the script the app is launched with once installed (used
-- for metadata/info only); `installer`/`uninstaller` are paths (relative
-- to the package folder) to that variant's install.lua/uninstall.lua.
--
-- apt still supports the original "generic installer" style (a bare
-- install.lua, optionally alongside a control.lua) for URLs/paths that
-- aren't part of the NyxApps registry -- see docs/PACKAGING.md.

local nyxlib = dofile("/lib/nyxlib.lua")
local logger = dofile("/lib/logger.lua")
local toolkit = dofile("/lib/toolkit.lua")

local GITHUB_OWNER = "yo-le-zz"
local GITHUB_REPO = "NyxOS"
local GITHUB_BRANCH = "main"
local API_HEADERS = { ["User-Agent"] = "NyxOS-apt" }

local REGISTRY_CACHE_PATH = "/var/apt/registry-cache.lua"
local TREE_CACHE_PATH = "/var/apt/tree-cache.lua"
local CACHE_TTL_MS = 60 * 60 * 1000 -- 1 hour

local args = {...}
local cmd = args[1]

local function usage()
    print("Usage:")
    print("  apt install <name> [client|server]")
    print("  apt install <url|path>")
    print("  apt update [name]")
    print("  apt remove <package>")
    print("  apt purge <package>")
    print("  apt list")
    print("  apt info <package>")
    print("  apt search <term>")
    print("  apt tool install|list|remove <name>")
end

local function normalize(path)
    return "/" .. fs.combine("", path)
end

------------------------------------------------------------------
-- fs tracking (unchanged from the original apt: figure out exactly
-- what an installer touched on disk so remove/purge can undo it).
------------------------------------------------------------------
local function withTrackedFs(fn)
    local written = {}
    local dirs = {}

    local orig = {
        open = fs.open, copy = fs.copy, move = fs.move,
        delete = fs.delete, makeDir = fs.makeDir,
    }

    fs.open = function(path, mode)
        local handle = orig.open(path, mode)
        if handle and (mode == "w" or mode == "a" or mode == "wb" or mode == "ab") then
            written[normalize(path)] = true
        end
        return handle
    end
    fs.copy = function(src, dst)
        orig.copy(src, dst)
        written[normalize(dst)] = true
    end
    fs.move = function(src, dst)
        orig.move(src, dst)
        written[normalize(dst)] = true
        written[normalize(src)] = nil
        dirs[normalize(src)] = nil
    end
    fs.delete = function(path)
        orig.delete(path)
        written[normalize(path)] = nil
        dirs[normalize(path)] = nil
    end
    fs.makeDir = function(path)
        orig.makeDir(path)
        dirs[normalize(path)] = true
    end

    local ok, err = pcall(fn)

    fs.open, fs.copy, fs.move, fs.delete, fs.makeDir =
        orig.open, orig.copy, orig.move, orig.delete, orig.makeDir

    local files, dirList = {}, {}
    for p in pairs(written) do table.insert(files, p) end
    for p in pairs(dirs) do table.insert(dirList, p) end
    return ok, err, files, dirList
end

-- A file written directly at the root ("/") is treated as an executable
-- command and automatically relocated into /bin
local function relocateFiles(files)
    local final = {}
    for _, path in ipairs(files) do
        local dir = fs.getDir(path)
        local name = fs.getName(path)
        if dir == "" or dir == "/" or dir == "." then
            local dest = "/bin/" .. name
            if path ~= dest then
                if fs.exists(dest) then fs.delete(dest) end
                fs.move(path, dest)
            end
            table.insert(final, dest)
        else
            table.insert(final, path)
        end
    end
    return final
end

------------------------------------------------------------------
-- GitHub-backed NyxApps registry
------------------------------------------------------------------
local function ghApiUrl(path)
    return "https://api.github.com/repos/" .. GITHUB_OWNER .. "/" .. GITHUB_REPO .. "/" .. path
end

local function ghRawUrl(path)
    return "https://raw.githubusercontent.com/" .. GITHUB_OWNER .. "/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH .. "/" .. path
end

local function httpGetJson(url)
    if not http then
        return nil, "The http API is not enabled on this computer."
    end
    local response, err = http.get(url, API_HEADERS)
    if not response then
        return nil, tostring(err)
    end
    local body = response.readAll()
    response.close()
    local ok, data = pcall(textutils.unserialiseJSON or textutils.unserializeJSON, body)
    if not ok or data == nil then
        return nil, "Could not parse JSON from " .. url
    end
    return data
end

local function loadCache(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialize, content)
    if ok and type(data) == "table" and data.at and (os.epoch("utc") - data.at) < CACHE_TTL_MS then
        return data.value
    end
    return nil
end

local function saveCache(path, value)
    if not fs.exists("/var/apt") then fs.makeDir("/var/apt") end
    local f = fs.open(path, "w")
    f.write(textutils.serialize({ at = os.epoch("utc"), value = value }))
    f.close()
end

-- Lists the folders under NyxApps/ in the repo (cached).
local function listNyxAppsFolders()
    local cached = loadCache(REGISTRY_CACHE_PATH)
    if cached then return cached end

    local entries, err = httpGetJson(ghApiUrl("contents/NyxApps"))
    if not entries then
        return nil, err
    end
    local folders = {}
    for _, entry in ipairs(entries) do
        if entry.type == "dir" then
            table.insert(folders, entry.name)
        end
    end
    saveCache(REGISTRY_CACHE_PATH, folders)
    return folders
end

-- Fetches and parses NyxApps/<folder>/app.json
local function fetchAppJson(folder)
    local body, err = (function()
        if not http then return nil, "The http API is not enabled on this computer." end
        local response, e = http.get(ghRawUrl("NyxApps/" .. folder .. "/app.json"), API_HEADERS)
        if not response then return nil, tostring(e) end
        local b = response.readAll()
        response.close()
        return b
    end)()
    if not body then return nil, err end
    local ok, data = pcall(textutils.unserialiseJSON or textutils.unserializeJSON, body)
    if not ok or type(data) ~= "table" then
        return nil, "Invalid app.json for " .. folder
    end
    data._folder = folder
    return data
end

-- Finds a NyxApps package by name (case-insensitive match against
-- app.json's "name" field, falling back to the folder name).
local function findPackageByName(name)
    local folders, err = listNyxAppsFolders()
    if not folders then
        return nil, err
    end
    local lowerName = name:lower()
    for _, folder in ipairs(folders) do
        if folder:lower() == lowerName then
            local app, aerr = fetchAppJson(folder)
            if app then return app end
        end
    end
    for _, folder in ipairs(folders) do
        local app = fetchAppJson(folder)
        if app and app.name and app.name:lower() == lowerName then
            return app
        end
    end
    return nil, "No package named '" .. name .. "' found in the NyxApps registry."
end

-- Downloads NyxApps/<folder>/<variant>/... plus app.json into a local
-- tmp folder, using the repo's recursive git tree (cached) to know
-- every file under that variant.
local function downloadVariant(app, variant, destDir)
    local tree = loadCache(TREE_CACHE_PATH)
    if not tree then
        local data, err = httpGetJson(ghApiUrl("git/trees/" .. GITHUB_BRANCH .. "?recursive=1"))
        if not data or not data.tree then
            return false, err or "Could not read the repository's file tree."
        end
        tree = data.tree
        saveCache(TREE_CACHE_PATH, tree)
    end

    local prefix = "NyxApps/" .. app._folder .. "/" .. variant .. "/"
    local found = 0
    for _, entry in ipairs(tree) do
        if entry.type == "blob" and entry.path:sub(1, #prefix) == prefix then
            local relative = entry.path:sub(#("NyxApps/" .. app._folder .. "/") + 1)
            local destPath = fs.combine(destDir, relative)
            local ok, err = (function()
                if not http then return false, "The http API is not enabled on this computer." end
                local response, e = http.get(ghRawUrl(entry.path), API_HEADERS)
                if not response then return false, tostring(e) end
                local body = response.readAll()
                response.close()
                local dir = fs.getDir(destPath)
                if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
                local f = fs.open(destPath, "w")
                f.write(body)
                f.close()
                return true
            end)()
            if ok then
                found = found + 1
            else
                return false, err
            end
        end
    end

    if found == 0 then
        return false, "No files found under " .. prefix .. " (check the app.json paths)."
    end
    return true
end

------------------------------------------------------------------
-- control.lua support (legacy / generic packages)
------------------------------------------------------------------
local function loadControl(runPath)
    local dir = fs.getDir(runPath)
    local controlPath = fs.combine(dir, "control.lua")
    if fs.exists(controlPath) then
        local ok, data = pcall(dofile, controlPath)
        if ok and type(data) == "table" then
            return data
        end
    end
    return nil
end

local function fetchRemoteControl(installUrl)
    if not http then return nil end
    local controlUrl = installUrl:gsub("install%.lua$", "control.lua")
    if controlUrl == installUrl then return nil end
    local response = http.get(controlUrl)
    if not response then return nil end
    local body = response.readAll()
    response.close()
    local fn, err = load(body, "control")
    if not fn then return nil end
    local ok, data = pcall(fn)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

------------------------------------------------------------------
-- Shared install logic: given a runPath (a local install.lua, already
-- on disk) run it with fs tracking and record it into the manifest.
------------------------------------------------------------------
local function runInstaller(pkgName, runPath, meta)
    local ok, err, files, dirs = withTrackedFs(function()
        return shell.run(runPath)
    end)

    if not ok then
        print("Install failed: " .. tostring(err))
        logger.error("apt", pkgName .. " install failed: " .. tostring(err))
        return false
    end

    files = relocateFiles(files)

    local uninstallScript = meta and meta.uninstallScript or nil
    if not uninstallScript then
        for _, f in ipairs(files) do
            if fs.getName(f) == "uninstall.lua" then
                uninstallScript = f
            end
        end
    end

    local manifest = nyxlib.loadManifest()
    manifest[pkgName] = {
        source = (meta and meta.source) or runPath,
        files = files,
        dirs = dirs,
        uninstallScript = uninstallScript,
        installedAt = os.epoch("utc"),
        version = meta and meta.version or nil,
        description = meta and meta.description or nil,
        author = meta and meta.author or nil,
        variant = meta and meta.variant or nil,
        registryFolder = meta and meta.registryFolder or nil,
        depends = meta and meta.depends or nil,
    }
    nyxlib.saveManifest(manifest)

    logger.info("apt", pkgName .. " installed (" .. #files .. " file(s))")
    print("Package '" .. pkgName .. "' installed (" .. #files .. " file(s), " .. #dirs .. " folder(s)):")
    for _, f in ipairs(files) do
        print("  " .. f)
    end
    if uninstallScript then
        print("Dedicated uninstall script found: " .. uninstallScript)
    end
    return true
end

------------------------------------------------------------------
-- apt install
------------------------------------------------------------------
local function cmdInstall(source, variantArg)
    if not source then
        print("Give a package name, URL, or path (e.g. apt install ./disk).")
        return
    end

    -- 1) Looks like a NyxApps registry name: no scheme, no slash, not an
    --    existing local path.
    local looksLikeName = not source:match("^https?://") and not source:find("/")
        and not fs.exists(shell.resolve(source))

    if looksLikeName then
        print("Looking up '" .. source .. "' in the NyxApps registry...")
        local app, err = findPackageByName(source)
        if not app then
            print("apt: " .. tostring(err))
            return
        end

        local types = app.type or {}
        local variant = variantArg
        if not variant then
            if #types == 1 then
                variant = types[1]
            elseif #types > 1 then
                write("This package has multiple variants (" .. table.concat(types, ", ") .. "). Which one? ")
                variant = read()
            end
        end
        if not variant or not app[variant] then
            print("apt: unknown or missing variant. Available: " .. table.concat(types, ", "))
            return
        end

        local variantDef = app[variant]
        local pkgName = app.name .. (#types > 1 and ("-" .. variant) or "")

        print("Downloading " .. app.name .. " v" .. tostring(app.version) .. " (" .. variant .. ") ...")
        local tmpDir = "/var/apt/tmp/" .. pkgName
        if fs.exists(tmpDir) then fs.delete(tmpDir) end
        local ok, derr = downloadVariant(app, variant, tmpDir)
        if not ok then
            print("apt: download failed: " .. tostring(derr))
            return
        end

        local installerPath = fs.combine(tmpDir, (variantDef.installer or (variant .. "/install.lua")):gsub("^" .. variant .. "/", ""))
        if not fs.exists(installerPath) then
            -- installer path in app.json is relative to the package
            -- root (e.g. "client/install.lua") -- try that directly too.
            installerPath = fs.combine(tmpDir, fs.getName(variantDef.installer or "install.lua"))
        end
        if not fs.exists(installerPath) then
            print("apt: installer not found at " .. tostring(variantDef.installer))
            return
        end

        if app.description then print("  " .. app.description) end
        if app.author then print("  by " .. app.author) end

        runInstaller(pkgName, installerPath, {
            source = "nyxapps:" .. app._folder,
            version = app.version,
            description = app.description,
            author = app.author,
            variant = variant,
            registryFolder = app._folder,
        })
        fs.delete(tmpDir)
        return
    end

    -- 2) URL or local path: generic single-file/disk installer (legacy
    --    behaviour, unchanged).
    local pkgName = variantArg
    local runPath
    local tempFile = nil
    local control = nil

    if source:match("^https?://") then
        if not http then
            print("The http API is not enabled on this computer.")
            return
        end
        control = fetchRemoteControl(source)
        pkgName = pkgName or (control and control.name) or
            source:match("([^/]+)%.lua$") or source:match("([^/]+)/?$") or ("package_" .. os.epoch("utc"))
        print("Downloading " .. source .. " ...")
        local response, err = http.get(source)
        if not response then
            print("Download failed: " .. tostring(err))
            return
        end
        local body = response.readAll()
        response.close()

        if not fs.exists("/var/apt/tmp") then fs.makeDir("/var/apt/tmp") end
        tempFile = "/var/apt/tmp/" .. pkgName .. "_install.lua"
        local f = fs.open(tempFile, "w")
        f.write(body)
        f.close()
        runPath = tempFile
    else
        local path = shell.resolve(source)
        if fs.isDir(path) then
            path = fs.combine(path, "install.lua")
        end
        if not fs.exists(path) then
            print("File not found: " .. path)
            return
        end
        control = loadControl(path)
        pkgName = pkgName or (control and control.name) or fs.getName(fs.getDir(path))
        if pkgName == nil or pkgName == "" then
            pkgName = "package_" .. os.epoch("utc")
        end
        runPath = path
    end

    if control then
        print("Installing package '" .. pkgName .. "'" ..
            (control.version and (" v" .. tostring(control.version)) or "") .. "...")
        if control.description then print("  " .. control.description) end
    else
        print("Installing package '" .. pkgName .. "'...")
    end

    runInstaller(pkgName, runPath, {
        source = source,
        version = control and control.version,
        description = control and control.description,
        depends = control and control.depends,
    })

    if tempFile and fs.exists(tempFile) then
        fs.delete(tempFile)
    end
end

------------------------------------------------------------------
-- apt remove / purge
------------------------------------------------------------------
local function cmdRemove(pkgName, mode, skipConfirm)
    if not pkgName then
        print("Give the package name (see 'apt list').")
        return false
    end

    local manifest = nyxlib.loadManifest()
    local entry = manifest[pkgName]
    if not entry then
        print("Unknown package: " .. pkgName)
        return false
    end

    local fullClean = (mode == "purge")

    if entry.uninstallScript and fs.exists(entry.uninstallScript) then
        print("This package provides its own uninstall script:")
        print("  " .. entry.uninstallScript)
        local runIt = skipConfirm
        if not skipConfirm then
            write("Use it for a clean uninstall? (y/n) ")
            runIt = (read() == "y")
        end
        if runIt then
            print("Running " .. entry.uninstallScript .. " ...")
            local ranOk = shell.run(entry.uninstallScript)
            if ranOk then
                print("Uninstall script finished.")
                fullClean = true
            else
                print("The script errored, falling back to manual cleanup...")
            end
        end
    end

    local removed = 0
    local remaining = {}
    for _, path in ipairs(entry.files or {}) do
        local isConfig = path:match("^/etc/") ~= nil
        if fs.exists(path) then
            if fullClean or not isConfig then
                fs.delete(path)
                removed = removed + 1
            else
                table.insert(remaining, path)
            end
        end
    end

    if entry.dirs then
        local sorted = {}
        for _, d in ipairs(entry.dirs) do table.insert(sorted, d) end
        table.sort(sorted, function(a, b) return #a > #b end)
        for _, d in ipairs(sorted) do
            local isConfig = d:match("^/etc/") ~= nil
            if fs.exists(d) and fs.isDir(d) and (fullClean or not isConfig) then
                if #fs.list(d) == 0 then
                    fs.delete(d)
                end
            end
        end
    end

    if fullClean then
        manifest[pkgName] = nil
        print("Package '" .. pkgName .. "' " .. (mode == "purge" and "purged" or "fully removed") ..
            (removed > 0 and (" (" .. removed .. " file(s) deleted)") or "") .. ".")
    else
        entry.files = remaining
        entry.removed = true
        print("Package '" .. pkgName .. "' removed (" .. removed .. " file(s)).")
        if #remaining > 0 then
            print("Config kept in /etc. Use 'apt purge " .. pkgName .. "' to delete everything.")
        end
    end
    nyxlib.saveManifest(manifest)
    logger.info("apt", pkgName .. " " .. mode .. "d")
    return true
end

------------------------------------------------------------------
-- apt list / info / search
------------------------------------------------------------------
local function cmdList()
    local manifest = nyxlib.loadManifest()
    local names = {}
    for name in pairs(manifest) do table.insert(names, name) end
    table.sort(names)
    if #names == 0 then
        print("No packages installed.")
        return
    end
    print(string.format("%-20s %-10s %-8s %s", "NAME", "VERSION", "VARIANT", "STATUS"))
    for _, name in ipairs(names) do
        local entry = manifest[name]
        local status = entry.removed and "removed*" or "installed"
        print(string.format("%-20s %-10s %-8s %s",
            name, tostring(entry.version or "-"), tostring(entry.variant or "-"), status))
    end
end

local function cmdInfo(pkgName)
    if not pkgName then
        print("Give the package name (see 'apt list').")
        return
    end
    local manifest = nyxlib.loadManifest()
    local entry = manifest[pkgName]
    if not entry then
        print("Unknown package: " .. pkgName)
        return
    end
    print("Package     : " .. pkgName)
    if entry.version then print("Version     : " .. tostring(entry.version)) end
    if entry.author then print("Author      : " .. tostring(entry.author)) end
    if entry.variant then print("Variant     : " .. tostring(entry.variant)) end
    if entry.description then print("Description : " .. tostring(entry.description)) end
    if entry.depends then print("Depends     : " .. table.concat(entry.depends, ", ")) end
    print("Source      : " .. tostring(entry.source))
    if entry.installedAt then
        print("Installed   : " .. os.date("%d/%m/%Y %H:%M:%S", math.floor(entry.installedAt / 1000)))
    end
    print("Files       : " .. #(entry.files or {}))
    print("Folders     : " .. #(entry.dirs or {}))
    print("Uninstaller : " .. (entry.uninstallScript or "none"))
    if entry.removed then
        print("Status      : removed (config kept)")
    end
end

local function cmdSearch(term)
    if not term then
        print("Usage: apt search <term>")
        return
    end
    local folders, err = listNyxAppsFolders()
    if not folders then
        print("apt: " .. tostring(err))
        return
    end
    local lowerTerm = term:lower()
    local any = false
    for _, folder in ipairs(folders) do
        if folder:lower():find(lowerTerm, 1, true) then
            local app = fetchAppJson(folder)
            any = true
            if app then
                print(app.name .. " v" .. tostring(app.version) .. " -- " .. tostring(app.description))
            else
                print(folder)
            end
        end
    end
    if not any then
        print("No match for '" .. term .. "'.")
    end
end

------------------------------------------------------------------
-- apt update
------------------------------------------------------------------
local function cmdUpdate(pkgName)
    local manifest = nyxlib.loadManifest()
    local targets = {}
    if pkgName then
        if manifest[pkgName] then table.insert(targets, pkgName) end
    else
        for name, entry in pairs(manifest) do
            if entry.registryFolder then
                table.insert(targets, name)
            end
        end
    end

    if #targets == 0 then
        print("Nothing to update (only NyxApps registry packages support 'apt update').")
        return
    end

    for _, name in ipairs(targets) do
        local entry = manifest[name]
        if not entry.registryFolder then
            print(name .. ": not a registry package, skipping.")
        else
            local app = fetchAppJson(entry.registryFolder)
            if not app then
                print(name .. ": could not check for updates.")
            elseif tostring(app.version) == tostring(entry.version) then
                print(name .. ": up to date (v" .. tostring(entry.version) .. ").")
            else
                print(name .. ": v" .. tostring(entry.version) .. " -> v" .. tostring(app.version) .. ", reinstalling...")
                cmdInstall(app.name, entry.variant)
            end
        end
    end
end

------------------------------------------------------------------
-- apt tool (shared/global libraries)
------------------------------------------------------------------
local function cmdTool(sub, name, url)
    if sub == "install" then
        if not name then print("Usage: apt tool install <name> [url]") return end
        local ok, err = toolkit.install(name, url)
        if ok then
            print("Shared library '" .. name .. "' installed to /lib/tools/" .. name .. ".lua")
            logger.info("apt", "tool installed: " .. name)
        else
            print("apt tool install: " .. tostring(err))
        end
        return
    end
    if sub == "list" then
        local list = toolkit.list()
        if #list == 0 then
            print("No shared libraries installed.")
        end
        for _, n in ipairs(list) do print(n) end
        return
    end
    if sub == "remove" then
        if not name then print("Usage: apt tool remove <name>") return end
        if toolkit.remove(name) then
            print("Shared library '" .. name .. "' removed.")
        else
            print("Not installed: " .. name)
        end
        return
    end
    print("Usage: apt tool install|list|remove <name>")
end

------------------------------------------------------------------

if not cmd then
    usage()
    return
end

if cmd == "install" then
    cmdInstall(args[2], args[3])
elseif cmd == "update" then
    cmdUpdate(args[2])
elseif cmd == "remove" or cmd == "purge" then
    cmdRemove(args[2], cmd, args[3] == "--yes")
elseif cmd == "list" then
    cmdList()
elseif cmd == "info" then
    cmdInfo(args[2])
elseif cmd == "search" then
    cmdSearch(args[2])
elseif cmd == "tool" then
    cmdTool(args[2], args[3], args[4])
else
    usage()
end
