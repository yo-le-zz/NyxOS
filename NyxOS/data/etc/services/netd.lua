return {
    name = "netd",
    description = "Network daemon: address, ping, DHCP client, packet forwarding.",
    exec = "/lib/services/netd.lua",
    autostart = true,
}
