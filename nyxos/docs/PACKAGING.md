# Créer des paquets NyxOS (façon `.deb`)

Ce document explique comment créer un script installable dans NyxOS via
`apt install`, et comment le distribuer sous forme de « disque » (une
disquette/disque dur CC: Tweaked, ou un simple dossier zippé) — un peu
comme on construit un paquet `.deb` pour Debian/Ubuntu.

## 1. Rappel : comment `apt install` fonctionne

`apt install <url|chemin>` exécute **réellement** un fichier `install.lua`
(via `shell.run`, pas juste `dofile`), puis regarde **tout ce que ce
script a touché sur le disque** pendant son exécution :

- `fs.open(chemin, "w"/"a")`
- `fs.copy(src, dst)`
- `fs.move(src, dst)`
- `fs.makeDir(dossier)`

Tout ce qui est écrit est automatiquement enregistré dans le manifeste
`/etc/apt/installed.lua`, ce qui permet ensuite `apt remove`/`apt purge`
de tout retirer proprement — même si ton script ne connaît rien du
système de paquets et se contente d'écrire ses fichiers normalement.

Un fichier écrit **à la racine** (`fs.open("hello.lua", "w")`) est
automatiquement déplacé dans `/bin` : c'est la manière la plus simple de
livrer une nouvelle commande.

## 2. Comparaison avec un paquet `.deb`

Un paquet Debian, une fois décompressé, ressemble à ça :

```
mon-paquet.deb
├── control.tar   -> DEBIAN/control     (nom, version, description, deps)
│                  -> DEBIAN/postinst   (script execute apres install)
│                  -> DEBIAN/prerm      (script execute avant suppression)
└── data.tar      -> /usr/bin/..., /etc/..., etc. (les vrais fichiers)
```

Un paquet NyxOS reprend la même idée, en beaucoup plus simple, avec des
noms de fichiers directement inspirés de ce modèle :

| Rôle Debian                    | Équivalent NyxOS      | Obligatoire ? |
|---------------------------------|------------------------|:---:|
| `DEBIAN/control` (métadonnées)  | `control.lua`          | non |
| `DEBIAN/postinst` (installation)| `install.lua`          | oui |
| `DEBIAN/prerm` (désinstallation)| `uninstall.lua`        | non |
| `data.tar` (fichiers livrés)    | fichiers écrits par `install.lua` (`fs.open`/`fs.copy`) | oui |
| paquet `.deb` lui-même          | un dossier ("disque") ou une URL pointant vers `install.lua` | -- |

## 3. Structure d'un paquet minimal

Le strict minimum est un seul fichier :

```
mon-paquet/
└── install.lua
```

`install.lua` écrit lui-même ses fichiers :

```lua
-- install.lua
local bin = fs.open("hello.lua", "w")   -- ecrit a la racine -> deplace dans /bin
bin.write([[print("Bonjour !")]])
bin.close()

local conf = fs.open("/etc/hello.conf", "w")  -- chemin absolu -> reste sur place
conf.write("message=Bonjour\n")
conf.close()
```

C'est exactement le paquet fourni en exemple dans
`exemples/paquet_hello/`.

## 4. Ajouter des métadonnées : `control.lua`

Comme le fichier `control` d'un `.deb`, `control.lua` est **optionnel**
mais recommandé dès que ton paquet a un nom, une version ou une
description. Place-le à côté de `install.lua` :

```lua
-- control.lua
return {
    name = "hello",
    version = "1.0.0",
    description = "Ajoute la commande 'hello' qui affiche un message.",
    depends = {},  -- noms d'autres paquets NyxOS (informatif)
}
```

`apt` le charge automatiquement :
- si présent, `name` devient le nom du paquet par défaut (plus besoin de
  taper `apt install <url> mon-nom`) ;
- `version` et `description` s'affichent pendant l'installation et dans
  `apt info <paquet>` / `apt list`.

Pour un paquet hébergé en ligne, `control.lua` est cherché au même
endroit que `install.lua` (ex: `.../mon-paquet/control.lua` à côté de
`.../mon-paquet/install.lua`) ; s'il n'existe pas, ce n'est pas une
erreur, le paquet s'installe simplement sans métadonnées.

## 5. Paquets multi-fichiers ("disquette" façon CCRF)

Pour livrer plusieurs fichiers (une commande + une lib partagée, par
exemple), utilise `fs.getDir(shell.getRunningProgram())` pour retrouver
les fichiers voisins de `install.lua`, exactement comme le ferait un
installeur CCRF :

```
mon-paquet/
├── install.lua
├── control.lua
├── uninstall.lua
└── lib/
    └── monoutil.lua
```

```lua
-- install.lua
local here = fs.getDir(shell.getRunningProgram())

fs.makeDir("/lib/monoutil")
fs.copy(fs.combine(here, "lib/monoutil.lua"), "/lib/monoutil/monoutil.lua")

local cmd = fs.open("moncommande.lua", "w")
cmd.write([[
local util = dofile("/lib/monoutil/monoutil.lua")
util.run(...)
]])
cmd.close()

print("Installe ! Tape 'moncommande' pour l'utiliser.")
```

## 6. Désinstallation propre : `uninstall.lua`

Si ton paquet a besoin d'une logique de nettoyage particulière (par
exemple arrêter un service, ou ne supprimer qu'une partie d'un dossier
partagé), fournis un `uninstall.lua` parmi tes fichiers installés — un
peu comme `DEBIAN/prerm`. `apt` le détecte automatiquement (il cherche un
fichier nommé `uninstall.lua` parmi ceux enregistrés dans le manifeste) :

```lua
-- uninstall.lua
if fs.exists("/lib/monoutil") then
    fs.delete("/lib/monoutil")
end
print("Nettoyage de mon-paquet termine.")
```

`apt remove mon-paquet` ou `apt purge mon-paquet` proposera alors de
l'exécuter avant de nettoyer (en secours) tout ce qui resterait suivi
dans le manifeste.

Sans `uninstall.lua`, le comportement par défaut suffit dans la plupart
des cas :
- `apt remove` supprime les fichiers du paquet **sauf** ceux dans `/etc`
  (la config est conservée, comme le vrai `apt`) ;
- `apt purge` supprime absolument tout, y compris `/etc` et les dossiers
  vides créés par le paquet.

## 7. Construire un "disque" (image installable)

Il y a deux façons de distribuer un paquet NyxOS, l'équivalent d'un
fichier `.deb` que l'on installerait avec `dpkg -i` :

**a) Une disquette/disque en jeu.** Place `install.lua` (et
éventuellement `control.lua`, `uninstall.lua`, `lib/...`) directement à
la racine d'un disque CC: Tweaked (l'objet "Disk" ou "Floppy Disk"),
insère-le dans le lecteur relié à l'ordinateur, puis :

```
apt install ./disk
```

`apt` va chercher `install.lua` sur le disque et l'exécuter avec
`shell.run`, donc `fs.getDir(shell.getRunningProgram())` renverra bien
`/disk` et tes fichiers voisins seront trouvés normalement.

**b) Une URL (hébergement web).** Héberge le dossier du paquet
(`install.lua`, `control.lua`, etc.) quelque part accessible en HTTP
(GitHub raw, Pastebin, ton propre serveur...), puis :

```
apt install https://exemple.com/mon-paquet/install.lua
```

⚠️ Ce mode ne télécharge que `install.lua` lui-même (plus
`control.lua` s'il existe au même endroit) : si ton paquet a besoin de
fichiers voisins (`lib/...`), fais en sorte que `install.lua` les
télécharge lui-même avec `http.get` avant de les écrire sur le disque, ou
distribue plutôt ce paquet via une disquette/disque (option a).

## 8. Checklist avant de publier un paquet

- [ ] `install.lua` écrit ses fichiers avec `fs.open`/`fs.copy`/`fs.makeDir`
      (jamais de manipulation "cachée" que `apt` ne pourrait pas suivre).
- [ ] Un fichier destiné à devenir une commande est soit écrit à la
      racine (déplacement automatique vers `/bin`), soit explicitement
      placé dans `/bin` par le script.
- [ ] `control.lua` (facultatif) donne un nom, une version et une
      description clairs.
- [ ] `uninstall.lua` (facultatif) nettoie tout ce qui ne serait pas géré
      correctement par le comportement par défaut de `apt remove`/`purge`.
- [ ] Testé localement avec `apt install ./disk` avant d'être publié en
      ligne.
