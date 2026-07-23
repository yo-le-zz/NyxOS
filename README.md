# NyxOS

Mini-OS pour CC: Tweaked (Minecraft), inspiré de la structure Ubuntu
(`/home`, `/bin`, `/etc`, `/var`...), avec un mini gestionnaire de paquets
façon `apt`, un compte utilisateur obligatoire à la connexion, la gestion
multi-utilisateurs, et une interface graphique façon
[CloverOS](https://github.com/PalorderSoftWorksOfficial/CloverOS) grâce à
la librairie [Basalt](https://github.com/Pyroxenium/Basalt2).

## Installation

1. Décompresse le zip.
2. Copie **`install.lua`** ET le dossier **`data/`** (côte à côte, dans le
   même dossier) dans le dossier de l'ordinateur en jeu :
   - Sauvegarde du monde → `computercraft/computer/<id>/`
   - ou plus simplement : mets les deux dans un disquette/disque, insère-la
     dans le lecteur de disque relié à l'ordinateur, puis copie avec
     `cp disk/install.lua /` et `cp disk/data /` (ou glisse-dépose côté hôte).
3. Dans l'ordinateur en jeu :
   ```
   install
   ```
   (ou `install.lua` selon comment tu l'as nommé)
4. Un assistant graphique (Basalt) s'ouvre : nom d'utilisateur, mot de
   passe (optionnel), nom d'ordinateur et **couleur d'accent** à choisir
   parmi une palette façon CloverOS. Ce premier compte est automatiquement
   administrateur. (Si Basalt ne peut pas se lancer, l'installeur retombe
   automatiquement sur les mêmes questions en mode texte.)
5. Redémarre l'ordinateur (`reboot`).

## Démarrage : menu de boot + connexion

À chaque démarrage, NyxOS affiche désormais :

1. **Un menu de boot** façon CloverOS (« Démarrer NyxOS » / « Shell de
   secours sans connexion »), navigable au clavier, avec démarrage
   automatique sur « Démarrer NyxOS » après quelques secondes si tu ne
   touches à rien.
2. **Un écran de connexion** obligatoire : choisis ton utilisateur dans la
   liste, entre ton mot de passe (s'il y en a un), puis tu arrives dans
   ton `/home/<utilisateur>`. Le shell de secours saute cette étape (utile
   si tu es bloqué dehors) mais n'ouvre aucune session utilisateur.

Comme pour le reste de l'interface, tout ça est fait avec Basalt, avec un
repli en mode texte simple si Basalt plante ou est absent : **l'ordinateur
ne reste jamais bloqué au démarrage**.

## Utilisateurs

```
adduser <nom> [admin]   -- cree un utilisateur (reserve aux administrateurs)
deluser <nom>           -- supprime un utilisateur (reserve aux administrateurs)
users                   -- liste les utilisateurs configures
passwd                  -- change ton propre mot de passe
passwd <nom>            -- change le mot de passe d'un autre utilisateur (admin)
whoami                  -- affiche l'utilisateur actuellement connecte
```

Le premier compte créé par l'installeur est toujours administrateur ;
`adduser`/`deluser` refusent d'agir si tu n'es pas administrateur, et
`deluser` refuse de supprimer le dernier administrateur du système.

Après ça, l'ordinateur a :

```
/home/<utilisateur>/
/bin/            -- commandes (tree, apt, + tout ce qu'apt installera)
/etc/
  passwd
  motd
  nyx-release
  apt/installed.lua   -- manifeste des paquets installés
/lib/
  nyxlib.lua
/startup.lua
```

## Commandes ajoutées

### `tree`

```
tree
tree /home
tree -L 2 /
```

Affiche l'arborescence façon Unix `tree`, avec le nombre de dossiers/fichiers.

### `apt`

```
apt install <url>            -- télécharge et exécute un install.lua distant
apt install ./disk           -- exécute install.lua présent sur un disque
apt install ./disk monnom    -- (optionnel) force le nom du paquet
apt remove <paquet>          -- supprime les fichiers, garde la config /etc
apt purge <paquet>           -- supprime tout, y compris la config
apt list                     -- liste les paquets installés
apt info <paquet>            -- détails sur un paquet installé
```

**Comment ça marche :**
- `apt install <url>` fait un `http.get` sur l'URL, récupère le code Lua,
  l'écrit dans un fichier temporaire (`/var/apt/tmp/`), puis l'exécute.
- `apt install ./disk` (ou n'importe quel chemin) va chercher un fichier
  `install.lua` à cet endroit (si tu donnes un dossier) ou le fichier
  lui-même (si tu donnes un `.lua` directement), puis l'exécute.
- L'installeur est exécuté avec **`shell.run`** (et pas juste chargé et
  appelé directement) : `shell.getRunningProgram()` renvoie donc le vrai
  chemin du script pendant son exécution. C'est indispensable pour
  supporter les **installeurs multi-fichiers type "disquette"** (par
  exemple un script `install.lua` qui utilise
  `fs.getDir(shell.getRunningProgram())` pour retrouver des fichiers
  voisins comme `lib/*.lua`, les copier avec `fs.copy`/`fs.makeDir`, puis
  créer une commande unique à la racine — le genre d'installeur qu'on
  trouve dans des projets comme CCRF).
- Pendant l'exécution du script installeur, `apt` intercepte **tous les
  fichiers et dossiers touchés sur le disque**, quelle que soit la
  méthode utilisée : `fs.open(..., "w")`, mais aussi `fs.copy`,
  `fs.move` et `fs.makeDir`. Peu importe où le script les place.
- Un fichier écrit à la racine (ex: `fs.open("hello.lua", "w")` ou
  `fs.open("/ccrf", "w")`) est automatiquement **déplacé dans `/bin`** —
  pratique pour livrer une nouvelle commande.
- Un fichier écrit à un chemin absolu (ex: `/etc/monpaquet.conf` ou
  `/ccrf_data/...`) reste où il est, mais reste suivi.
- Tous les fichiers/dossiers touchés sont enregistrés dans
  `/etc/apt/installed.lua` sous le nom du paquet, ce qui permet ensuite
  `apt remove` / `apt purge`.
- **Si le paquet fournit son propre `uninstall.lua`** (détecté
  automatiquement parmi les fichiers installés), `apt remove`/`apt purge`
  le repère et propose de l'exécuter pour une désinstallation propre,
  avant de nettoyer en secours tout ce qui resterait suivi dans le
  manifeste.
- `apt remove` supprime les fichiers du paquet **sauf** ceux dans `/etc`
  (comportement façon vrai apt : la config est gardée), sauf si le
  script `uninstall.lua` du paquet a été utilisé (dans ce cas tout est
  nettoyé).
- `apt purge` supprime absolument tout, y compris la config et les
  dossiers créés (s'ils sont vides).

Un exemple de paquet installable est fourni dans
`exemples/paquet_hello/install.lua` : héberge-le en ligne (pastebin,
raw GitHub...) ou mets-le sur un disque, et teste avec
`apt install <url ou chemin>`.

**Important (côté serveur Minecraft) :** pour que `apt install <url>`
fonctionne, l'API `http` doit être activée dans la config CC: Tweaked
(`http_enable=true`), et le domaine/l'URL doit être autorisé si une
liste blanche est en place.

### Affichage sur écran (moniteur)

Au démarrage, NyxOS cherche automatiquement un **moniteur** branché sur
l'ordinateur (`peripheral.find`/`peripheral.getNames`), quel que soit le
**côté ou le nom réseau** sur lequel il est connecté (`top`, `left`,
`monitor_0` via modem, etc. — détection automatique de la position). Si
un moniteur est trouvé :
- il détecte s'il s'agit d'un **Advanced Monitor** (couleur) ou d'un
  **Monitor standard**, via `monitor.isColour()` ;
- il choisit une échelle de texte adaptée (0.5 pour un Advanced Monitor,
  1 pour un standard) ;
- il redirige tout le terminal (`term.redirect`) vers cet écran.

Si aucun moniteur n'est branché, NyxOS continue normalement sur l'écran
natif de l'ordinateur.

```
display            -- affiche l'écran actuellement configuré (côté, type, échelle)
display scan        -- relance la détection (utile si tu branches un écran à chaud)
display scale <n>    -- change l'échelle de texte de l'écran connecté
```

Configuration stockée dans `/etc/nyx-display.lua`.

### `encrypt`

Chiffrement de disque façon Linux (LUKS). Détecte automatiquement les
disques/drives connectés par numéro de côté ou nom réseau.

```
encrypt              -- liste les disques disponibles et leur statut
encrypt <drive>      -- chiffre le disque spécifié
encrypt <drive> open -- déverrouille le disque chiffré
encrypt <drive> close -- verrouille le disque
```

**Exemples :**
```
encrypt top          -- chiffre le disque connecté en haut
encrypt drive_0 open -- déverrouille le disque réseau drive_0
encrypt left close   -- verrouille le disque connecté à gauche
```

Le Cryptography Accelerator est utilisé pour le chiffrement si disponible.
La configuration est stockée dans `/etc/encrypt-config.lua`.

### `uninstall`

Désinstallation complète de NyxOS.

```
uninstall           -- lance l'assistant de désinstallation avec confirmation
uninstall --force   -- désinstallation sans confirmation (DANGEREUX)
```

Cette commande supprime tous les fichiers NyxOS (`/bin`, `/lib`, `/etc`,
`/home`, `/var`, `/startup.lua`) et redémarre l'ordinateur en mode vanilla
CC: Tweaked. **Cette opération est irréversible.**

### Commandes façon Linux

En plus de `tree` et `apt`, NyxOS ajoute une série de commandes
classiques (tape `man` pour la liste complète, `man <commande>` pour le
détail d'une commande) :

`cat`, `echo`, `touch`, `pwd`, `whoami`, `hostname`, `uname`, `date`,
`uptime`, `df`, `find`, `grep`, `head`, `tail`, `wc`, `passwd`,
`adduser`, `deluser`, `users`, `display`, `neofetch`, `man`, `encrypt`,
`uninstall`.

(NyxOS n'ajoute pas `ls`, `cd`, `cp`, `mv`, `rm`, `mkdir`, `clear`,
`reboot`, `shutdown` : ces commandes existent déjà nativement dans
CC: Tweaked.)

## Interface graphique (Basalt)

`data/lib/basalt.lua` embarque la librairie
[Basalt2](https://github.com/Pyroxenium/Basalt2) (release complète),
utilisée pour l'installeur, le menu de boot, l'écran de connexion et le
pager de `man`. Tu peux t'en servir dans tes propres paquets :

```lua
local basalt = dofile("/lib/basalt.lua")
local main = basalt.getMainFrame()
main:addLabel():setText("Salut depuis mon paquet !"):setPosition(2, 2)
basalt.run()
```

## Notes de sécurité

- Le menu de connexion **bloque réellement** l'accès au shell tant que le
  mot de passe correct n'est pas entré (sauf choix explicite du « shell
  de secours » au menu de boot). Les mots de passe sont maintenant **hachés
  avec SHA-256** via le module `/lib/crypto.lua`, qui utilise le
  **Cryptography Accelerator** de CC: Tweaked si disponible. Si le
  Cryptography Accelerator n'est pas connecté, un fallback de hash simple
  est utilisé (moins sécurisé mais fonctionnel).
- Tu peux ajouter d'autres commandes en les mettant simplement dans
  `data/bin/` avant l'installation, ou en les installant après coup via
  `apt install`. Voir `docs/PACKAGING.md` pour créer tes propres paquets
  installables (façon `.deb`) ou disquettes d'installation.
