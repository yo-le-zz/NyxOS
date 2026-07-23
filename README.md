# 🚀 NyxOS

> ⚠️ **Version actuelle : V1**
>
> Cette première version pose les bases de NyxOS. De nombreuses fonctionnalités et améliorations arriveront dans les prochaines versions.

**NyxOS** est un mini système d'exploitation pour **CC: Tweaked (Minecraft)**, fortement inspiré de la structure Unix/Ubuntu (`/home`, `/bin`, `/etc`, `/var`...). 

Il embarque :
* 📦 Un mini gestionnaire de paquets façon **`apt`**
* 🔒 Un système **multi-utilisateurs** sécurisé avec connexion obligatoire
* 🎨 Une interface graphique fluide façon [CloverOS](https://github.com/PalorderSoftWorksOfficial/CloverOS) grâce à la librairie [Basalt2](https://github.com/Pyroxenium/Basalt2)
* 🖥️ Une gestion native et automatique des **écrans/moniteurs**
* 🔑 Un chiffrement de disque type **LUKS**

---

## 📋 Prérequis

Pour utiliser NyxOS, il vous faut au minimum :

- ✅ Un **Computer** (ou Advanced Computer) CC: Tweaked
- ✅ Un **Monitor** (écran - *optionnel, détection automatique*)
- ✅ Un **Disk Drive** *(uniquement nécessaire pendant l'installation par disquette)*
- ⭐ Un **Cryptography Accelerator** de **Classic Peripherals** *(optionnel mais fortement recommandé pour profiter du chiffrement matériel et d'une meilleure sécurité)*

> ℹ️ *Sans **Classic Peripherals**, NyxOS fonctionne normalement, mais les fonctionnalités de chiffrement utilisent un mode de secours logiciel moins sécurisé.*

---

## 🛠️ Installation

Deux méthodes sont disponibles.

### Méthode 1 — Archive (recommandée)

1. Téléchargez la **dernière Release** (`NyxOS_x.x.x.zip`) et décompressez-la.
2. Copiez **`install.lua`** ET le dossier **`data/`** (côte à côte, dans le même dossier) dans le dossier de l'ordinateur en jeu :
   - Sauvegarde du monde → `computercraft/computer/<id>/`
   - Ou plus simplement : mettez les deux sur une disquette/disque, insérez-la dans le lecteur de disque relié à l'ordinateur, puis copiez avec :
     ```bash
     cp disk/install.lua /
     cp disk/data /
     ```
3. Dans l'ordinateur en jeu, lancez :
   ```bash
   install
   ```
4. Un assistant graphique (**Basalt**) s'ouvre : nom d'utilisateur, mot de passe (optionnel), nom d'ordinateur et **couleur d'accent** à choisir parmi une palette façon CloverOS. Ce premier compte est automatiquement administrateur. *(Si Basalt ne peut pas se lancer, l'installeur retombe automatiquement sur les mêmes questions en mode texte).*
5. Redémarrez l'ordinateur :
   ```bash
   reboot
   ```

---

### Méthode 2 — Web Installer (Recommandé en ligne)

Exécutez simplement la commande suivante dans le terminal de votre ordinateur CC: Tweaked :

```bash
wget https://raw.githubusercontent.com/yo-le-zz/NyxOS/main/webinstall.lua webinstall.lua && webinstall
```

> **Note :** Pour que l'installation Web fonctionne, l'API HTTP doit être activée dans la configuration de CC: Tweaked (`http_enable=true`).

---

## 🥾 Démarrage : Menu de Boot + Connexion

À chaque démarrage, NyxOS s'initialise en deux étapes :

1. 🟢 **Un menu de boot** façon CloverOS (*« Démarrer NyxOS »* / *« Shell de secours sans connexion »*), navigable au clavier, avec démarrage automatique sur *« Démarrer NyxOS »* après quelques secondes d'inactivité.
2. 🔐 **Un écran de connexion** obligatoire : choisissez votre utilisateur dans la liste, entrez votre mot de passe, puis vous arrivez dans votre dossier `/home/<utilisateur>`.

> 💡 Le shell de secours saute l'étape de connexion (utile en cas de blocage) mais n'ouvre aucune session utilisateur. Tout l'affichage est géré avec Basalt, avec un repli automatique en mode texte simple si Basalt plante ou est absent.

---

## 👥 Gestion des Utilisateurs

```bash
adduser <nom> [admin]   # crée un utilisateur (réservé aux administrateurs)
deluser <nom>           # supprime un utilisateur (réservé aux administrateurs)
users                   # liste les utilisateurs configurés
passwd                  # change votre propre mot de passe
passwd <nom>            # change le mot de passe d'un autre utilisateur (admin)
whoami                  # affiche l'utilisateur actuellement connecté
```

Le premier compte créé par l'installeur est toujours administrateur. `adduser`/`deluser` refusent d'agir sans les privilèges administrateur, et `deluser` refuse de supprimer le dernier administrateur du système.

---

## 📁 Arborescence Système

```text
/
├── home/<utilisateur>/  # Dossier personnel de l'utilisateur
├── bin/                 # Commandes (tree, apt, + paquets installés)
├── etc/                 # Fichiers de configuration
│   ├── passwd           # Identifiants et utilisateurs
│   ├── motd             # Message d'accueil
│   ├── nyx-release      # Information de version
│   └── apt/
│       └── installed.lua # Registre des paquets installés
├── lib/
│   └── nyxlib.lua       # Bibliothèques système
├── var/                 # Fichiers temporaires
└── startup.lua          # Script de démarrage principal
```

---

## 🧰 Commandes Intégrées

### 🌳 `tree` — Arborescence
```bash
tree          # Dossier courant
tree /home    # Dossier spécifique
tree -L 2 /   # Limiter la profondeur à 2 niveaux
```
Affiche l'arborescence façon Unix `tree`, avec le nombre de dossiers et de fichiers.

---

### 📦 `apt` — Gestionnaire de Paquets
```bash
apt install <url>            # télécharge et exécute un install.lua distant
apt install ./disk           # exécute install.lua présent sur un disque
apt install ./disk monnom    # (optionnel) force le nom du paquet
apt remove <paquet>          # supprime les fichiers, garde la config /etc
apt purge <paquet>           # supprime tout, y compris la config
apt list                     # liste les paquets installés
apt info <paquet>            # détails sur un paquet installé
```

**Fonctionnement de `apt` :**
- `apt install <url>` télécharge le code Lua via `http.get`, l'écrit dans `/var/apt/tmp/`, puis l'exécute.
- `apt install ./disk` cherche un fichier `install.lua` au chemin indiqué.
- L'installeur est exécuté avec `shell.run`, assurant une compatibilité avec les installeurs multi-fichiers.
- Intercepte tous les fichiers et dossiers créés/modifiés (`fs.open`, `fs.copy`, `fs.move`, `fs.makeDir`).
- Un fichier écrit à la racine est automatiquement placé dans `/bin`.
- Enregistre toutes les modifications dans `/etc/apt/installed.lua`.
- Exécute automatiquement `uninstall.lua` s'il est fourni lors d'un `apt remove`/`purge`.

---

### 🖥️ `display` — Affichage sur Écran Externe

NyxOS cherche automatiquement un **moniteur** branché (`peripheral.find`/`peripheral.getNames`) sur n'importe quel côté ou nom réseau :
- Détecte le type d'écran (*Advanced Monitor* ou *Standard*).
- Adapte l'échelle de texte automatiquement (0.5 pour Advanced, 1 pour Standard).
- Redirige le terminal (`term.redirect`) vers l'écran externe.

```bash
display            # affiche l'écran actuellement configuré (côté, type, échelle)
display scan        # relance la détection (utile si vous branchez un écran à chaud)
display scale <n>    # change l'échelle de texte de l'écran connecté
```
*Configuration stockée dans `/etc/nyx-display.lua`.*

---

### 🔒 `encrypt` — Chiffrement de Disque (LUKS)

Détecte automatiquement les lecteurs connectés.

```bash
encrypt              # liste les disques disponibles et leur statut
encrypt <drive>      # chiffre le disque spécifié
encrypt <drive> open # déverrouille le disque chiffré
encrypt <drive> close# verrouille le disque
```

*Le Cryptography Accelerator est utilisé pour le chiffrement si disponible. Configuration stockée dans `/etc/encrypt-config.lua`.*

---

### 🗑️ `uninstall` — Désinstallation

Désinstallation complète de NyxOS.

```bash
uninstall           # lance l'assistant de désinstallation avec confirmation
uninstall --force   # désinstallation sans confirmation (DANGEREUX)
```

Cette commande supprime tous les fichiers NyxOS (`/bin`, `/lib`, `/etc`, `/home`, `/var`, `/startup.lua`) et redémarre l'ordinateur en mode vanilla CC: Tweaked.

---

### 🐧 Commandes façon Linux

Tapez `man` pour la liste complète, ou `man <commande>` pour le détail d'une commande :

> `cat`, `echo`, `touch`, `pwd`, `whoami`, `hostname`, `uname`, `date`, `uptime`, `df`, `find`, `grep`, `head`, `tail`, `wc`, `passwd`, `adduser`, `deluser`, `users`, `display`, `neofetch`, `man`, `encrypt`, `uninstall`.

---

## 🎨 Interface Graphique (Basalt)

Le fichier `data/lib/basalt.lua` embarque la librairie [Basalt2](https://github.com/Pyroxenium/Basalt2). Vous pouvez l'utiliser dans vos propres paquets :

```lua
local basalt = dofile("/lib/basalt.lua")
local main = basalt.getMainFrame()
main:addLabel():setText("Salut depuis mon paquet !"):setPosition(2, 2)
basalt.run()
```

---

## 🛡️ Sécurité

- Le menu de connexion bloque l'accès au shell tant que le mot de passe n'est pas validé.
- Les mots de passe sont hachés en **SHA-256** via `/lib/crypto.lua`, avec support du **Cryptography Accelerator**.