-- Always Logging settings panel (LibAddonMenu-2.0). Everything is also reachable via /alog.

local AL = AlwaysLogging
AL.Settings = AL.Settings or {}
local S = AL.Settings

function S.Create()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = AL.name .. "Options"
    local panelData = {
        type = "panel",
        name = AL.displayName,
        displayName = "|c4FC3F7Always Logging|r",
        author = AL.author,
        version = AL.version,
        website = "https://github.com/brainsnorkel/AlwaysLogging",
        slashCommand = "/alogsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    -- getFunc/setFunc read AL.sv on every call because it is swapped when the
    -- scope checkbox changes; capturing it once would edit the wrong table.
    local function Setting(key, name, tooltip, extra)
        local option = {
            type = "checkbox",
            name = name,
            tooltip = tooltip,
            getFunc = function() return AL.sv[key] end,
            setFunc = function(v) AL.sv[key] = v end,
            default = AL.defaults[key],
        }
        for k, v in pairs(extra or {}) do option[k] = v end
        return option
    end

    local function Disabled() return not AL.sv.enabled end

    local options = {
        {
            type = "description",
            text = "Turns on encounter logging (/encounterlog) every time you enter the game. Logging is only "
                .. "ever turned off when you turn Always Logging off. Chat commands: /alog or /alwayslogging.",
        },
        { type = "header", name = "Settings scope" },
        {
            type = "checkbox",
            name = "Use account-wide settings",
            tooltip = "On: this character uses the settings shared by every character on the account. "
                .. "Off: this character keeps its own settings, so it can log differently from the rest.",
            getFunc = function() return AL.charSV.useAccountWide end,
            setFunc = function(v) AL.SetAccountWide(v) end,
            default = true,
        },
        { type = "header", name = "Logging" },
        Setting("enabled", "Always log encounters",
            "Turn encounter logging on when you enter the game. Turning this off stops logging now.",
            { setFunc = function(v) AL.SetEnabled(v) end }),
        Setting("reapplyOnZone", "Keep it on after loading screens",
            "If /encounterlog or another addon turns logging off, turn it back on after the next loading "
                .. "screen. Off: only turn it on when you log in or /reloadui.",
            { disabled = Disabled }),
        { type = "header", name = "Chat messages" },
        Setting("chatOnLogin", "Status when entering the game",
            "Say whether encounter logging is on after you log in or /reloadui."),
        Setting("chatOnZone", "Status after every loading screen",
            "Say whether encounter logging is on after every loading screen, even when nothing changed."),
        Setting("warnOnOff", "Warn when logging is turned off",
            "Say so when /encounterlog or another addon turns logging off while Always Logging is on. "
                .. "At most once per loading screen.",
            { disabled = Disabled }),
        { type = "header", name = "On-screen indicator" },
        Setting("indicator", "Show indicator",
            "Shows \"Encounter log: on\" in green while logging. \"Encounter log: off\" is red when Always "
                .. "Logging should be logging but is not, and amber when logging is off on purpose.",
            { setFunc = function(v) AL.SetIndicatorShown(v) end }),
        Setting("locked", "Lock position",
            "Unlock, close the settings, show the cursor and drag the indicator. Then lock it here or with "
                .. "/alog lock. While unlocked it shows even if switched off.",
            { setFunc = function(v) AL.SetIndicatorLocked(v) end }),
        {
            type = "button",
            name = "Reset position",
            tooltip = "Put the indicator back beside the compass.",
            func = function() AL.Indicator.ResetPosition() end,
            width = "half",
        },
    }

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, options)
end
