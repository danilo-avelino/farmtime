-- Farm Time - Painel de configurações e botão do minimapa
-- Feito sem bibliotecas externas (sem LibDBIcon/AceConfig) para o addon
-- continuar sendo uma pasta só.

local _, FT = ...

local ICON = "Interface\\Icons\\INV_Misc_Flower_02"

---------------------------------------------------------------------------
-- Painel
---------------------------------------------------------------------------
local panel = CreateFrame("Frame", "FarmTimeConfig", UIParent, "BasicFrameTemplateWithInset")
panel:SetSize(650, 566)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:SetClampedToScreen(true)
panel:Hide()
table.insert(UISpecialFrames, "FarmTimeConfig") -- fecha com ESC

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", panel, "TOP", 0, -5)
title:SetText("Farm Time")

local controls = {}
-- Duas colunas: caixas de seleção à esquerda; sliders, minimapa e idioma à direita.
local x, y = 16, -36

-- labelKey é uma chave de FT.L (o texto troca junto com o idioma).
local function AddCheckbox(key, labelKey)
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetFontObject("GameFontHighlight")
    FT:T(cb.Text, labelKey)
    cb:SetScript("OnClick", function(self)
        FT:SetOption(key, self:GetChecked() and true or false)
    end)
    cb.Refresh = function(self) self:SetChecked(FT.db[key]) end
    table.insert(controls, cb)
    y = y - 28
    return cb
end

-- Slider simples, sem template (os templates de slider mudam entre clientes).
local function AddSlider(key, labelKey, lo, hi, step)
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", x + 6, y - 6)

    local s = CreateFrame("Slider", nil, panel)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(270, 16)
    s:SetPoint("TOPLEFT", x + 10, y - 24)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouse(true)

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0, 0, 0, 0.6)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(6)

    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    local function UpdateText(v)
        text:SetFormattedText("%s: |cffffffff%d|r", FT.L[labelKey], v)
    end

    s:SetScript("OnValueChanged", function(self, v, userInput)
        v = math.floor(v / step + 0.5) * step
        UpdateText(v)
        if userInput and FT.db[key] ~= v then
            FT:SetOption(key, v)
        end
    end)
    s.Refresh = function(self)
        self:SetValue(FT.db[key])
        UpdateText(FT.db[key])
    end
    table.insert(controls, s)
    y = y - 54
    return s
end

AddCheckbox("enabled",         "CFG_ENABLED")
AddCheckbox("onlyGathering",   "CFG_ONLY")
AddCheckbox("anchorToNode",    "CFG_ANCHOR")
AddCheckbox("hideGameName",    "CFG_HIDENAME")
AddCheckbox("sound",           "CFG_SOUND")
AddCheckbox("bindInteractKey", "CFG_KEY")
AddCheckbox("showPrompt",      "CFG_PROMPT")
AddCheckbox("fastLoot",        "CFG_FASTLOOT")
AddCheckbox("sessionWindow",   "CFG_SESSION")
AddCheckbox("trackTradeGoods", "CFG_MATS")
AddCheckbox("hudEnabled",      "CFG_HUD")
AddCheckbox("hudShowUnconfirmed", "CFG_GREY")
AddCheckbox("arrowEnabled",    "CFG_ARROW")
AddCheckbox("shareGuild",      "CFG_SHARE_GUILD")
AddCheckbox("shareGroup",      "CFG_SHARE_GROUP")
AddCheckbox("manageCVars",     "CFG_CVARS")
AddCheckbox("debug",           "CFG_DEBUG")

x, y = 330, -36
AddSlider("iconSize",      "CFG_SIZE", 16, 96, 2)
AddSlider("interactRange", "CFG_RANGE", 5, 60, 1)
AddSlider("hudRange",      "CFG_HUD_RANGE", 30, 300, 10)
AddSlider("hudPitch",      "CFG_PITCH", 0, 85, 1)
AddSlider("hudFov",        "CFG_FOV", 40, 150, 1)

local minimapCB = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
minimapCB:SetPoint("TOPLEFT", x, y)
minimapCB.Text:SetFontObject("GameFontHighlight")
FT:T(minimapCB.Text, "CFG_MINIMAP")
minimapCB:SetScript("OnClick", function(self)
    FT.db.minimap.hide = not self:GetChecked()
    FT:UpdateMinimapButton()
end)
minimapCB.Refresh = function(self) self:SetChecked(not FT.db.minimap.hide) end
table.insert(controls, minimapCB)
y = y - 34

-- Idioma: um botão por idioma, funciona como seleção única.
local langLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
langLabel:SetPoint("TOPLEFT", x + 6, y)
FT:T(langLabel, "CFG_LANGUAGE")
y = y - 18
local langX = x
for _, lang in ipairs(FT.LANGUAGES) do
    local rb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    rb:SetPoint("TOPLEFT", langX, y)
    rb.Text:SetFontObject("GameFontHighlight")
    rb.Text:SetText(lang.label) -- nome do idioma sempre no próprio idioma
    rb:SetScript("OnClick", function()
        FT:SetOption("language", lang.code)
    end)
    rb.Refresh = function(self) self:SetChecked(FT.db.language == lang.code) end
    table.insert(controls, rb)
    langX = langX + 140
end

local statusBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
statusBtn:SetSize(110, 22)
statusBtn:SetPoint("BOTTOMLEFT", 16, 14)
FT:T(statusBtn, "BTN_STATUS")
statusBtn:SetScript("OnClick", function() SlashCmdList.FARMTIME("status") end)

local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
testBtn:SetSize(110, 22)
testBtn:SetPoint("LEFT", statusBtn, "RIGHT", 8, 0)
FT:T(testBtn, "BTN_TEST")
testBtn:SetScript("OnClick", function() FT:ShowTestAlert() end)

local sessionBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
sessionBtn:SetSize(110, 22)
sessionBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)
FT:T(sessionBtn, "BTN_SESSION")
sessionBtn:SetScript("OnClick", function() FT:ToggleSessionWindow() end)

local calibrateBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
calibrateBtn:SetSize(110, 22)
calibrateBtn:SetPoint("LEFT", sessionBtn, "RIGHT", 8, 0)
FT:T(calibrateBtn, "BTN_CALIBRATE")
calibrateBtn:SetScript("OnClick", function() FT:StartCalibration() end)

function FT:RefreshConfig()
    if not panel:IsShown() then return end
    for _, c in ipairs(controls) do c:Refresh() end
end

panel:SetScript("OnShow", function() FT:RefreshConfig() end)

function FT:ToggleConfig()
    panel:SetShown(not panel:IsShown())
end

---------------------------------------------------------------------------
-- Botão do minimapa (arrastável pela borda)
---------------------------------------------------------------------------
local button = CreateFrame("Button", "FarmTimeMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local bg = button:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetSize(20, 20)
bg:SetPoint("TOPLEFT", 7, -5)

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetTexture(ICON)
icon:SetSize(17, 17)
icon:SetPoint("TOPLEFT", 7, -6)
icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")

local function PlaceButton()
    local angle = math.rad(FT.db.minimap.angle)
    local radius = (Minimap:GetWidth() / 2) + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    FT.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    PlaceButton()
end

button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", OnDragUpdate)
end)
button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then
        FT:SetOption("enabled", not FT.db.enabled)
        FT:Print(FT.db.enabled and FT.L.ENABLED or FT.L.DISABLED)
    else
        FT:ToggleConfig()
    end
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Farm Time")
    GameTooltip:AddLine(FT.db.enabled and ("|cff33ff33" .. FT.L.ENABLED .. "|r") or ("|cffff3333" .. FT.L.DISABLED .. "|r"))
    GameTooltip:AddLine(FT.L.TT_CLICK, 1, 1, 1)
    GameTooltip:AddLine(FT.L.TT_RIGHTCLICK, 1, 1, 1)
    GameTooltip:AddLine(FT.L.TT_DRAG, 1, 1, 1)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

function FT:UpdateMinimapButton()
    if self.db.minimap.hide then
        button:Hide()
    else
        PlaceButton()
        button:Show()
    end
    self:RefreshConfig()
end

FT:RegisterEvent("PLAYER_LOGIN", function(self)
    self:UpdateMinimapButton()
end)
