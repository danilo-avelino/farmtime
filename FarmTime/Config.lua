-- Farm Time - Painel de configurações e botão do minimapa
-- Feito sem bibliotecas externas (sem LibDBIcon/AceConfig) para o addon
-- continuar sendo uma pasta só.

local _, FT = ...

local ICON = "Interface\\Icons\\INV_Misc_Flower_02"

---------------------------------------------------------------------------
-- Painel
---------------------------------------------------------------------------
local panel = CreateFrame("Frame", "FarmTimeConfig", UIParent, "BasicFrameTemplateWithInset")
panel:SetSize(340, 520)
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
local y = -36

local function AddCheckbox(key, label)
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, y)
    cb.Text:SetFontObject("GameFontHighlight")
    cb.Text:SetText(label)
    cb:SetScript("OnClick", function(self)
        FT:SetOption(key, self:GetChecked() and true or false)
    end)
    cb.Refresh = function(self) self:SetChecked(FT.db[key]) end
    table.insert(controls, cb)
    y = y - 28
    return cb
end

-- Slider simples, sem template (os templates de slider mudam entre clientes).
local function AddSlider(key, label, lo, hi, step)
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 22, y - 6)

    local s = CreateFrame("Slider", nil, panel)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(260, 16)
    s:SetPoint("TOPLEFT", 26, y - 24)
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
        text:SetFormattedText("%s: |cffffffff%d|r", label, v)
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

AddCheckbox("enabled",       "Ativar destaque")
AddCheckbox("onlyGathering", "Só ervas e minérios")
AddCheckbox("anchorToNode",  "Ícone em cima do nó (senão, no centro da tela)")
AddCheckbox("hideGameName",  "Esconder o nome do jogo sobre o nó")
AddCheckbox("sound",         "Som ao encontrar um nó")
AddCheckbox("bindInteractKey", "Tecla F coleta a erva/minério")
AddCheckbox("fastLoot",      "Fast loot (Shift segurado desativa)")
AddCheckbox("sessionWindow", "Janela da sessão abre ao coletar")
AddCheckbox("manageCVars",   "Ligar ícones de interação do jogo")
AddCheckbox("debug",         "Debug no chat")
y = y - 6
AddSlider("iconSize",      "Tamanho do ícone", 16, 96, 2)
AddSlider("interactRange", "Alcance (jardas)", 5, 60, 1)

local minimapCB = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
minimapCB:SetPoint("TOPLEFT", 16, y)
minimapCB.Text:SetFontObject("GameFontHighlight")
minimapCB.Text:SetText("Mostrar botão no minimapa")
minimapCB:SetScript("OnClick", function(self)
    FT.db.minimap.hide = not self:GetChecked()
    FT:UpdateMinimapButton()
end)
minimapCB.Refresh = function(self) self:SetChecked(not FT.db.minimap.hide) end
table.insert(controls, minimapCB)

local statusBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
statusBtn:SetSize(96, 22)
statusBtn:SetPoint("BOTTOMLEFT", 16, 14)
statusBtn:SetText("Diagnóstico")
statusBtn:SetScript("OnClick", function() SlashCmdList.FARMTIME("status") end)

local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
testBtn:SetSize(96, 22)
testBtn:SetPoint("BOTTOMRIGHT", -16, 14)
testBtn:SetText("Testar alerta")
testBtn:SetScript("OnClick", function() FT:ShowTestAlert() end)

local sessionBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
sessionBtn:SetSize(96, 22)
sessionBtn:SetPoint("BOTTOM", 0, 14)
sessionBtn:SetText("Sessão")
sessionBtn:SetScript("OnClick", function() FT:ToggleSessionWindow() end)

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
        FT:Print(FT.db.enabled and "ativado" or "desativado")
    else
        FT:ToggleConfig()
    end
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Farm Time")
    GameTooltip:AddLine(FT.db.enabled and "|cff33ff33Ativado|r" or "|cffff3333Desativado|r")
    GameTooltip:AddLine("Clique: configurações", 1, 1, 1)
    GameTooltip:AddLine("Clique direito: liga/desliga", 1, 1, 1)
    GameTooltip:AddLine("Arraste: mover o botão", 1, 1, 1)
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
