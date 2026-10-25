# Building NyxOS packages

NyxOS packages come in two flavours:

1. **NyxApps registry packages** -- the standard used by
   `github.com/yo-le-zz/NyxOS/NyxApps/*`, installable by name with
   `apt install <name>`. This is the recommended format for anything
   you want to share with the community.
2. **Generic installers** (`.deb`-style) -- a bare `install.lua`
   (optionally with a `control.lua`), installable from a URL or a local
   disk with `apt install <url|path>`. Useful for one-off scripts or
   quick local testing.

Use `mkpkg <name> [client|server|both]` to instantly scaffold a valid
NyxApps-style package (see section 2).

## 1. How `apt install` actually works

Whichever flavour you use, `apt` **really executes** an `install.lua`
(via `shell.run`, not just `dofile`), then looks at **everything that
script touched on disk** while it ran:

- `fs.open(path, "w"/"a")`
- `fs.copy(src, dst)`
- `fs.move(src, dst)`
- `fs.makeDir(folder)`

Everything written is automatically recorded in the
`/etc/apt/installed.lua` manifest, so `apt remove`/`apt purge` can later
clean everything up -- even if your script knows nothing about the
package manager and just writes its files normally.

A file written at the **root** (`fs.open("hello.lua", "w")`) is
automatically moved into `/bin`: the simplest way to ship a new command.

## 2. The `app.json` standard (NyxApps registry)

A registry package lives in its own folder under `NyxApps/` in the
NyxOS repository, and describes itself with an `app.json` at its root:

```json
{
  "name": "cctchat",
  "version": "1.2.0",
  "description": "A simple rednet chat client/server.",
  "author": "someone",
  "type": ["client", "server"],
  "client": {
    "entry": "client/cctchat.lua",
    "installer": "client/install.lua",
    "uninstaller": "client/uninstall.lua"
  },
  "server": {
    "entry": "server/cctchat-server.lua",
    "installer": "server/install.lua",
    "uninstaller": "server/uninstall.lua"
  }
}
```

- `name` -- the identifier used by `apt install <name>` (case-insensitive).
- `version` -- compared against the installed version by `apt update`.
- `type` -- which variants exist: `["client"]`, `["server"]`, or both.
- For each declared type, a matching top-level key (`client`/`server`)
  gives that variant's `entry` (what the app is launched with once
  installed -- shown by `apt info`), `installer` and `uninstaller`
  (paths relative to the package root).

Folder layout matching the example above:

```
NyxApps/CCTchat/
├── app.json
├── client/
│   ├── install.lua
│   ├── uninstall.lua
│   └── cctchat.lua
└── server/
    ├── install.lua
    ├── uninstall.lua
    └── cctchat-server.lua
```

Scaffold this automatically:

```
mkpkg cctchat both
```

Once published to `github.com/yo-le-zz/NyxOS` under `NyxApps/`, anyone
can run:

```
apt install cctchat            -- prompts for client/server if both exist
apt install cctchat client
apt search chat
apt update cctchat             -- reinstalls if app.json's version changed
```

`apt` discovers packages by listing `NyxApps/` via the GitHub API and
reading each folder's `app.json` (both responses are cached locally for
an hour in `/var/apt/*-cache.lua` to avoid hammering the API), then
downloads every file under the chosen variant's folder before running
its `installer`.

## 3. Generic installers (`.deb`-style, URL or disk)

For quick/local packages that don't need to live in the NyxApps
registry, the original, simpler format still works.

### Minimal package

```
my-package/
└── install.lua
```

```lua
-- install.lua
local bin = fs.open("hello.lua", "w")   -- written at the root -> moved to /bin
bin.write([[print("Hello!")]])
bin.close()

local conf = fs.open("/etc/hello.conf", "w")  -- absolute path -> stays put
conf.write("message=Hello\n")
conf.close()
```

This is exactly the example package in `exemples/paquet_hello/`.

### Optional metadata: `control.lua`

```lua
-- control.lua
return {
    name = "hello",
    version = "1.0.0",
    description = "Adds the 'hello' command, which prints a message.",
    depends = {},  -- names of other NyxOS packages (informative)
}
```

If present, `name` becomes the package's default name and
`version`/`description` show up during install and in `apt info`/`apt
list`.

### Multi-file packages

```
my-package/
├── install.lua
├── control.lua
├── uninstall.lua
└── lib/
    └── myutil.lua
```

```lua
-- install.lua
local here = fs.getDir(shell.getRunningProgram())

fs.makeDir("/lib/myutil")
fs.copy(fs.combine(here, "lib/myutil.lua"), "/lib/myutil/myutil.lua")

local cmd = fs.open("mycommand.lua", "w")
cmd.write([[
local util = dofile("/lib/myutil/myutil.lua")
util.run(...)
]])
cmd.close()

print("Installed! Type 'mycommand' to use it.")
```

### Distribution

**a) A disk in-game.** Put `install.lua` (and optionally `control.lua`,
`uninstall.lua`, `lib/...`) at the root of a CC: Tweaked disk, insert it,
then:

```
apt install ./disk
```

**b) A URL.** Host the package folder somewhere reachable over HTTP
(GitHub raw, your own server...), then:

```
apt install https://example.com/my-package/install.lua
```

This mode only downloads `install.lua` itself (plus `control.lua` if it
sits right next to it): if your package needs sibling files, have
`install.lua` fetch them itself with `http.get`, or distribute via a
disk instead.

## 4. Uninstall logic: `uninstall.lua`

Optional for either package flavour. `apt` runs it (with confirmation)
before falling back to automatic cleanup of everything tracked in the
manifest:

```lua
-- uninstall.lua
if fs.exists("/lib/myutil") then
    fs.delete("/lib/myutil")
end
print("my-package cleaned up.")
```

Without one, the default behaviour is usually enough:
- `apt remove` deletes the package's files **except** anything under
  `/etc` (config is kept, like real `apt`);
- `apt purge` deletes everything, including `/etc` and empty folders
  the package created.

## 5. Shared/global libraries: `apt tool`

If your package depends on a big shared library (Basalt being the
obvious example), don't bundle your own copy -- depend on the global
one instead:

```lua
local toolkit = dofile("/lib/toolkit.lua")
local basalt = toolkit.require("basalt")  -- nil, err if not installed
```

Users install it once with `apt tool install basalt` (reuses the
system's own `/lib/basalt.lua` automatically, no download needed), and
every package sharing that dependency uses the same on-disk copy.

## 6. Checklist before publishing

- [ ] `install.lua` writes its files with `fs.open`/`fs.copy`/`fs.makeDir`
      (nothing "hidden" that `apt` couldn't track).
- [ ] A file meant to become a command is either written at the root
      (auto-moved to `/bin`) or explicitly placed in `/bin`.
- [ ] `app.json` (registry packages) or `control.lua` (generic
      packages) gives a clear name, version and description.
- [ ] `uninstall.lua` (optional) cleans up anything the default
      `apt remove`/`purge` behaviour wouldn't handle correctly.
- [ ] Tested locally with `apt install ./disk` (generic) or by pointing
      `apt install <name>` at a fork/branch before publishing.
