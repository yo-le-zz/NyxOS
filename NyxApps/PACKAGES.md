# 🚀 NyxOS App Package Standard

Every NyxOS application must provide an `app.json` file.

Example:

```json
{
    "name": "example",
    "version": "1.0.0",
    "description": "Example application",

    "author": "author",

    "type": [
        "client",
        "server"
    ],

    "client": {
        "entry": "example.lua",
        "installer": "install.lua",
        "uninstaller": "uninstall.lua"
    },

    "server": {
        "entry": "startup.lua",
        "installer": "install.lua",
        "uninstaller": "uninstall.lua"
    }
}
```

`entry` is informational (the main script of the variant, relative to the
variant folder). `installer` / `uninstaller` are relative to the variant
folder (`client/` or `server/`) or to the package root: `apt` accepts both.
Only declare the variants listed in `type` (and give them a folder).


# 💪 Supported types

## Client ( for NyxOS installation )
## Server ( for empty computer installation )


# 📓 Required files

    - `app.json`
    - `LICENSE.txt`
    - `ORIGIN.md`
    - `control.lua` (optional)
    - `install.lua`
    - `uninstall.lua`

# 🖥️ Desktop & server integration (NyxOS 1.1.0+)

Each variant (`client` / `server`) of `app.json` may also declare:

```json
"client": {
    "entry": "ccrf.lua",
    "installer": "install.lua",
    "uninstaller": "uninstall.lua",
    "launch": "ccrf",
    "icon": { "color": "red", "art": ["  /\\  ", " /!!\\ ", "/____\\"] }
},
"server": {
    "service": {
        "name": "cctchat",
        "program": "/cctchat-serv/main.lua",
        "args": ["Server"],
        "autostart": true,
        "description": "CCTchat chat server"
    }
}
```

- `launch`: the shell command that starts the app. The desktop shows an
  icon for the installed package and the Packages app gets a **Launch** button.
- `icon.color`: a colour name (`red`, `lime`, `cyan`, `orange`...).
  `icon.art`: three strings of 6 characters drawn on the icon.
- `service`: registered by `apt install` as a NyxOS service (see
  `service list`) and removed by `apt remove`. Servers run in the
  background, with no interface needed.
- Installers must only write inside their own folders (`/lib/<app>`,
  `/etc/<app>`, ...) and must never touch `/startup.lua`, `/boot.json` or
  `/nyxos.lua`. A file written to `/` is moved into `/bin` by `apt` and
  becomes a command.
