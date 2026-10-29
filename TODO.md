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

## 1.4.0 — Vrai réseau + SSH
- [ ] `/etc/network.lua` : interface(s), IP statique/DHCP-like, masque, passerelle
- [ ] `/etc/hosts` + serveur/clients **DNS** (service `dns`, résolution de noms → ID/IP)
- [ ] Fichiers de configuration serveur (`/etc/servers/*.lua` : ip, dns, ports, services)
- [ ] Commandes : `ifconfig`, `ping`, `nslookup`, `hostname`, `netstat`
- [ ] Couche transport au-dessus de rednet/modem (ports, sockets simples)
- [ ] Package **ssh** (client + serveur) : shell distant, `scp`, clés/mots de passe
- [ ] Task Manager : état réseau détaillé

## 1.5.0 — Variables d'environnement, mémoire virtuelle, éditeur
- [ ] Variables d'environnement : `/etc/environment`, `~/.profile`, `export`, `env`,
      `unset`, `$VAR` dans le shell et dans `.nyx`
- [ ] Mémoire virtuelle : fichier d'échange (swap) pour les gros jeux de données,
      API `vm.alloc/free/read/write`, commande `free`, affichage dans Specs
- [ ] **Éditeur de code** (app bureau + commande `edit`) : onglets, coloration
      Lua/.nyx/Python/C, recherche, sauvegarde, exécution
- [ ] Éditeur : numéros de ligne, auto-indentation, annuler/refaire

## 1.6.0 — Langages externes (Python, C)
- [ ] Registre d'interpréteurs `/etc/interpreters.lua` (`.py` → package python,
      `.c` → package c)
- [ ] Hook shell : `python main.py` / `c main.c` → interpréteur du package
- [ ] API `nyxapi.registerInterpreter(name, ext, program)` pour les packages
- [ ] Spécification (docs/) de l'interface qu'un interpréteur doit fournir :
      parse → exécution → traduction des appels système vers l'API NyxOS
- [ ] Packages `python` et `c` : squelettes (le vrai interpréteur viendra plus tard)

## 1.7.0 — Robustesse et finitions
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
