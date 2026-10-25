-- /lib/permissions.lua : NyxOS permission manager (sudo-style)
--
-- NyxOS users already carry a permanent `admin` flag (see /lib/users.lua)
-- for accounts that can always manage users/packages/services. On top of
-- that, this module adds a Linux-style *sudo session*: any admin user can
-- run `sudo <command>`, re-confirm their own password once, and NyxOS
-- will remember that for a short time window (like the real sudo
-- timestamp cache) so they don't have to retype it for every privileged
-- command in a row.
--
-- Sessions are stored in /var/run/sudo.lua (volatile -- cleared on
-- shutdown, just like /var/run/session.lua).

local nyxlib = dofile("/lib/nyxlib.lua")
local users  = dofile("/lib/users.lua")

local permissions = {}

local SUDO_PATH = "/var/run/sudo.lua"
local SUDOERS_PATH = "/etc/sudoers.lua"

-- Default sudo session length: 5 minutes of inactivity, same ballpark as
-- the default `timestamp_timeout` on real Linux sudo.
permissions.DEFAULT_TIMEOUT = 5 * 60 * 1000

local function loadSudoState()
    return nyxlib.loadTable(SUDO_PATH)
end

local function saveSudoState(state)
    nyxlib.saveTable(SUDO_PATH, state)
end

-- Is `username` allowed to use sudo at all? By default, any account
-- with the permanent `admin` flag. /etc/sudoers.lua can optionally
-- restrict this further to an explicit list: return { "alice", "bob" }.
function permissions.isSudoer(username)
    if not username then return false end
    local user = users.find(username)
    if not user or not user.admin then
        return false
    end
    if fs.exists(SUDOERS_PATH) then
        local ok, list = pcall(dofile, SUDOERS_PATH)
        if ok and type(list) == "table" and #list > 0 then
            for _, name in ipairs(list) do
                if name == username then return true end
            end
            return false
        end
    end
    return true
end

-- True if `username` currently has a live sudo session (already
-- authenticated within the timeout window).
function permissions.sudoActive(username)
    if not username then return false end
    local state = loadSudoState()
    local entry = state[username]
    if not entry then return false end
    if os.epoch("utc") >= entry.expiresAt then
        return false
    end
    return true
end

-- Seconds remaining on the current sudo session, or 0.
function permissions.sudoRemaining(username)
    local state = loadSudoState()
    local entry = state[username]
    if not entry then return 0 end
    local remaining = math.floor((entry.expiresAt - os.epoch("utc")) / 1000)
    return math.max(0, remaining)
end

-- Starts/refreshes a sudo session for `username` for `timeoutMs`
-- (defaults to permissions.DEFAULT_TIMEOUT).
function permissions.grantSudo(username, timeoutMs)
    local state = loadSudoState()
    state[username] = { expiresAt = os.epoch("utc") + (timeoutMs or permissions.DEFAULT_TIMEOUT) }
    saveSudoState(state)
end

-- Drops a user's sudo session immediately ("sudo -k").
function permissions.revokeSudo(username)
    local state = loadSudoState()
    state[username] = nil
    saveSudoState(state)
end

-- True if `username` currently has elevated rights: either a permanent
-- administrator account, or an active sudo session. This is the check
-- privileged commands (adduser, deluser, service, apt tool, reset...)
-- should use instead of looking at `.admin` directly.
function permissions.isPrivileged(username)
    if not username then return false end
    local user = users.find(username)
    if user and user.admin then
        return true
    end
    return permissions.sudoActive(username)
end

-- Convenience for scripts: returns ok, errorMessage. Checks the
-- currently logged in session user.
function permissions.requirePrivileged(actionDescription)
    local session = nyxlib.loadSession()
    if not session.username then
        return false, "No active session (logged in via the recovery shell?)."
    end
    if not permissions.isPrivileged(session.username) then
        return false, "Permission denied: " .. (actionDescription or "this action") ..
            " requires an administrator or an active 'sudo' session."
    end
    return true
end

return permissions
