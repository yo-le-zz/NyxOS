-- webinstall.lua : installeur web de NyxOS
-- Usage : wget https://raw.githubusercontent.com/yo-le-zz/NyxOS/main/webinstall.lua webinstall.lua && webinstall
--
-- Telecharge install.lua et le dossier data/ depuis GitHub, puis lance
-- l'installation ou la mise a jour si NyxOS est deja present.

local VERSION = "1.0.0"
local REPO_BASE = "https://raw.githubusercontent.com/yo-le-zz/NyxOS/main/NyxOS"
local palette = colors or colours

-- Liste des fichiers a telecharger (relatifs a NyxOS/)
local FILES = {
    "install.lua",
    "data/startup.lua",
    "data/etc/motd",
    "data/etc/apt/installed.lua",
    "data/lib/basalt.lua",
    "data/lib/crypto.lua",
    "data/lib/display.lua",
    "data/lib/login.lua",
    "data/lib/nyxlib.lua",
    "data/lib/shellui.lua",
    "data/lib/theme.lua",
    "data/lib/users.lua",
    "data/bin/adduser.lua",
    "data/bin/apt.lua",
    "data/bin/cat.lua",
    "data/bin/date.lua",
    "data/bin/deluser.lua",
    "data/bin/df.lua",
    "data/bin/diagbasalt.lua",
    "data/bin/display.lua",
    "data/bin/echo.lua",
    "data/bin/encrypt.lua",
    "data/bin/find.lua",
    "data/bin/grep.lua",
    "data/bin/head.lua",
    "data/bin/hostname.lua",
    "data/bin/man.lua",
    "data/bin/neofetch.lua",
    "data/bin/passwd.lua",
    "data/bin/pwd.lua",
    "data/bin/tail.lua",
    "data/bin/testbasalt.lua",
    "data/bin/touch.lua",
    "data/bin/tree.lua",
    "data/bin/uname.lua",
    "data/bin/uninstall.lua",
    "data/bin/uptime.lua",
    "data/bin/users.lua",
    "data/bin/wc.lua",
    "data/bin/whoami.lua",
}

local function isInstalled()
    return fs.exists("/etc/nyx-release") or fs.exists("/startup.lua")
end

local function ensureDir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

local function download(url)
    local response = http.get(url, {
        ["User-Agent"] = "NyxOS-WebInstall/" .. VERSION,
    })
    if not response then
        return nil, "HTTP indisponible (verifie http_enable=true dans config)"
    end
    local code = response.getResponseCode and response.getResponseCode() or 200
    if code < 200 or code >= 300 then
        response.close()
        return nil, "HTTP " .. tostring(code) .. " pour " .. url
    end
    local body = response.readAll()
    response.close()
    if not body or body == "" then
        return nil, "Reponse vide pour " .. url
    end
    return body
end

local function downloadFile(relPath, destPath)
    local url = REPO_BASE .. "/" .. relPath:gsub(" ", "%%20")
    local body, err = download(url)
    if not body then
        return false, err
    end
    ensureDir(fs.getDir(destPath))
    if fs.exists(destPath) then
        fs.delete(destPath)
    end
    local f = fs.open(destPath, "w")
    f.write(body)
    f.close()
    return true
end

local function main()
    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)

    if not http then
        print("Erreur : HTTP non disponible.")
        print("Active http_enable=true dans la config CC: Tweaked.")
        return
    end

    local updateMode = isInstalled()
    if updateMode then
        print("=== Mise a jour NyxOS via le web ===")
        print("NyxOS est deja installe. Telechargement de la version " .. VERSION .. "...")
    else
        print("=== Installation NyxOS via le web ===")
        print("Telechargement de la version " .. VERSION .. "...")
    end
    print("")

    local okCount = 0
    local failCount = 0
    for _, relPath in ipairs(FILES) do
        local destPath = relPath
        write("  " .. relPath .. " ... ")
        local ok, err = downloadFile(relPath, destPath)
        if ok then
            print("OK")
            okCount = okCount + 1
        else
            print("ECHEC")
            print("    " .. tostring(err))
            failCount = failCount + 1
        end
    end

    print("")
    if failCount > 0 then
        print("Telechargement partiel : " .. okCount .. " OK, " .. failCount .. " echec(s).")
        print("Verifie ta connexion et relance webinstall.")
        return
    end

    print("Telechargement termine (" .. okCount .. " fichiers).")
    print("")
    if updateMode then
        print("Lancement de la mise a jour...")
    else
        print("Lancement de l'installation...")
    end
    print("")

    shell.run("install")
end

main()
