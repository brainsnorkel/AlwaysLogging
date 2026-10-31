--[[
    Always Logging

    Turns on encounter logging (the same switch as /encounterlog) whenever you
    enter the game, and by default turns it back on after every loading screen
    if something else switched it off.

    Rules:
      - Entering the game and loading screens only ever turn logging ON.
      - Logging is only turned OFF when you turn Always Logging off yourself
        (/alog off, /alog toggle, or the settings panel).
      - Each character can use the account-wide settings (the default) or keep
        its own, so one character can opt out while the rest keep logging.
]]

AlwaysLogging = AlwaysLogging or {}
local AL = AlwaysLogging

AL.name        = "AlwaysLogging"
AL.displayName = "Always Logging"
AL.version     = "1.0.0"
AL.author      = "@brainsnorkel"

local EM = EVENT_MANAGER
local SV_NAME    = "AlwaysLoggingSV"
local SV_VERSION = 1
local APPLY_NAME = AL.name .. "Apply"

-- Applied a little after each loading screen: Easy Stalking makes its own
-- decision 1000 ms after EVENT_PLAYER_ACTIVATED, and running after it means
-- this addon gets the last word instead of racing it.
local APPLY_DELAY_MS = 1500

AL.defaults = {
    enabled       = true,    -- turn encounter logging on when entering the game
    reapplyOnZone = true,    -- also turn it back on after every loading screen
    chatOnLogin   = true,    -- status line when entering the game
    chatOnZone    = false,   -- status line after every loading screen
    warnOnOff     = true,    -- warn when something else turns logging off
}

-- Only the per-character table carries the scope flag.
local CHARACTER_DEFAULTS = { useAccountWide = true }
for k, v in pairs(AL.defaults) do CHARACTER_DEFAULTS[k] = v end

AL.sv        = nil     -- the active settings table: AL.accountSV or AL.charSV
AL.accountSV = nil
AL.charSV    = nil

AL.entered        = false   -- first EVENT_PLAYER_ACTIVATED since login or /reloadui
AL.applyPending   = false   -- a loading screen happened and AL.Apply has not run yet
AL.applying       = false   -- true while this addon calls SetEncounterLogEnabled
AL.lastState      = nil     -- last observed IsEncounterLogEnabled()
AL.warnedThisZone = false

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------
local PREFIX = "|c4FC3F7Always Logging|r: "
local ON     = "|c5FD35FON|r"
local OFF    = "|cFF6060OFF|r"

function AL.Print(text)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(PREFIX .. tostring(text))
    else
        d(PREFIX .. tostring(text))
    end
end

local function ScopeText()
    return AL.charSV.useAccountWide and "account-wide settings" or "this character's own settings"
end

function AL.StatusText()
    local text = "Encounter logging is " .. (IsEncounterLogEnabled() and ON or OFF) .. ". "
    if AL.sv.enabled then
        return text .. "Always Logging is on (" .. ScopeText() .. ")."
    end
    return text .. "Always Logging is off (" .. ScopeText() .. "); /alog on to enable."
end

---------------------------------------------------------------------------
-- Encounter log
---------------------------------------------------------------------------

-- Returns true if the encounter log ended up in the requested state.
local function SetLogging(on)
    AL.applying = true
    SetEncounterLogEnabled(on)
    AL.applying = false
    AL.lastState = IsEncounterLogEnabled()
    return AL.lastState == on
end

local function TurnOn()
    if IsEncounterLogEnabled() then return "already" end
    return SetLogging(true) and "turned_on" or "failed"
end

local FAILED_TEXT = "could not turn encounter logging on. Try /encounterlog."

local function WillTurnOnAtApply()
    return AL.sv.enabled and (not AL.entered or AL.sv.reapplyOnZone)
end

-- Watches every call to SetEncounterLogEnabled, including the game's own
-- /encounterlog command and other addons, so a log that is switched off
-- behind this addon's back gets reported instead of silently lost.
local function OnSetEncounterLogEnabled()
    if AL.applying then return end
    local now = IsEncounterLogEnabled()
    if now == AL.lastState then return end
    AL.lastState = now
    if now or not AL.sv.enabled or not AL.sv.warnOnOff or AL.warnedThisZone then return end
    -- switched off during a loading screen that is about to turn it back on:
    -- AL.Apply reports that, so a warning here would only be noise
    if AL.applyPending and WillTurnOnAtApply() then return end
    -- once per loading screen, so a combat-only logger elsewhere cannot spam chat
    AL.warnedThisZone = true
    if AL.sv.reapplyOnZone then
        AL.Print("encounter logging was turned " .. OFF .. " by /encounterlog or another addon. "
            .. "It will be turned back on after the next loading screen; /alog off to stop that.")
    else
        AL.Print("encounter logging was turned " .. OFF .. " by /encounterlog or another addon. "
            .. "It will be turned back on the next time you log in or /reloadui.")
    end
end

-- Easy Stalking's automatic mode turns logging off outside the places it is
-- set to log, which undoes this addon on every loading screen.
local function WarnAboutEasyStalking()
    local ez = EzStalking
    if ez and ez.settings and ez.settings.log and ez.settings.log.enabled then
        AL.Print("Easy Stalking's automatic logging is also on, and it turns logging off outside the "
            .. "places it is set to log. Turn off one of the two to stop them overriding each other.")
    end
end

---------------------------------------------------------------------------
-- Entering the game / loading screens
---------------------------------------------------------------------------
function AL.Apply()
    local firstEntry = not AL.entered
    local result = "already"
    if WillTurnOnAtApply() then
        result = TurnOn()
    end
    AL.lastState = IsEncounterLogEnabled()
    AL.entered = true
    AL.applyPending = false
    AL.warnedThisZone = false

    if result == "failed" then
        AL.Print(FAILED_TEXT)
    elseif result == "turned_on" then
        AL.Print("turned encounter logging " .. ON .. ".")
    elseif (firstEntry and AL.sv.chatOnLogin) or AL.sv.chatOnZone then
        AL.Print(AL.StatusText())
    end

    if firstEntry and AL.sv.enabled then
        WarnAboutEasyStalking()
    end
end

local function OnPlayerActivated()
    AL.applyPending = true
    -- coalesce back-to-back loading screens into one apply
    EM:UnregisterForUpdate(APPLY_NAME)
    EM:RegisterForUpdate(APPLY_NAME, APPLY_DELAY_MS, function()
        EM:UnregisterForUpdate(APPLY_NAME)
        AL.Apply()
    end)
end

---------------------------------------------------------------------------
-- Settings changes (shared by the slash command and the settings panel)
---------------------------------------------------------------------------
function AL.SetEnabled(enabled)
    AL.sv.enabled = enabled
    local ok
    if enabled then
        AL.warnedThisZone = false   -- an explicit "on" deserves to hear about the next switch-off
        ok = TurnOn() ~= "failed"
    else
        ok = not IsEncounterLogEnabled() or SetLogging(false)
    end
    if not ok then
        AL.Print(enabled and FAILED_TEXT or "could not turn encounter logging off. Try /encounterlog.")
        return
    end
    AL.Print("Always Logging " .. (enabled and ON or OFF) .. ". Encounter logging is "
        .. (IsEncounterLogEnabled() and ON or OFF) .. ".")
end

function AL.ToggleEnabled()
    AL.SetEnabled(not AL.sv.enabled)
end

-- Switching scope never turns logging off; it only turns it on if the newly
-- active settings say so.
function AL.SetAccountWide(useAccountWide)
    AL.charSV.useAccountWide = useAccountWide
    AL.sv = useAccountWide and AL.accountSV or AL.charSV
    if AL.sv.enabled and TurnOn() == "failed" then
        AL.Print(FAILED_TEXT)
    end
    AL.Print("now using " .. ScopeText() .. ". " .. AL.StatusText())
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function PrintHelp()
    AL.Print("commands:")
    AL.Print("/alog - toggle Always Logging on or off")
    AL.Print("/alog on | off - turn it on (logging starts now) or off (logging stops now)")
    AL.Print("/alog status - show the encounter logging state")
    AL.Print("/alog account - use the account-wide settings on this character")
    AL.Print("/alog character - give this character its own settings")
end

local function SlashHandler(args)
    local cmd = (args or ""):lower():match("^%s*(.-)%s*$")
    if cmd == "" or cmd == "toggle" then
        AL.ToggleEnabled()
    elseif cmd == "on" then
        AL.SetEnabled(true)
    elseif cmd == "off" then
        AL.SetEnabled(false)
    elseif cmd == "status" then
        AL.Print(AL.StatusText())
    elseif cmd == "account" then
        AL.SetAccountWide(true)
    elseif cmd == "character" or cmd == "char" or cmd == "toon" then
        AL.SetAccountWide(false)
    else
        PrintHelp()
    end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local function OnAddOnLoaded(_, addonName)
    if addonName ~= AL.name then return end
    EM:UnregisterForEvent(AL.name, EVENT_ADD_ON_LOADED)

    AL.accountSV = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, nil, AL.defaults)
    AL.charSV    = ZO_SavedVars:NewCharacterIdSettings(SV_NAME, SV_VERSION, nil, CHARACTER_DEFAULTS)
    AL.sv        = AL.charSV.useAccountWide and AL.accountSV or AL.charSV
    AL.lastState = IsEncounterLogEnabled()

    ZO_PostHook("SetEncounterLogEnabled", OnSetEncounterLogEnabled)
    EM:RegisterForEvent(AL.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    if AL.Settings and AL.Settings.Create then
        AL.Settings.Create()
    end

    SLASH_COMMANDS["/alwayslogging"] = SlashHandler
    SLASH_COMMANDS["/alog"] = SlashHandler
end

EM:RegisterForEvent(AL.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
