-- /startup.lua : demarrage de NyxOS (execute a chaque boot)

shell.setPath(shell.path() .. ":/bin")

-- Redirige l'affichage vers un ecran (moniteur) branche, si un est trouve,
-- peu importe le cote ou le nom reseau (detection automatique de la
-- position), et adapte l'echelle de texte selon Advanced Monitor (couleur)
-- ou Monitor standard. Si aucun ecran n'est detecte, NyxOS continue
-- normalement sur l'ecran natif de l'ordinateur.
local displayOk, nyxdisplay = pcall(dofile, "/lib/display.lua")
if displayOk and nyxdisplay then
    pcall(nyxdisplay.setup, true)
end

-- Enregistre l'heure de demarrage pour la commande "uptime"
if not fs.exists("/var/run") then
    fs.makeDir("/var/run")
end
local bootFile = fs.open("/var/run/boot.time", "w")
bootFile.write(tostring(os.epoch("utc")))
bootFile.close()

-- Menu de demarrage + connexion (facon CloverOS). Tout est fait dans
-- /lib/login.lua avec Basalt et un repli texte automatique : si quoi que
-- ce soit echoue ici, l'ordinateur continue quand meme vers le shell
-- plutot que de rester bloque.
local mode = "boot"
local loginOk, nyxlogin = pcall(dofile, "/lib/login.lua")
if loginOk and nyxlogin then
    local menuOk, menuChoice = pcall(nyxlogin.bootMenu)
    if menuOk and menuChoice then
        mode = menuChoice
    end

    if mode == "recovery" then
        term.setBackgroundColor((colors or colours).black)
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Shell de secours NyxOS (aucune connexion) ===")
    else
        local authOk, username = pcall(nyxlogin.authenticate)
        if authOk and username then
            local nyxlib = dofile("/lib/nyxlib.lua")
            nyxlib.saveSession(username)
            local user = dofile("/lib/users.lua").find(username)
            if user and user.home and fs.exists(user.home) then
                pcall(shell.setDir, user.home)
            end
        end
    end
end

if fs.exists("/etc/motd") then
    local f = fs.open("/etc/motd", "r")
    print(f.readAll())
    f.close()
end

-- Lancer le shell graphique avec Basalt (repli texte si indisponible)
local shelluiOk, shellui = pcall(dofile, "/lib/shellui.lua")
if shelluiOk and shellui then
    local runOk, success = pcall(shellui.run)
    if not runOk or success == false then
        shellui.runTextFallback()
    end
else
    shell.run("/bin/shell")
end
