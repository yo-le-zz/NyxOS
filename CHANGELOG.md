# Changelog

## 1.1.0

### Added
- **Desktop rewritten**: icons can be moved (click + drag, snapped to a
  grid, positions saved in `~/.desktop-layout`) and launched with a
  double click; several pages when there are many icons; right-click menus.
- Folders and files of `~/Desktop` appear next to the apps (open, rename,
  delete, "New folder / New file" from the desktop menu).
- **Installed packages get a desktop icon** (from `launch` / `icon` in the
  manifest) and are launchable from the Packages app.
- **Pop-up dialogs** (rename, new folder/file, delete / uninstall confirmation).
- **Files** app: colours by file type, rename / new / delete, Home and Desktop shortcuts.
- **Packages** app: Installed tab (Launch, Update, Remove, Purge) and a
  registry Browse tab with search + Install.
- **Settings** app, centered, four pages: General (hostname, boot
  interface), Account (**change password**), Look (accent colour, desktop
  background), System.
- Start menu: all apps, Exit to shell, Reboot, Shutdown.
- `guimode server`: text shell + autostart services, no graphical UI.

### Changed
- CCRF, CCTchat and Redionet `app.json` declare `launch`, `icon` and
  server `service`; their installers no longer write to `/`.

## 1.0.4

### Added
- **Background processes**: `command &` / `bg command` start a background
  job; `ps [-a]`, `jobs [pid]`, `kill`, `pkill`, `killall` and `top`
  manage them. Jobs have their own hidden terminal (read it with
  `jobs <pid>`) and survive Ctrl+T.
- **Services**: `service start|stop|restart` act immediately, `service
  add <name> <program>` registers any program as an autostart service, and
  a service can now be a plain program (`program = "/x/main.lua"`), which
  is what server installs need. `app.json` server variants can declare a
  `service` block that `apt install` registers (and `apt remove` removes).
- **`specs`** command (storage, peripherals, network, Lua heap, uptime...).
- **Task Manager** rewritten: every process, service (running or stopped),
  and system part (display, network, filesystem, desktop...), with
  Kill/Start/Stop/Enable/Disable, a Specs page and a Power page.

### Fixed
- `sudo apt install ...` (and any command that asks a question) did not
  work in the graphical shell / desktop terminal. Questions and password
  prompts now appear in the input line (passwords masked) while the
  command waits; the interface no longer freezes during a command.
- The desktop's Terminal app is now the exact same UI as the graphical
  shell (tabs, history, clear/exit), just smaller.

## 1.0.3

### Fixed
- **Desktop**: clicking an icon or a Start-menu entry crashed with `attempt to call method 'hide' (a nil value)` (Basalt has no `hide()`); screens are now swapped with `setVisible` and old ones destroyed. Icons are rounded and use text labels instead of `[x]`.
- **Terminals (desktop + graphical shell)**: `clear`/`cls` now clear the text box, `exit` closes the tab (or leaves the shell), a red `x` button closes a tab, and the output is capped to the last 300 lines so the terminal no longer stops accepting commands after many of them.
- **`Out of space` during install** (`install.lua: Out of space` in
  `fs.copy`): a computer has only ~1 MB and the downloaded `data/` folder
  (500+ KB) was kept next to the installed copy. Source files are now
  deleted as soon as they are copied (never on a disk), and a clear error
  with the free space is shown if it still does not fit.
- **Installer / web installer**: `webinstall` no longer looks for a
  `boot.json` in the repository (the installer generates it on the
  computer); HTTP errors are now told apart from "http disabled". The
  installer no longer crashes midway after wiping its own `data/` folder
  (it keeps what it still needs, only deletes real disk entries and
  checks that every source file exists first). A leftover `/startup.lua`
  from NyxLoader no longer counts as "NyxOS installed".
- **Basalt crashes**: invalid colour (`darkGray`), non-existent methods
  (`clearItems`, `scrollTo`), a fake global `shell`/`require` leaking out
  of `basalt.lua`, and `term.redirect` misuse that killed the interface
  after every command. Command output is now captured with a real
  `window` (`/lib/capture.lua`), line breaks included. The desktop
  shows the real start-up error, asks before deleting, and its Start menu
  opens/closes properly.
- **Boot**: `/nyxos.lua` works under NyxLoader's stand-in `shell` and
  when started with `dofile`.
- **Passwords**: one real SHA-256 everywhere (the digest used to change
  when a Cryptography Accelerator was plugged in/out, locking users
  out). New passwords are salted (`$nyx1$...`); old ones are upgraded at
  first login.
- `apt`: a failing installer was reported as success; installer paths
  without a leading `/`; downloads now binary-safe, spaces escaped, tmp
  folder always cleaned.
- `recovery` rewritten (it restored `/startup.lua` and missed files; now
  restores `/nyxos.lua`, never touches user data, replaces a file only
  after a complete download).
- `uninstall` no longer wipes every file/folder in the root: only
  NyxOS's own files (and NyxLoader/other files are kept).
- `rm` protects boot files and survives undeletable paths;
  `table.unpack` fallbacks for CC versions without it; `.nyx` `if`
  expansion; shared-library install over an existing file.

## 1.0.2

### Fixed
- `apt install <name>`: the installer path for a package's
  `client`/`server` variant was miscomputed, crashing with `bad
  argument #3 (string expected, got number)` right before running the
  installer (root cause: a Lua multi-return-value pitfall, not a
  misunderstanding of NyxApps' folder layout). The variant's
  `uninstall.lua` is now also persisted at install time so `apt
  remove`/`purge` can still run it later.
- `.nyx` scripts no longer crash with `attempt to call field 'resolve'
  (a nil value)` if `shell` isn't available in the calling environment.
- Fixed a self-inflicted bug in `/lib/nyxlib.lua` where an earlier
  automated edit had corrupted the file (a block got duplicated into 4
  places, breaking `loadManifest` and `installDevFs`); the file was
  rebuilt and every other prior edit was audited for the same mistake.
- Cryptography Accelerator detection now uses `peripheral.find()`, so
  it's correctly found when connected through a wired modem instead of
  only when directly attached to a side.

### Added
- `rm`: `-r`/`-f`/`-i` flags, and a typed `yes` confirmation (like
  `sudo` re-checking a password) before deleting a wildcard, several
  items at once, or a protected system folder.
- `dd`: `if=`/`of=`/`bs=`/`count=`, works with `/dev/zero` and
  `/dev/null`.
- `boot.json` (`name`/`version`/`author`/`file`) and a disk-vs-main-
  computer choice at install time. NyxOS's entry point is now
  `nyxos.lua` instead of owning `/startup.lua` directly. A fresh
  main-computer install formats everything except `/rom`, then
  downloads and runs [NyxLoader](https://github.com/yo-le-zz/NyxLoader)'s
  own web installer so it becomes `/startup.lua` and can boot NyxOS (or
  any disk carrying its own `boot.json`) through a BIOS-style menu.
- **Graphical desktop** (`desktop` command, `guimode desktop` to boot
  into it by default): taskbar with a Start menu, clock and active-app
  indicator; desktop icons; a Windows-style file explorer; an embedded
  terminal; an `apt` front-end; a task manager (services + shutdown/
  reboot). Apps fill the content area one at a time for now -- no
  floating/draggable windows yet.

## 1.0.1

### Fixed
- Basalt-based screens (login, shell, installer, man pager, encrypt,
  uninstall) now actually respond to touch on an Advanced Monitor:
  `monitor_touch` events are translated into the `mouse_click`/`mouse_up`
  events Basalt listens for (`/lib/monitorbridge.lua`).
- The graphical shell no longer crashes on start (`nyxlib.getSession`
  didn't exist; it now reads the session correctly).
- Fixed a syntax error in `encrypt.lua`/`uninstall.lua`'s text-mode
  fallback (`...` used outside a vararg function).

### Added
- `sudo` with a timed privilege session, and `/etc/sudoers.lua`
  (`/lib/permissions.lua`, `/bin/sudo.lua`). `adduser`/`deluser`/`passwd`
  now accept an active sudo session, not just permanent admins.
- Background services/daemons: `/lib/services.lua` (a small cooperative
  scheduler run from `startup.lua`), `/bin/service.lua`, and an example
  "heartbeat" service.
- Centralized logging (`/lib/logger.lua`, `/bin/logs.lua`), with
  automatic rotation.
- `apt` now understands the `app.json` package standard and can install
  NyxApps registry packages directly by name (`apt install cctchat`),
  fetched straight from GitHub, with `apt update`/`search`/`info`.
  Registry lookups are cached for an hour.
- `apt tool install/list/remove`: shared/global libraries (e.g.
  `apt tool install basalt`) other packages can `require` instead of
  bundling their own copy (`/lib/toolkit.lua`).
- `reset`: removes every apt-installed package in one go.
- `recovery`: repairs core system files from GitHub without touching
  users/config/`/home`; the installer also auto-detects a broken/partial
  install and offers recovery instead of a blind reinstall.
- A mini database engine (`/lib/db.lua`, `/bin/db.lua`).
- Basic networking: `curl`, `wget`, `net` (rednet open/host/discover/
  send, plus a small dhcp-style discovery helper).
- Machine identity: `/etc/machine-id`, `/bin/machineid.lua`.
- Multiple terminals: `newterm` (native `multishell` on Advanced
  Computers) and an in-window tab bar in the graphical shell.
- `/lib/nyxapi.lua`: a single entry point third-party scripts can use to
  reach every core subsystem, with a small pub/sub event bus for
  cross-package communication.
- `mkpkg`: scaffolds a ready-to-edit `app.json` package.
- The `.nyx` scripting language (`/lib/nyxscript.lua`, `/bin/nyx.lua`),
  documented in `docs/NYX_SCRIPTING.md` with examples.
- `/dev/null` and `/dev/zero`.
- Installer: installs directly onto a connected screen, offers a
  with/without graphical-interface choice, and detects a partial/broken
  install to offer recovery instead of a blind reinstall.
- `shutdown`/`reboot` now flush `/var/tmp` and `/var/apt/tmp` for a
  clean tmp lifecycle, and take priority over any same-named ROM
  program (`/bin` is now first on `shell.path()`).

### Changed
- The entire core OS, installer, docs, and README are now in English.
- `docs/PACKAGING.md` documents both the new `app.json` registry format
  and the original generic-installer format.
