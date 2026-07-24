# Changelog

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
