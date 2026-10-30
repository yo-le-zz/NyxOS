return {
    name = "dhcpd",
    description = "DHCP server: leases addresses from /etc/dhcpd.lua.",
    exec = "/lib/services/dhcpd.lua",
    autostart = false,
}
