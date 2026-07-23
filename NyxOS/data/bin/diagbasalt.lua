-- /bin/diagbasalt.lua : diagnostic détaillé de Basalt

print("=== DIAGNOSTIC BASALT ===")
print("")

-- Test 1: Vérification du fichier
print("1. Verification du fichier basalt.lua :")
if fs.exists("/lib/basalt.lua") then
    local size = fs.getSize("/lib/basalt.lua")
    print("   Fichier existe : OUI")
    print("   Taille : " .. size .. " bytes")
    if size > 300000 then
        print("   Taille : CORRECTE")
    else
        print("   Taille : ANORMALE (devrait > 300KB)")
    end
else
    print("   Fichier existe : NON")
    print("   Verification dans data/lib :")
    if fs.exists("data/lib/basalt.lua") then
        print("   Trouve dans data/lib/basalt.lua")
        local size = fs.getSize("data/lib/basalt.lua")
        print("   Taille : " .. size .. " bytes")
    else
        print("   PAS TROUVE dans data/lib")
    end
end
print("")

-- Test 2: Lecture des premières et dernières lignes
print("2. Lecture des lignes :")
local testPath = "/lib/basalt.lua"
if not fs.exists(testPath) then
    testPath = "data/lib/basalt.lua"
end
if fs.exists(testPath) then
    local f = fs.open(testPath, "r")
    if f then
        local line1 = f.readLine()
        local line2 = f.readLine()
        f.close()
        print("   Ligne 1 : " .. (line1 or "NIL"))
        print("   Ligne 2 : " .. (line2 or "NIL"))
        
        -- Lire la dernière ligne
        local f2 = fs.open(testPath, "r")
        local lastLine = ""
        for line in f2.readLine do
            lastLine = line
        end
        f2.close()
        print("   Derniere ligne : " .. (lastLine or "NIL"))
    else
        print("   ERREUR: Impossible d'ouvrir le fichier")
    end
end
print("")

-- Test 3: Tentative de chargement avec debug
print("3. Tentative de chargement :")
local function loadBasalt(path)
    print("   Essai : " .. path)
    local f = fs.open(path, "r")
    if not f then
        print("   ERREUR: Impossible d'ouvrir")
        return false, "open failed"
    end
    
    local content = f.readAll()
    f.close()
    
    print("   Taille lue : " .. #content .. " bytes")
    
    local chunk, err = load(content, path)
    if not chunk then
        print("   ERREUR de compilation : " .. tostring(err))
        return false, err
    end
    
    print("   Compilation OK")
    
    local success, result = pcall(chunk)
    if not success then
        print("   ERREUR d'execution : " .. tostring(result))
        return false, result
    end
    
    print("   Chargement OK")
    print("   Type de retour : " .. type(result))
    return true, result
end

local paths = {"/lib/basalt.lua", "data/lib/basalt.lua"}
local loaded = false
for _, path in ipairs(paths) do
    if fs.exists(path) then
        local ok, result = loadBasalt(path)
        if ok then
            print("   SUCCES avec : " .. path)
            loaded = true
            -- Test si basalt a les méthodes attendues
            if type(result) == "table" then
                print("   Methodes disponibles :")
                for k, v in pairs(result) do
                    print("     - " .. k)
                    if k == "getMainFrame" then
                        print("       -> getMainFrame trouve (OK)")
                    end
                end
            end
            break
        end
    end
end

if not loaded then
    print("   ECHEC: Impossible de charger Basalt")
end
print("")

-- Test 4: Vérification de l'environnement
print("4. Environnement :")
print("   OS : " .. tostring(_OS))
print("   Version CC : " .. tostring(_CC_VERSION or "inconnue"))
print("   Computer ID : " .. os.getComputerID())
print("")

print("=== DIAGNOSTIC TERMINE ===")
