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