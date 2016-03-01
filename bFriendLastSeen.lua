-- =============================================================================
--  bFriendLastSeen
--    by: BurstBiscuit
-- =============================================================================

require "math"
require "table"
require "unicode"
require "lib/lib_Callback2"
require "lib/lib_ChatLib"
require "lib/lib_Debug"
require "lib/lib_Slash"
require "lib/lib_Time"

Debug.EnableLogging(false)


-- =============================================================================
--  Variables
-- =============================================================================

local g_FriendsMap = {}
local g_FriendsInfo = {}
local CB2_PrintDebugInfo


-- =============================================================================
--  Functions
-- =============================================================================

function Notification(message)
    ChatLib.Notification({text = "[bFriendLastSeen] " .. tostring(message)})
end

--[[
 -- Returns a string of the timestamp difference supplied
 --  "3 days, 13 hours, 48 seconds"
  ]]
function GetTimeDifferenceString(timestamp)
    local now = tonumber(System.GetLocalUnixTime())
    local times = {86400, 3600, 60, 1}
    local words = {"day", "hour", "minute", "second"}
    local diff = now - timestamp
    local str = ""
    local s = function(c) if (c > 1) then return "s" else return "" end end

    for k, v in pairs(times) do
        local val = math.floor(diff / v)

        if (val and val > 0) then
            if (str ~= "") then
                str = str .. ", "
            end

            str = str .. val .. " " .. words[k] .. s(val)
        end

        diff = diff % v
    end

    return str
end

--[[
 -- Returns a string containing all the friend info, or an error message
  ]]
function GetFriendInfoString(name)
    if (name and g_FriendsMap[name]) then
        Debug.Table("friendInfo", g_FriendsInfo[g_FriendsMap[name]])

        local friendInfo = g_FriendsInfo[g_FriendsMap[name]]
        local lastSeenString = "\n\tLast seen: <unknown>"
        local zoneString = ""

        if (friendInfo.last_seen_at) then
            local lastSeenInfo = Time.GetFullDate(friendInfo.last_seen_at) .. " " .. Time.GetTimeString(friendInfo.last_seen_at)
            lastSeenString = unicode.gsub(lastSeenString, "<unknown>", lastSeenInfo .. " (" .. GetTimeDifferenceString(friendInfo.last_seen_at) .. " ago)")
        end

        if (friendInfo.last_zone_id) then
            local zoneInfo = Game.GetZoneInfo(friendInfo.last_zone_id)
            zoneString = "\n\tZone: <unknown>"

            if (zoneInfo.main_title) then
                zoneString = unicode.gsub(zoneString, "<unknown>", zoneInfo.main_title)
            end
        end

        return ChatLib.EncodePlayerLink(friendInfo.player_name) .. tostring(lastSeenString) .. tostring(zoneString)
    else
        return "Data for " .. tostring(name) .. " was not found."
    end
end

function PrintDebugInfo()
    Debug.Table("g_FriendsInfo", g_FriendsInfo)
    Debug.Table("g_FriendsMap", g_FriendsMap)
end

function OnSlashCommand(args)
    if (args[1]) then
        Notification(GetFriendInfoString(normalize(args[1])))
    else
        Notification("Usage: '/bfls <player_name>'\n\tExample: '/bfls BurstBiscuit'")
    end
end


-- =============================================================================
--  Events
-- =============================================================================

--[[
 -- ON_COMPONENT_LOAD
  ]]
function OnComponentLoad()
    LIB_SLASH.BindCallback({
        slash_list = "bfriendlastseen, bfls",
        description = "bFriendLastSeen",
        func = OnSlashCommand,
        autocomplete_name = 1
    })

    CB2_PrintDebugInfo = Callback2.Create()
    CB2_PrintDebugInfo:Bind(PrintDebugInfo)
end

--[[
 -- ON_FRIENDS_LOADED
  ]]
function OnFriendsLoaded(args)
    Debug.Table("ON_FRIENDS_LOADED", args)

    if (args and args.friends) then
        for _, friend in pairs(args.friends) do
            if (friend.status_type and friend.status_type == "FRIEND") then
                if (friend.player_name) then
                    g_FriendsInfo[friend.unique_name] = friend
                    g_FriendsMap[normalize(friend.player_name)] = friend.unique_name
                else
                    Debug.Warn("Missing player_name:", friend)
                end
            end
        end

        -- make sure to only print debug info once when <= 50 results, another page might still come in
        if (#args.friends <= tonumber(System.GetCvar("friends_list.per_page"))) then
            if (CB2_PrintDebugInfo:Pending()) then
                CB2_PrintDebugInfo:Reschedule(1)
            else
                CB2_PrintDebugInfo:Schedule(1)
            end
        end
    end
end

--[[
 -- ON_FRIEND_ADDED
  ]]
function OnFriendAdded(args)
    Debug.Table("ON_FRIEND_ADDED", args)

    if (args and args.unique_name and args.player_name) then
        Debug.Log("Adding friend info and mapping:", args.unique_name)
        g_FriendsMap[normalize(args.player_name)] = args.unique_name
        g_FriendsInfo[args.unique_name] = {}
    end
end

--[[
 -- ON_FRIEND_REMOVED
  ]]
function OnFriendRemoved(args)
    Debug.Table("ON_FRIEND_REMOVED", args)

    if (args and args.unique_name and args.player_name) then
        Debug.Log("Removing friend info and mapping:", args.unique_name)
        g_FriendsMap[normalize(args.player_name)] = nil
        g_FriendsInfo[args.unique_name] = nil
    end
end

--[[
 -- ON_FRIEND_STATUS_CHANGED
  ]]
function OnFriendStatusChanged(args)
    Debug.Table("ON_FRIEND_STATUS_CHANGED", args)

    if (args.unique_name) then
        local onlineInfo = Friends.GetOnline(args.unique_name) or false
        Debug.Table("onlineInfo", onlineInfo)

        if (g_FriendsMap[args.unique_name] and onlineInfo) then
            -- Update information from online friend
            Debug.Log("Updating friend info for online friend:", args.unique_name)
            g_FriendsInfo[g_FriendsMap[args.unique_name]].player_name = onlineInfo.player_name
            g_FriendsInfo[g_FriendsMap[args.unique_name]].last_seen_at = tonumber(System.GetLocalUnixTime())
            g_FriendsInfo[g_FriendsMap[args.unique_name]].last_zone_id = onlineInfo.zone
        elseif (g_FriendsMap[args.unique_name]) then
            -- Update last seen timestamp
            Debug.Log("Updating friend info for offline friend:", args.unique_name)
            g_FriendsInfo[g_FriendsMap[args.unique_name]].last_seen_at = tonumber(System.GetLocalUnixTime())
        else
            Debug.Warn("No information for friend:", args)
        end
    else
        Debug.Error("Missing unique_name:", args)
    end
end
