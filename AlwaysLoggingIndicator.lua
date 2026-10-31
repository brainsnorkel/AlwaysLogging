-- Always Logging on-screen indicator: "Encounter log: on" in green, "off" in red or amber.

local AL = AlwaysLogging
AL.Indicator = AL.Indicator or {}
local I = AL.Indicator

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local WINDOW_NAME = "AlwaysLoggingIndicator"
local POLL_NAME   = AL.name .. "IndicatorPoll"
local FONT_SIZE   = 18

local TEXT_ON  = "Encounter log: on"
local TEXT_OFF = "Encounter log: off"

local GREEN = { 0.37, 0.83, 0.37 }   -- logging
local RED   = { 1.00, 0.33, 0.33 }   -- not logging, although Always Logging should have it on
local AMBER = { 1.00, 0.69, 0.00 }   -- not logging, and that is expected right now

-- Another addon holding its own reference to SetEncounterLogEnabled would
-- bypass the hook, so poll as well: an indicator that can be wrong is worse
-- than none.
local POLL_MS = 1000

-- Size the window for the longer of the two texts. The label reports 0 width
-- until it has been laid out, so estimate until then.
local function Fit()
    local widest = 0
    for _, text in ipairs({ TEXT_ON, TEXT_OFF }) do
        I.label:SetText(text)
        local w = I.label:GetTextWidth()
        if not w or w <= 0 then w = FONT_SIZE * 0.6 * string.len(text) end
        if w > widest then widest = w end
    end
    I.window:SetDimensions(widest + 20, FONT_SIZE + 14)
end

function I.ApplyPosition()
    I.window:ClearAnchors()
    I.window:SetAnchor(TOP, GuiRoot, TOP, AL.sv.x, AL.sv.y)
end

-- x is the window centre's offset from the screen centre, y its top edge, so
-- the default spot beside the compass survives UI scale and aspect changes.
local function SavePosition()
    local cx = I.window:GetCenter()
    local rx = GuiRoot:GetCenter()
    AL.sv.x = math.floor(cx - rx + 0.5)
    AL.sv.y = math.floor(I.window:GetTop() - GuiRoot:GetTop() + 0.5)
end

function I.ResetPosition()
    AL.sv.x, AL.sv.y = AL.defaults.x, AL.defaults.y
    if I.window then I.ApplyPosition() end
end

-- Redraws the text and colour; cheap enough to call on every change and poll.
function I.Update()
    if not I.window then return end
    local on = IsEncounterLogEnabled()
    local color = on and GREEN or (AL.IsUnexpectedlyOff() and RED or AMBER)
    if on == I.shownOn and color == I.shownColor then return end
    I.shownOn, I.shownColor = on, color
    I.label:SetText(on and TEXT_ON or TEXT_OFF)
    I.label:SetColor(color[1], color[2], color[3], 1)
end

-- Applies visibility, lock and position from the active settings. While
-- unlocked the indicator shows even if it is switched off, so it can be moved.
function I.Refresh()
    if not I.window then return end
    local unlocked = not AL.sv.locked
    I.window:SetMovable(unlocked)
    I.window:SetMouseEnabled(unlocked)
    I.bg:SetHidden(not unlocked)
    I.hint:SetHidden(not unlocked)
    I.label:SetHidden(not (AL.sv.indicator or unlocked))
    I.ApplyPosition()
    I.shownOn, I.shownColor = nil, nil
    I.Update()
end

function I.Create()
    if I.window then return end

    local tlw = WM:CreateTopLevelWindow(WINDOW_NAME)
    tlw:SetClampedToScreen(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetHandler("OnMoveStop", SavePosition)

    local bg = WM:CreateControl(WINDOW_NAME .. "BG", tlw, CT_BACKDROP)
    bg:SetAnchorFill(tlw)
    bg:SetCenterColor(0, 0, 0, 0.45)
    bg:SetEdgeColor(1, 1, 1, 0.6)
    bg:SetEdgeTexture("", 1, 1, 1)

    local label = WM:CreateControl(WINDOW_NAME .. "Text", tlw, CT_LABEL)
    label:SetAnchor(CENTER, tlw, CENTER, 0, 0)
    label:SetFont("$(BOLD_FONT)|" .. FONT_SIZE .. "|soft-shadow-thick")

    local hint = WM:CreateControl(WINDOW_NAME .. "Hint", tlw, CT_LABEL)
    hint:SetAnchor(TOP, tlw, BOTTOM, 0, 2)
    hint:SetFont("ZoFontGameSmall")
    hint:SetColor(1, 1, 1, 0.8)
    hint:SetText("Always Logging: show the cursor, drag to move, then /alog lock")

    I.window, I.bg, I.label, I.hint = tlw, bg, label, hint
    Fit()

    I.fragment = ZO_HUDFadeSceneFragment:New(tlw)
    HUD_SCENE:AddFragment(I.fragment)
    HUD_UI_SCENE:AddFragment(I.fragment)

    EM:RegisterForUpdate(POLL_NAME, POLL_MS, I.Update)
    I.Refresh()
end
