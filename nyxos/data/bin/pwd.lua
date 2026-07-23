-- /bin/pwd.lua : affiche le dossier courant

print("/" .. fs.combine("", shell.dir()))
