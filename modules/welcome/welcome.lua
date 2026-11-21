-- welcome: greets each player as they enter the world. A starting point for
-- your own modules: the map server calls on_login(player) after the game's
-- own onLogin, with the same player object as scripts/lua/player.lua.
--
-- The lines come from settings/welcome.toml when the server has one:
--
--   lines = [
--     "Welcome to XIVLegacy!",
--     "Found a bug? Press Ctrl+F12 to send a report.",
--   ]
--
-- Each quoted string after `lines` is one chat line (no escapes inside the
-- quotes). Without the file, players get the one line below.

require("global")

local DEFAULT_LINES = { "Welcome to XIVLegacy!" }

-- The quoted strings of the `lines = [...]` array in a welcome.toml text;
-- full-line # comments are skipped. Empty when there is none.
function welcome_lines_from(text)
    local lines = {}
    local list = text:gsub("[^\n]*", function(l)
        if l:match("^%s*#") then return "" end
    end):match("lines%s*=%s*(%b[])")
    if list then
        for s in list:gmatch('"([^"]*)"') do
            table.insert(lines, s)
        end
    end
    return lines
end

local function welcome_lines()
    local f = io and io.open("settings/welcome.toml", "r")
    if not f then return DEFAULT_LINES end
    local text = f:read("*a") or ""
    f:close()
    local lines = welcome_lines_from(text)
    if #lines == 0 then return DEFAULT_LINES end
    return lines
end

function on_login(player)
    for _, line in ipairs(welcome_lines()) do
        player:SendMessage(MESSAGE_TYPE_SYSTEM, "", line)
    end
end
