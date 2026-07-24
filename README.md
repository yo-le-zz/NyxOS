# 🚀 NyxOS

> ⚠️ **Current version: 1.0.1**
>
> This release builds on NyxOS's first version with a much larger command
> set (sudo, services, networking, a mini database, logging...). Some
> larger features are still in progress -- see [Roadmap](#-roadmap) below.

**NyxOS** is a mini operating system for **CC: Tweaked (Minecraft)**,
heavily inspired by the Unix/Ubuntu layout (`/home`, `/bin`, `/etc`,
`/var`...).

It ships with:
* 📦 A mini **`apt`**-style package manager, with a `name`-based registry
  (`apt install cctchat`) built on the `app.json` standard
* 🔒 A secure **multi-user** system with mandatory login, plus
  Linux-style **`sudo`** with a timed privilege session
* 🎨 A smooth graphical interface in the style of
  [CloverOS](https://github.com/PalorderSoftWorksOfficial/CloverOS),
  powered by the [Basalt2](https://github.com/Pyroxenium/Basalt2) library
  -- installable with or without it
* 🖥️ Native, automatic **screen/monitor** handling, including touch
  input on Advanced Monitors
* 🔑 **LUKS**-style disk encryption
* 🛠️ Background **services/daemons**, a mini **database**, centralized
  **logging**, machine **identity**, basic **networking** (`curl`,
  `wget`, `net`/rednet), and the **`.nyx`** automation scripting language

---

## 📋 Requirements

To use NyxOS you need at least:

- ✅ A **Computer** (or Advanced Computer) running CC: Tweaked
- ✅ A **Monitor** (screen -- *optional, auto-detected*)
- ✅ A **Disk Drive** *(only needed for floppy-based installation)*
- ⭐ A **Cryptography Accelerator** from **Classic Peripherals**
  *(optional but strongly recommended for hardware-accelerated
  encryption/hashing and better security)*

> ℹ️ *Without Classic Peripherals, NyxOS works normally, but encryption
> and hashing fall back to a less secure software mode.*

---

## 🛠️ Installation

Two methods are available.

### Method 1 -- Archive (recommended)

1. Download the latest **Release** (`NyxOS_x.x.x.zip`) and unzip it.
2. Copy **`install.lua`** AND the **`data/`** folder (side by side, in the
   same folder) into the in-game computer's folder:
   - World save → `computercraft/computer/<id>/`
   - Or more simply: put both on a floppy/disk, insert it into the disk
     drive attached to the computer, then copy with:
     ```bash
     cp disk/install.lua /
     cp disk/data /
     ```
3. On the in-game computer, run:
   ```bash
   install
   ```
4. If a monitor is connected, the installer automatically runs on it. A
   graphical wizard (**Basalt**) opens: username, password (optional),
   computer name, an **accent colour** from a CloverOS-style palette,
   and whether to install the **graphical interface** at all (you can
   choose a text-only install). The first account created is always an
   administrator. *(If Basalt can't start, the installer falls back to
   the same questions in text mode automatically.)*
5. Reboot the computer:
   ```bash
   reboot
   ```

If NyxOS is already installed, running `install` again offers an
**update** (system files refreshed, users/config untouched) or, if it
detects a partially broken install, a **recovery** mode instead. The
same repair can be triggered any time with the standalone `recovery`
command, which re-downloads core files straight from GitHub.

### Method 2 -- Web Installer (recommended online)

Just run the following in your CC: Tweaked computer's terminal:

```bash
wget https://raw.githubusercontent.com/yo-le-zz/NyxOS/main/webinstall.lua webinstall.lua && webinstall
```

> **Note:** for the web install to work, the HTTP API must be enabled in
> the CC: Tweaked config (`http_enable=true`).

---

## 🥾 Boot: boot menu + login

On every boot, NyxOS initialises in two steps:

1. 🟢 **A CloverOS-style boot menu** (*"Start NyxOS"* / *"Recovery shell
   (no login)"*), keyboard-navigable, auto-starting *"Start NyxOS"*
   after a few seconds of inactivity -- a small BIOS-like timed prompt.
2. 🔐 **A mandatory login screen**: pick your user from the list, enter
   your password, and you land in `/home/<user>`.

> 💡 The recovery shell skips login (useful if something's stuck) but
> opens no user session -- from there you can run `recovery` to repair
> system files, or `shell` to reach the plain CraftOS shell if NyxOS
> itself won't load. Everything is rendered with Basalt, with an
> automatic fallback to plain text mode if Basalt crashes, is absent, or
> was disabled at install time.

---

## 👥 User management

```bash
adduser <name> [admin]   # creates a user (admin/sudo only)
deluser <name>            # deletes a user (admin/sudo only)
users                     # lists configured users
passwd                    # changes your own password
passwd <name>              # changes another user's password (admin/sudo)
whoami                    # shows the currently logged in user
```

The first account created by the installer is always an administrator.
`adduser`/`deluser` refuse to act without elevated privileges, and
`deluser` refuses to delete the system's last administrator.

### 🔑 `sudo` -- temporary elevated privileges

```bash
sudo <command> [args...]   # runs a command with a temporary sudo session
sudo -v                    # refreshes/extends the current session
sudo -k                    # drops the session immediately
```

Any administrator account can `sudo`; re-entering your own password
starts a 5-minute session (like real Linux sudo) so you don't need to
retype it for every privileged command in a row. `/etc/sudoers.lua` can
optionally restrict which admins are allowed to use it.

---

## 📁 System layout

```text
/
├── home/<user>/         # User's personal folder
├── bin/                 # Commands (tree, apt, sudo, + installed packages)
├── dev/                 # Special files: /dev/null, /dev/zero
├── etc/                 # Configuration files
│   ├── passwd           # User accounts
│   ├── motd             # Welcome message
│   ├── nyx-release       # Version info
│   ├── machine-id        # Persistent machine identity
│   ├── services/          # Service (daemon) definitions
│   └── apt/
│       └── installed.lua  # Installed package registry
├── lib/
│   ├── nyxlib.lua         # Core system library
│   ├── nyxapi.lua          # Unified API facade for third-party scripts
│   └── tools/              # Shared/global libraries ("apt tool install")
├── var/
│   ├── log/nyxos.log        # Centralized system log
│   ├── db/                  # Mini databases
│   ├── run/                  # Volatile runtime state (session, services...)
│   ├── tmp/, apt/tmp/          # Scratch space, wiped on shutdown/reboot
└── startup.lua           # Main boot script
```

---

## 🧰 Built-in commands

Run `man` for the full list, or `man <command>` for details on any one
of them (rendered in a real scrollable pager). Highlights:

### 🌳 `tree` -- file tree
```bash
tree          # current folder
tree /home    # specific folder
tree -L 2 /   # limit depth to 2 levels
```

### 📦 `apt` -- package manager
```bash
apt install <name> [client|server]   # install a NyxApps registry package by name
apt install <url|path>               # install a generic install.lua
apt install ./disk                   # install from a local disk
apt update [name]                     # check/apply updates from the registry
apt remove <package>                  # delete files, keep /etc
apt purge <package>                    # delete everything, incl. /etc
apt list                               # list installed packages
apt info <package>                      # details about an installed package
apt search <term>                       # search the NyxApps registry
apt tool install|list|remove <name>      # shared/global libraries (e.g. basalt)
```

Registry packages describe themselves with an `app.json` (name,
version, description, author, client/server entry+installer+uninstaller)
-- see [`docs/PACKAGING.md`](NyxOS/docs/PACKAGING.md). Use `mkpkg <name>`
to scaffold a new one instantly. Every install/removal is tracked in
`/etc/apt/installed.lua`; `reset` uninstalls everything on top of the
base system in one go.

### 🛠️ `service` -- background services (daemons)
```bash
service list
service status [name]
service enable|disable <name>
service logs <name>
```
A tiny cooperative init system: enabled services run alongside the
interactive shell from boot onward (`/lib/services.lua`).

### 🌐 Networking
```bash
curl <url> [-o file]
wget <url> <file>
net open|host|discover|send|dhcp
```

### 🗄️ `db` -- mini database
```bash
db list
db tables <database>
db dump <database> <table>
```
A lightweight table-store any package can use via `/lib/db.lua` --
useful for chat logs, radio channels, turtle fleets, etc.

### 📜 `logs` -- centralized logging
```bash
logs           # last 30 lines
logs -t apt     # filter by tag
logs -f          # follow in real time
```

### 🖥️ `display` -- external screen output
NyxOS automatically looks for a connected **monitor**
(`peripheral.find`/`peripheral.getNames`) on any side or network name,
detects Advanced vs Standard, scales text accordingly, and redirects
the terminal to it -- touch input works too (monitor touches are
translated into clicks for Basalt).
```bash
display            # shows the currently configured screen
display scan         # re-runs detection (hot-plugged screen)
display scale <n>     # changes the connected screen's text scale
```

### 🔒 `encrypt` -- disk encryption (LUKS-style)
```bash
encrypt   # graphical disk encryption/unlock manager
```

### 🗑️ `uninstall` / `reset` / `recovery`
```bash
uninstall            # fully removes NyxOS, back to vanilla CC: Tweaked
reset                # removes every apt-installed package, keeps the base OS
recovery              # repairs core system files from GitHub, keeps your data
```

### 📝 `.nyx` scripts
```bash
nyx myscript.nyx
```
NyxOS's own automation language -- a small mix of shell scripting and
old-style batch scripting (labels + goto). See
[`docs/NYX_SCRIPTING.md`](NyxOS/docs/NYX_SCRIPTING.md).

---

## 🎨 Graphical interface (Basalt)

`data/lib/basalt.lua` bundles the [Basalt2](https://github.com/Pyroxenium/Basalt2)
library. You can use it in your own packages:

```lua
local basalt = dofile("/lib/basalt.lua")
local main = basalt.getMainFrame()
main:addLabel():setText("Hi from my package!"):setPosition(2, 2)
basalt.run()
```

Prefer not bundling your own copy? Install it as a shared library once
(`apt tool install basalt`) and pull it in with
`dofile("/lib/toolkit.lua").require("basalt")` instead.

For scripts that want one entry point into every core subsystem
(users, permissions, services, logging, db, networking...), see
`/lib/nyxapi.lua`.

---

## 🛡️ Security

- The login screen blocks shell access until the password is verified.
- Passwords are hashed with **SHA-256** via `/lib/crypto.lua`, with
  **Cryptography Accelerator** support.
- `sudo` sessions are time-limited and can be restricted via
  `/etc/sudoers.lua`.
- Always use `shutdown`/`reboot` (not the raw terminate combo) for a
  clean shutdown that wipes `/var/tmp` and `/var/apt/tmp`.

---

## 🗺️ Roadmap

Larger features that are planned but **not yet implemented**:

- Signed boot / secure boot (CCSecureBoot-style), with a BIOS-like boot
  order editable from a recovery menu
- A full graphical desktop: taskbar, drawn icons, a Windows-style file
  explorer, and a task manager
- A turtle fleet manager with live monitoring
- `apt` importing (and auto-adapting) almost any project from
  [PineStore.cc](https://pinestore.cc)

See `TODO.md` in the repository for the detailed, up-to-date list.
