-- control.lua : metadonnees du paquet, a cote de install.lua.
-- Facultatif, mais recommande : c'est l'equivalent du fichier "control"
-- d'un paquet .deb Debian. apt.lua le lit automatiquement s'il est
-- present (voir docs/PACKAGING.md).

return {
    name = "hello",
    version = "1.0.0",
    description = "Ajoute la commande 'hello' qui affiche un message.",
    depends = {}, -- noms d'autres paquets NyxOS requis (informatif pour l'instant)
}
