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
        "entry": "bin/example.lua",
        "installer": "install.lua",
        "uninstaller": "uninstall.lua"
    },

    "server": {
        "entry": "startup.lua",
        "installer": "install.lua",
        "uninstaller": "uninstall.lua"
    },
}


# 💪 Supported types

## Client ( for NyxOS installation )
## Server ( for empty computer installation )


# 📓 Required files

    - `app.json`
    - `LICENSE.txt`
    - `ORIGIN.md`
    - `control.lua
    - `install.lua`
    - `uninstall.lua`