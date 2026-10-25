-- control.lua : package metadata, next to install.lua.
-- Optional but recommended: the equivalent of the "control" file in a
-- Debian .deb package. apt.lua reads it automatically if present (see
-- docs/PACKAGING.md).

return {
    name = "hello",
    version = "1.0.0",
    description = "Adds the 'hello' command, which prints a message.",
    depends = {}, -- names of other required NyxOS packages (informative for now)
}
