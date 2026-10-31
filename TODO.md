# NyxOS — TODO / roadmap par version

Légende : `[x]` fait · `[ ]` à faire · `(?)` à préciser

Chaque version fait l'objet d'un zip livré séparément.

---

## 1.0.4 — Processus, services, Task Manager ✅ (livrée)
- [x] `sudo apt install …` fonctionne dans le shell graphique / terminal du bureau
      (questions y/n et mots de passe via la ligne de saisie, masqués)
- [x] Terminal du bureau = même UI que le shell graphique (en plus petit)
- [x] Processus en arrière-plan : `cmd &`, `bg`, `jobs [pid]`
- [x] `ps [-a]`, `kill`, `pkill`, `killall`, `top`
- [x] Services : `service start|stop|restart|add|remove`, service = simple programme
- [x] `app.json` : bloc `service` pour les variantes serveur (installé/retiré par `apt`)
- [x] `specs` (specs de la machine)
- [x] Task Manager : tous les processus/services/parties système (display, network,
      filesystem, desktop…) + page Specs + page Power

## 1.1.0 — Bureau : icônes, dossiers, apps ✅ (livrée)
- [x] Icônes déplaçables : 1 clic = sélection + glisser-déposer, 2 clics = lancer
- [x] Positions des icônes sauvegardées (`~/.desktop-layout`)
- [x] Les dossiers/fichiers de `~/Desktop` apparaissent à côté des apps
- [x] Icônes avec des formes différentes par app (pictogrammes en blocs CC)
- [x] Files : renommer (pop-up), nouveau dossier (pop-up), supprimer (pop-up), couleurs
      par type de fichier (glisser vers le bureau : reporté)
- [x] Settings : page centrée, plus de couleurs, **changer le mot de passe**, hostname,
      thème, mode d'interface (shell/desktop/server), repo + auto-update (voir 1.2.0)
- [x] Packages : bouton **Lancer**, installer/désinstaller, mettre à jour
- [x] Icônes des packages installés sur le bureau
- [x] **Tous les packages existants** (CCRF, CCTchat, Redionet) : `app.json` avec `icon`,
      `launch`, `service` (serveurs), nettoyer leurs installeurs (plus de fichiers
      jetés à la racine `/`)
- [x] Menu Démarrer : apps, Exit to shell, Reboot, Shutdown (recherche : reporté)

## 1.2.0 — Fenêtres, apps par défaut, installateur, langues ✅ (livrée)
- [x] Fenêtres flottantes : barre de titre, déplacer / cacher / plein écran / fermer, superposition
- [x] Apps par défaut : calculatrice, éditeur de code, calendrier, horloge, notes, journaux
- [x] Installateur animé : choix de la langue, des apps, progression
- [x] Packs de langues fr / es / de, commande `lang`
- [x] Logs système (erreurs Basalt, crashs d'apps), `sleep`, correctifs top / Files / sudo
- [x] Icônes : clic = menu, clic puis clic vide = déplacer

## 1.3.0 — Mises à jour automatiques ✅ (livrée)
- [x] Lecture des tags GitHub (`X.Y.Z`) — repo par défaut `yo-le-zz/NyxOS`
- [x] Repo configurable (`/etc/nyx-config.lua` → `updateRepo`, modifiable dans Settings)
- [x] Auto-update activable/désactivable dans Settings (+ fréquence)
- [x] Commande `nyxupdate [check|install|status|repo|auto|interval]`
- [x] Notification dans le bureau « mise à jour disponible » (bouton Update!)
- [x] Mise à jour sûre : tout est téléchargé avant remplacement, jamais d'écrasement de
      `/etc` ni `/home`, arrêt si pas assez de place
- [ ] Rollback complet (impossible avec le quota de 1 Mo : seulement « rien n'est remplacé
      si le téléchargement échoue »)

## 1.4.0 — Vrai réseau + SSH ✅ (livrée)
- [x] `/etc/network.lua` : IP statique / DHCP, masque, passerelle
- [x] `/etc/hosts` + service `dns`
- [x] `/etc/servers/*.lua` (ip, dns, ports, services)
- [x] `ifconfig`, `ping`, `nslookup`, `netstat`, `hosts`
- [x] Couche transport (ports, sockets) au-dessus de rednet
- [x] Package **ssh** (ssh, scp, clés, sshd)
- [x] Task Manager : page réseau
- [ ] Chiffrement du trafic (rien n'est chiffré pour l'instant)

## 1.5.0 — Internet, marketplace, apps, fonds d'écran ✅ (livrée)
- [x] http / https sur le réseau NyxOS (`/lib/nyxhttp.lua`, `web`, service `httpd`, `nyxcert`)
      + repli sur le vrai internet (API `http` de CC)
- [x] Navigateur (app **Browser**)
- [x] CCTchat revu (login throttle, hash SHA-256 par utilisateur, /quit), vérifié en simulateur
- [x] Marketplace refaite (Packages) : cartes, une icône par paquet (`icon.generate`)
- [x] Nouvelles apps : Paint, Globe, Snake, 2048, Minesweeper, System Monitor
- [x] Paquets : cowsay, fortune, snow, todo
- [x] Fonds d'écran animés (`/lib/wallpaper.lua`) : globe, étoiles, vagues, plasma, matrix, image Paint
- [x] Basalt : `Image:setTransparent` (icônes sur le fond d'écran)
- [x] Installateur : globe animé, globe pendant la copie des fichiers
- [x] Menu Démarrer multi-colonnes

## 1.6.0 — Variables d'environnement, mémoire virtuelle, éditeur avancé ✅ (livrée)
- [x] Variables d'environnement : `/etc/environment`, `~/.profile`, `export [-p|-g]`, `env`,
      `printenv`, `unset`, `$VAR` / `${VAR}` / `~` dans le shell et dans `.nyx`
- [x] Mémoire virtuelle : swap `/var/swap`, API `vm.alloc/free/read/write/stats`, commande `free`,
      ligne Swap dans Specs
- [x] Éditeur : annuler/refaire (Ctrl+Z / Ctrl+Y, boutons < >), auto-indentation,
      coloration Lua/.nyx/Python/C selon l'extension
- [ ] Éditeur : sélection multi-lignes, remplacement

## 1.7.0 — Profils (Classic / Tablette / Serveur), installateur, correctifs UI ✅ (livrée)
- [x] Trois profils : Classic, Tablette (incl. mini PC), Serveur (`profile`, Settings, installateur)
- [x] UI adaptée : fenêtres maximisées + menu compact en Tablette, tableau de bord texte en Serveur
- [x] Mode bureau (GUI) par défaut
- [x] Installateur : questionnaire (profil, hostname, utilisateur, mot de passe, accent) dans le style des menus de langue
- [x] Installation de paquets depuis l'UI sans terminal (choix client/serveur, mot de passe admin, boîte de tâche)
- [x] Icônes des apps installées individuellement (manifeste apt `launch`/`icon`)
- [x] Déplacement des fenêtres : mode « placer » (clic sur le titre, flèches, clic pour poser)
- [x] Redionet : client corrigé (1.1.2)
- [x] NyxLoader 1.1.0 (ASCII, redémarrage auto, installateur NyxOS)

## 1.8.0 — Langages externes (Python, C)
- [ ] Registre d'interpréteurs `/etc/interpreters.lua` (`.py` → package python,
      `.c` → package c)
- [ ] Hook shell : `python main.py` / `c main.c` → interpréteur du package
- [ ] API `nyxapi.registerInterpreter(name, ext, program)` pour les packages
- [ ] Spécification (docs/) de l'interface qu'un interpréteur doit fournir :
      parse → exécution → traduction des appels système vers l'API NyxOS
- [ ] Packages `python` et `c` : squelettes (le vrai interpréteur viendra plus tard)

## 1.9.0 — Robustesse et finitions
- [ ] Installation sur disque : réécriture des chemins sous NyxLoader (limite connue)
- [ ] Priorités de processus, `nice`, limites de ressources
- [ ] IPC simple entre processus (files de messages)
- [x] Mode serveur sans interface (`guimode server`) : services + shell texte
- [ ] Tests automatisés (simulateur CC:Tweaked) dans le dépôt
- [ ] Documentation complète (`docs/`) pour chaque sous-système

---

## Backlog / idées
- [ ] Signature des fichiers au boot (accélérateur crypto + NyxLoader)
- [ ] `apt` : import de projets PineStore.cc
- [ ] Gestionnaire de flotte de turtles
- [ ] `.nyx` : arithmétique et contrôle de flux enrichi

---

## Turtles (roadmap long terme, tout à la fin)
- [ ] Profil « Turtle » : détection `turtle`, UI texte minimale, démarrage automatique d'un job
- [ ] Gestionnaire de flotte : liste/état/carburant/position de toutes les turtles (modem/Redionet)
- [ ] Contrôle à distance : console, déplacement manuel, caméra d'inventaire
- [ ] GPS : hôte GPS, calibration, `gps locate`, cartes de positions
- [ ] Pathfinding A* avec carte du monde partagée et évitement de collision entre turtles
- [ ] Programmes de minage : tunnel, branche, chambre, veine, mine en carrière (quarry)
- [ ] Programmes de ferme : blé, arbres, canne, élevage, ferme à mobs
- [ ] Construction : plans (`.nfp`/schéma), murs, sols, bâtiments, copie de zone
- [ ] Gestion d'inventaire : tri, coffre-dépôt automatique, déchargement, recharge de carburant
- [ ] Gestion du carburant : retour automatique à la base, estimation de trajet
- [ ] Planificateur de tâches (file de jobs, priorités, reprise après redémarrage)
- [ ] Éditeur de jobs visuel et scripts `.nyx` dédiés turtle
- [ ] Packages `apt` « turtle » (variantes client turtle / serveur de flotte)
- [ ] Journal et alertes (turtle bloquée, plus de carburant, inventaire plein)
- [ ] Synchronisation d'état au reboot (reprise de position et de tâche)
- [ ] Tableau de bord flotte dans l'UI Serveur (carte, jobs, carburant)
