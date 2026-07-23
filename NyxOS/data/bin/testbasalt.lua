-- /bin/testbasalt.lua : script de test pour vérifier Basalt

print("Test de chargement de Basalt...")
print("")

-- Test depuis data/lib (pendant l'installation)
print("1. Test depuis data/lib/basalt.lua :")
local ok1, basalt1 = pcall(dofile, "data/lib/basalt.lua")
if ok1 and basalt1 then
    print("   SUCCES : Basalt charge depuis data/lib")
else
    print("   ECHEC : " .. tostring(basalt1))
end
print("")

-- Test depuis /lib (après installation)
print("2. Test depuis /lib/basalt.lua :")
if fs.exists("/lib/basalt.lua") then
    local ok2, basalt2 = pcall(dofile, "/lib/basalt.lua")
    if ok2 and basalt2 then
        print("   SUCCES : Basalt charge depuis /lib")
    else
        print("   ECHEC : " .. tostring(basalt2))
    end
else
    print("   Fichier introuvable : /lib/basalt.lua")
end
print("")

-- Test avec pcall et dofile direct
print("3. Test avec pcall(dofile, '/lib/basalt.lua') :")
local ok3, basalt3 = pcall(dofile, "/lib/basalt.lua")
if ok3 then
    print("   pcall OK")
    if basalt3 then
        print("   Basalt n'est pas nil")
        if type(basalt3) == "table" then
            print("   Basalt est une table")
        else
            print("   Basalt est de type : " .. type(basalt3))
        end
    else
        print("   Basalt est nil")
    end
else
    print("   pcall ECHEC : " .. tostring(basalt3))
end
print("")

-- Vérification de la taille du fichier
print("4. Verification du fichier :")
if fs.exists("/lib/basalt.lua") then
    local size = fs.getSize("/lib/basalt.lua")
    print("   Taille : " .. size .. " bytes")
    if size > 300000 then
        print("   Taille correcte (> 300KB)")
    else
        print("   Taille anormale (devrait etre > 300KB)")
    end
else
    print("   Fichier introuvable")
end
print("")

print("Test termine.")
