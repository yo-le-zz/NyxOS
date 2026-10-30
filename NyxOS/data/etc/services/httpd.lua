return {
    name = "httpd",
    description = "Web server (http/https) for the NyxOS network, serves /srv/www.",
    exec = "/lib/services/httpd.lua",
    autostart = false,
}
