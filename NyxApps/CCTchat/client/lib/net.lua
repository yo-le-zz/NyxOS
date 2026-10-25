-- CCTchat - Reseau cote client

local M = {}
local PROTOCOL = "cctchat"

function M.open()
    local modemSide = nil
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "modem" then
            modemSide = side
            break
        end
    end
    if not modemSide then
        error("Aucun modem trouve ! Attachez un modem (filaire ou sans fil) a l'ordinateur.")
    end
    if not rednet.isOpen(modemSide) then
        rednet.open(modemSide)
    end
    return modemSide
end

function M.findServer()
    return rednet.lookup(PROTOCOL, "cct-serv")
end

return M
