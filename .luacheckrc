-- Luacheck configuration for ESO addon development
std = "lua51"
max_line_length = 120
self = false
unused_args = false

globals = {
    "AlwaysLogging",
    "SLASH_COMMANDS",
}

-- The harness stubs the game API, so it defines globals by design, and it
-- keeps one scenario per line.
files["tests/run.lua"] = { allow_defined_top = true, max_line_length = false, ignore = { "1", "311" } }

read_globals = {
    -- ESO core
    "EVENT_MANAGER",
    "CHAT_ROUTER",
    "ZO_SavedVars",
    "ZO_PostHook",
    "d",

    -- ESO events
    "EVENT_ADD_ON_LOADED",
    "EVENT_PLAYER_ACTIVATED",

    -- ESO functions
    "IsEncounterLogEnabled",
    "SetEncounterLogEnabled",

    -- ESO UI
    "WINDOW_MANAGER",
    "GuiRoot",
    "HUD_SCENE",
    "HUD_UI_SCENE",
    "ZO_HUDFadeSceneFragment",
    "CT_LABEL",
    "CT_BACKDROP",
    "TOP",
    "BOTTOM",
    "CENTER",
    "DL_OVERLAY",
    "DT_HIGH",

    -- Libraries and other addons
    "LibAddonMenu2",
    "EzStalking",
}
