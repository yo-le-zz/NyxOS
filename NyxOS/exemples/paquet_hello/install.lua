-- Exemple de paquet NyxOS : "hello"
-- Peut etre installe via :
--   apt install https://.../paquet_hello/install.lua
--   apt install ./disk        (si ce fichier est a la racine du disque)
--
-- Regle : tout fichier ecrit ici EST automatiquement suivi par apt.
-- S'il est ecrit a la racine ("hello.lua"), apt le deplace dans /bin.
-- S'il est ecrit dans un chemin absolu (ex: "/etc/hello.conf"), apt le
-- laisse la ou il est mais le garde dans le manifeste (utile pour la
-- config, qui est conservee par "apt remove" et effacee par "apt purge").

local bin = fs.open("hello.lua", "w")
bin.write([[
print("Bonjour depuis le paquet 'hello' !")
]])
bin.close()

local conf = fs.open("/etc/hello.conf", "w")
conf.write("message=Bonjour\n")
conf.close()

print("Paquet 'hello' pret a etre enregistre par apt.")
