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

# 🖥️ Desktop & server integration (NyxOS 1.1.0+, pixel icons 1.1.1+)

Each variant (`client` / `server`) of `app.json` may also declare:

```json
"client": {
    "entry": "ccrf.lua",
    "installer": "install.lua",
    "uninstaller": "uninstall.lua",
    "launch": "ccrf",
    "icon": {
        "palette": { "r": "red", "w": "white" },
        "pixels": [
            ".......rr.......",
            "......rrrr......",
            "......rwwr......",
            ".....rrwwrr.....",
            "....rrrrrrrr....",
            "....rrrwwrrr...."
        ]
    }
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
- `icon`: **the app draws its icon as pixels, NyxOS renders it** (like
  MineOS icons). `pixels` = rows of up to 16 x 9 pixels (one character per
  pixel, `.` or space = transparent), `palette` maps each character to a
  colour name (`red`, `lime`, `lightBlue`...) or `#rrggbb` (mapped to the
  nearest of the 16 screen colours). Smaller images are centred.
  Each 2 x 3 block of pixels becomes one character, so a cell can show at
  most two colours: keep details bold. Old `{ "color", "art" }` icons still work.
  An installer can also register it from code:
  `dofile("/lib/nyxapi.lua").registerIcon("name", { palette = ..., pixels = ... })`
  (stored in `/etc/icons/<name>.lua`).
- `service`: registered by `apt install` as a NyxOS service (see
  `service list`) and removed by `apt remove`. Servers run in the
  background, with no interface needed.
- Installers must only write inside their own folders (`/lib/<app>`,
  `/etc/<app>`, ...) and must never touch `/startup.lua`, `/boot.json` or
  `/nyxos.lua`. A file written to `/` is moved into `/bin` by `apt` and
  becomes a command.

# 🌐 Network & ssh (NyxOS 1.4.0+)

NyxOS has a virtual IP network over rednet (`/lib/netstack.lua`): addresses
(`ifconfig`), names (`/etc/hosts`, service `dns`), DHCP (service `dhcpd`),
`ping`, `netstat`, and sockets for packages:

```lua
local net = dofile("/lib/netstack.lua")
local l = net.listen(8080, "myserver"); local c = l:accept(10)   -- server
local c = net.connect("server1", 8080); c:send({...}); c:receive(5) -- client
```

A computer can be described by `/etc/servers/<name>.lua`:
`return { name="web1", ip="10.0.1.7", gateway="10.0.1.1", dns="10.0.1.2", ports={[80]="web"}, services={"dns"} }`
(listed services are started by `netd`). The `ssh` package (`apt install ssh`)
adds `ssh`, `scp`, `ssh-keygen`, `ssh-copy-id` and the `sshd` service.
Nothing is encrypted on the network: key logins never send the secret, password
logins do send the password in clear.

# 🌍 http / https (NyxOS 1.5.0+)

```lua
local web = dofile("/lib/nyxhttp.lua")
local res, err = web.get("http://myserver/index.html")   -- res.status, res.headers, res.body
web.post(url, data)
web.serve({ port = 80 }, function(req) return { status = 200, body = "hi" } end)
```
`https://` works on the NyxOS network once the server certificate has been
imported with `nyxcert import`. Unknown hosts go to the real internet when the
CC `http` API is enabled.

# 🎨 Package icons

`client.icon` in `app.json` is a pixel icon (`palette` + 9 rows of 16 characters).
Without it, the marketplace generates a unique icon from the package name.
