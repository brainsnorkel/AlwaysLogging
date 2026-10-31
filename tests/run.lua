-- Offline harness: stubs enough of the ESO API to drive Always Logging under plain Lua.
local ADDON = (arg and arg[0] and arg[0]:match("^(.*)/tests/") or ".") .. "/"
LOG = {}
function d(...) LOG[#LOG+1] = table.concat({...}, " ") end
CHAT_ROUTER = { AddSystemMessage = function(_, t) d(t) end }
EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED = 1, 2

-- the game's encounter log switch
ENCOUNTER_LOG, LOG_REFUSES = false, false
local function GameSetEncounterLogEnabled(on)
  if LOG_REFUSES then return false end
  ENCOUNTER_LOG = on and true or false; return true
end
function IsEncounterLogEnabled() return ENCOUNTER_LOG end

-- ZO_PostHook as the game defines it
function ZO_PostHook(obj, name, hook)
  if type(obj) == "string" then hook, name, obj = name, obj, _G end
  local orig = obj[name]
  if type(orig) == "function" then
    obj[name] = function(...) local r = { orig(...) }; hook(...); return unpack(r) end
  end
end

-- saved variables survive between simulated logins, keyed like the game keys them
SAVED, CHAR_ID = { chars = {} }, "char1"
local function fill(t, defaults) for k, v in pairs(defaults) do if t[k] == nil then t[k] = v end end; return t end
ZO_SavedVars = {
  NewAccountWide = function(_, _, _, _, defaults) SAVED.account = fill(SAVED.account or {}, defaults); return SAVED.account end,
  NewCharacterIdSettings = function(_, _, _, _, defaults)
    SAVED.chars[CHAR_ID] = fill(SAVED.chars[CHAR_ID] or {}, defaults); return SAVED.chars[CHAR_ID] end,
}

local handlers, updates = {}, {}
EVENT_MANAGER = {
  RegisterForEvent = function(_, n, ev, fn) handlers[ev] = handlers[ev] or {}; handlers[ev][n] = fn end,
  UnregisterForEvent = function(_, n, ev) if handlers[ev] then handlers[ev][n] = nil end end,
  RegisterForUpdate = function(_, n, ms, fn) updates[n] = { ms = ms, fn = fn } end,
  UnregisterForUpdate = function(_, n) updates[n] = nil end,
}
local function FIRE(ev, ...) for _, fn in pairs(handlers[ev] or {}) do fn(ev, ...) end end
local function PENDING() return updates["AlwaysLoggingApply"] ~= nil end
-- let the apply delay (and one indicator poll) elapse
local function WAIT() local due = {} for _, u in pairs(updates) do due[#due+1] = u end; for _, u in ipairs(due) do u.fn(0) end end
LibAddonMenu2 = { RegisterAddonPanel = function() end, RegisterOptionControls = function(_, _, o) LAM_OPTS = o end }

-- UI controls: just enough state to see text, colour, visibility, lock and position
CT_LABEL, CT_BACKDROP, TOP, BOTTOM, CENTER, DL_OVERLAY, DT_HIGH = 1, 2, 3, 4, 5, 1, 1
local function ctl(name)
  local c = { name = name, hidden = false, x = 0, y = 0, w = 0, h = 0, handlers = {} }
  for _, m in ipairs({ "SetClampedToScreen", "SetDrawLayer", "SetDrawTier", "SetAnchorFill", "SetCenterColor", "SetEdgeColor", "SetEdgeTexture", "SetFont" }) do c[m] = function() end end
  function c:SetHandler(ev, fn) self.handlers[ev] = fn end
  function c:SetHidden(h) self.hidden = h end
  function c:SetText(t) self.text = t end
  function c:SetColor(r, g, b) self.color = { r, g, b } end
  function c:SetDimensions(w, h) self.w, self.h = w, h end
  function c:SetMovable(m) self.movable = m end
  function c:SetMouseEnabled(m) self.mouse = m end
  function c:ClearAnchors() self.anchor = nil end
  function c:SetAnchor(p, rel, rp, x, y) self.anchor = { p, rel, rp, x, y }; if rel == GuiRoot then self.x, self.y = x, y end end
  function c:GetTextWidth() return 0 end   -- not laid out yet, as at creation in the game
  function c:GetCenter() return 960 + self.x, self.y + self.h / 2 end
  function c:GetTop() return self.y end
  return c
end
GuiRoot = ctl("GuiRoot")
function GuiRoot:GetCenter() return 960, 540 end
function GuiRoot:GetTop() return 0 end
WINDOW_MANAGER = { CreateTopLevelWindow = function(_, n) return ctl(n) end, CreateControl = function(_, n) return ctl(n) end }
ZO_HUDFadeSceneFragment = { New = function(_, c) return { control = c } end }
HUD_SCENE = { AddFragment = function(_, f) FRAGMENTS = (FRAGMENTS or 0) + 1 end }; HUD_UI_SCENE = HUD_SCENE

-- a fresh login (or /reloadui): the game rebuilds every global, then fires the load events
local function LOGIN(charId, opts)
  opts = opts or {}
  handlers, updates, SLASH_COMMANDS, AlwaysLogging, LAM_OPTS = {}, {}, {}, nil, nil
  SetEncounterLogEnabled = GameSetEncounterLogEnabled
  CHAR_ID = charId or "char1"
  if not opts.keepLog then ENCOUNTER_LOG = false end
  dofile(ADDON .. "AlwaysLogging.lua"); dofile(ADDON .. "AlwaysLoggingIndicator.lua"); dofile(ADDON .. "AlwaysLoggingSettings.lua")
  FIRE(EVENT_ADD_ON_LOADED, "SomeOtherAddon"); FIRE(EVENT_ADD_ON_LOADED, "AlwaysLogging")
  FIRE(EVENT_PLAYER_ACTIVATED)
  if not opts.noWait then WAIT() end
  return AlwaysLogging
end
local function ZONE() FIRE(EVENT_PLAYER_ACTIVATED); WAIT() end
local function SLASH(s) SLASH_COMMANDS["/alog"](s) end
local function said(since, text) for i = since + 1, #LOG do if LOG[i]:find(text, 1, true) then return true end end; return false end
local function opt(name) for _, o in ipairs(LAM_OPTS) do if o.name == name then return o end end end

local fails = 0
local function check(c, m) if c then print("  ok   " .. m) else fails = fails + 1; print("  FAIL " .. m) end end

print("-- entering the game")
local n = #LOG
local AL = LOGIN()
check(ENCOUNTER_LOG, "login turns encounter logging on")
check(said(n, "turned encounter logging"), "login says it turned logging on")
check(#LOG == n + 1, "exactly one chat line at login")
check(AL.sv == SAVED.account and SAVED.chars.char1.useAccountWide == true, "account-wide settings by default")
check(type(LAM_OPTS) == "table" and #LAM_OPTS >= 8, "settings panel registered")
n = #LOG; ZONE()
check(ENCOUNTER_LOG and #LOG == n, "loading screen while on: no change, no chat")
n = #LOG; AL = LOGIN(nil, { keepLog = true })
check(ENCOUNTER_LOG and said(n, "Encounter logging is |c5FD35FON") and not said(n, "turned"), "reloadui while on: status, not 'turned on'")

print("-- something else turns logging off")
n = #LOG; SetEncounterLogEnabled(false)
check(not ENCOUNTER_LOG and said(n, "by /encounterlog or another addon") and said(n, "next loading screen"), "warns once")
n = #LOG; SetEncounterLogEnabled(true); SetEncounterLogEnabled(false)
check(#LOG == n, "second switch-off in the same zone is not repeated")
n = #LOG; ZONE()
check(ENCOUNTER_LOG and said(n, "turned encounter logging"), "next loading screen turns it back on")
n = #LOG; SetEncounterLogEnabled(true)
check(#LOG == n, "switching on (already on) says nothing")
n = #LOG; SetEncounterLogEnabled(false)
check(said(n, "another addon"), "warning re-arms after a loading screen")

print("-- races during a loading screen")
SetEncounterLogEnabled(true)
n = #LOG; FIRE(EVENT_PLAYER_ACTIVATED); SetEncounterLogEnabled(false)
check(not said(n, "another addon"), "switched off while the apply is pending: no warning")
WAIT(); check(ENCOUNTER_LOG and said(n, "turned encounter logging"), "pending apply turns it back on")
local applies = 0; local apply = AL.Apply; AL.Apply = function() applies = applies + 1; apply() end
FIRE(EVENT_PLAYER_ACTIVATED); FIRE(EVENT_PLAYER_ACTIVATED)
check(PENDING(), "loading screen schedules an apply")
WAIT(); check(applies == 1 and not PENDING(), "back-to-back loading screens coalesce into one apply")
AL.Apply = apply
n = #LOG; AL = LOGIN(nil, { noWait = true }); SetEncounterLogEnabled(false)
check(not said(n, "another addon"), "off -> off at login (Easy Stalking's pass) is not a change")
WAIT(); check(ENCOUNTER_LOG, "and logging still ends up on")

print("-- keep it on after loading screens: off")
AL.sv.reapplyOnZone = false
n = #LOG; SetEncounterLogEnabled(false)
check(said(n, "log in or /reloadui"), "warning says when it comes back")
ZONE(); check(not ENCOUNTER_LOG, "loading screen leaves it off")
n = #LOG; AL = LOGIN()
check(ENCOUNTER_LOG and said(n, "turned encounter logging"), "but the next login turns it on")
AL.sv.reapplyOnZone = true

print("-- slash commands")
n = #LOG; SLASH("off")
check(not AL.sv.enabled and not ENCOUNTER_LOG, "/alog off disables and stops logging now")
check(said(n, "Always Logging |cFF6060OFF"), "/alog off says so")
n = #LOG; SetEncounterLogEnabled(true); SetEncounterLogEnabled(false)
check(#LOG == n, "no warnings while Always Logging is off")
SetEncounterLogEnabled(true); ZONE()
check(ENCOUNTER_LOG, "while off, a loading screen does not turn logging off")
n = #LOG; AL = LOGIN()
check(not ENCOUNTER_LOG and said(n, "/alog on to enable"), "login while off: stays off, says how to enable")
ENCOUNTER_LOG = true; AL = LOGIN(nil, { keepLog = true })
check(ENCOUNTER_LOG, "login while off never turns logging off")
SetEncounterLogEnabled(false)
n = #LOG; SLASH("")
check(AL.sv.enabled and ENCOUNTER_LOG and said(n, "Always Logging |c5FD35FON"), "/alog toggles back on and starts logging")
SLASH_COMMANDS["/alwayslogging"]("toggle"); check(not AL.sv.enabled, "/alwayslogging toggle")
SLASH("ON"); check(AL.sv.enabled and ENCOUNTER_LOG, "commands are case-insensitive")
n = #LOG; SLASH("  status  "); check(said(n, "Encounter logging is"), "status, with stray spaces")
n = #LOG; SLASH("bogus"); check(said(n, "/alog character"), "unknown command prints help")
SetEncounterLogEnabled(false); SLASH("off"); SLASH("on")
n = #LOG; SetEncounterLogEnabled(false); check(said(n, "another addon"), "/alog on re-arms the switch-off warning")
SLASH("on")

print("-- per-character settings")
n = #LOG; SLASH("character")
check(AL.sv == SAVED.chars.char1 and not SAVED.chars.char1.useAccountWide, "/alog character switches to own settings")
check(said(n, "this character's own settings"), "and says so")
SLASH("off")
check(SAVED.account.enabled and not SAVED.chars.char1.enabled, "turning off a character leaves the account on")
AL = LOGIN("char2")
check(ENCOUNTER_LOG and AL.sv == SAVED.account, "another character uses the account settings and logs")
n = #LOG; AL = LOGIN("char1")
check(not ENCOUNTER_LOG and AL.sv == SAVED.chars.char1, "the opted-out character does not log")
check(said(n, "this character's own settings"), "its status names the scope")
n = #LOG; SLASH("account")
check(AL.sv == SAVED.account and ENCOUNTER_LOG, "/alog account switches back and starts logging")
check(said(n, "now using account-wide settings"), "and says so")
SLASH("toon"); check(AL.sv == SAVED.chars.char1 and ENCOUNTER_LOG, "switching to a disabled scope does not stop logging")
SLASH("account")

print("-- chat options")
AL.sv.chatOnZone = true
n = #LOG; ZONE(); check(said(n, "Encounter logging is"), "status after every loading screen when enabled")
AL.sv.chatOnZone, AL.sv.chatOnLogin = false, false
n = #LOG; AL = LOGIN(nil, { keepLog = true }); check(#LOG == n, "login status can be turned off")
n = #LOG; AL = LOGIN(); check(said(n, "turned encounter logging"), "but turning logging on is still reported")
AL.sv.chatOnLogin, AL.sv.warnOnOff = true, false
n = #LOG; SetEncounterLogEnabled(false); check(#LOG == n, "switch-off warning can be turned off")
AL.sv.warnOnOff = true

print("-- failures and conflicts")
LOG_REFUSES = true
n = #LOG; AL = LOGIN(); check(said(n, "could not turn encounter logging on"), "reports when the game refuses")
SLASH("off"); n = #LOG; SLASH("on"); check(said(n, "could not") and not said(n, "Always Logging |c5FD35FON"), "/alog on reports failure")
LOG_REFUSES = false
EzStalking = { settings = { log = { enabled = true } } }
n = #LOG; AL = LOGIN(); check(said(n, "Easy Stalking"), "warns when Easy Stalking's automatic logging is also on")
n = #LOG; ZONE(); check(not said(n, "Easy Stalking"), "only at login")
EzStalking.settings.log.enabled = false
n = #LOG; AL = LOGIN(); check(not said(n, "Easy Stalking"), "quiet when Easy Stalking's automatic logging is off")
EzStalking = nil

print("-- on-screen indicator")
AL = LOGIN()
local I = AL.Indicator
local function shows(text, colour)
  local c = I.label.color
  local is = { green = c[2] > 0.8 and c[1] < 0.5, red = c[1] == 1 and c[2] < 0.5, amber = c[1] == 1 and c[2] > 0.6 and c[3] == 0 }
  return I.label.text == text and is[colour] and not I.label.hidden
end
check(FRAGMENTS and I.window and I.label, "indicator built and added to the HUD")
check(shows("Encounter log: on", "green"), "logging: green 'Encounter log: on'")
check(not I.window.movable and not I.window.mouse and I.bg.hidden and I.hint.hidden, "starts locked")
check(I.window.anchor[1] == TOP and I.window.x == 380 and I.window.y == 40, "default spot beside the compass")
check(updates["AlwaysLoggingIndicatorPoll"] ~= nil, "poll registered")
SetEncounterLogEnabled(false)
check(shows("Encounter log: off", "red"), "switched off behind its back: red")
FIRE(EVENT_PLAYER_ACTIVATED)
check(shows("Encounter log: off", "amber"), "about to be turned back on: amber, not red")
WAIT(); check(shows("Encounter log: on", "green"), "turned back on: green")
SLASH("off"); check(shows("Encounter log: off", "amber"), "/alog off: amber")
SetEncounterLogEnabled(true); check(shows("Encounter log: on", "green"), "on by someone else while off: green")
SetEncounterLogEnabled(false); SLASH("on"); check(shows("Encounter log: on", "green"), "/alog on: green")
AL.sv.reapplyOnZone = false; SetEncounterLogEnabled(false); FIRE(EVENT_PLAYER_ACTIVATED)
check(shows("Encounter log: off", "red"), "loading screen that will not fix it stays red")
WAIT(); AL.sv.reapplyOnZone = true; SLASH("on")
ENCOUNTER_LOG = false   -- an addon calling a saved reference, bypassing the hook
WAIT(); check(shows("Encounter log: off", "red"), "poll catches a change the hook missed")
SLASH("off"); SLASH("on")
n = #LOG; SLASH("indicator"); check(I.label.hidden and not AL.sv.indicator and said(n, "hidden"), "/alog indicator hides it")
SLASH("unlock"); check(not I.label.hidden and I.window.movable and I.window.mouse and not I.bg.hidden and not I.hint.hidden, "unlocking shows it to move even when hidden")
I.window.x, I.window.y = -200, 300; I.window.handlers.OnMoveStop()
check(AL.sv.x == -200 and AL.sv.y == 300, "drag saves the position")
SLASH("lock"); check(I.label.hidden and not I.window.movable and I.bg.hidden, "locking hides it again")
SLASH("indicator"); check(not I.label.hidden and AL.sv.indicator, "/alog indicator shows it")
AL = LOGIN(); I = AL.Indicator
check(I.window.x == -200 and I.window.y == 300, "position survives a reload")
SLASH("character"); check(I.window.x == 380 and I.window.y == 40, "a character's own settings have their own position")
SLASH("indicator"); SLASH("account")
check(I.window.x == -200 and not I.label.hidden, "switching back restores the account position and visibility")
I.ResetPosition(); check(AL.sv.x == 380 and AL.sv.y == 40 and I.window.x == 380, "reset position")

print("-- settings panel")
for _, o in ipairs(LAM_OPTS) do
  if o.getFunc then o.getFunc() end
  if type(o.disabled) == "function" then o.disabled() end
end
check(opt("Always log encounters").getFunc() == true, "panel reads the active settings")
opt("Always log encounters").setFunc(false)
check(not AL.sv.enabled and not ENCOUNTER_LOG, "panel off stops logging")
check(opt("Keep it on after loading screens").disabled() == true, "dependent options grey out")
opt("Always log encounters").setFunc(true); check(ENCOUNTER_LOG, "panel on starts logging")
opt("Use account-wide settings").setFunc(false)
check(AL.sv == SAVED.chars.char1, "scope checkbox switches tables")
check(opt("Always log encounters").getFunc() == SAVED.chars.char1.enabled, "panel follows the switched table")
opt("Status after every loading screen").setFunc(true)
check(SAVED.chars.char1.chatOnZone and not SAVED.account.chatOnZone, "panel writes to the active table only")
opt("Use account-wide settings").setFunc(true)
I = AL.Indicator
opt("Show indicator").setFunc(false); check(I.label.hidden and not AL.sv.indicator, "panel hides the indicator")
opt("Lock position").setFunc(false); check(I.window.movable and not I.label.hidden, "panel unlocks it")
I.window.x = 0; opt("Reset position").func(); check(AL.sv.x == 380 and I.window.x == 380, "panel resets its position")
-- LAM's "Reset to defaults" calls every setFunc with its default, in panel order
SLASH("character"); SLASH("off"); AL.sv.reapplyOnZone = false
for _, o in ipairs(LAM_OPTS) do if o.setFunc then o.setFunc(o.default) end end
check(AL.sv == SAVED.account and AL.sv.enabled and AL.sv.reapplyOnZone and ENCOUNTER_LOG, "reset to defaults: account-wide, on, logging")
check(AL.sv.indicator and AL.sv.locked and not I.label.hidden and not I.window.movable, "reset to defaults: indicator shown and locked")

print(fails == 0 and "\nALL PASS" or ("\n" .. fails .. " FAILURES")); os.exit(fails == 0 and 0 or 1)
