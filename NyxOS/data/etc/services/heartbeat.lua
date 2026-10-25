return {
    name = "heartbeat",
    description = "Writes an uptime line to the system log every 5 minutes.",
    exec = "/lib/services/heartbeat.lua",
    autostart = false,
}
