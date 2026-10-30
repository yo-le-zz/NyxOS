return {
    name = "dns",
    description = "Name server: resolves names from /etc/hosts for the network.",
    exec = "/lib/services/dns.lua",
    autostart = false,
}
