-- Farm Time - Destaque na tela
--
-- Addons não conseguem enxergar objetos do mundo nem converter posição 3D em
-- posição de tela. Mas o próprio jogo tem o "soft target de interação": ele
-- escolhe o objeto interagível à sua frente (erva, minério, baú...) e pode
-- desenhar uma placa de nome (nameplate) sobre ele. Essa placa é posicionada
-- pelo cliente no lugar exato do objeto em 3D, então basta ancorar o nosso
-- destaque (ícone grande + brilho pulsando) nela.
--
-- Limitação: o jogo escolhe UM objeto por vez (o melhor à frente/no centro).

local _, FT = ...

local UNIT = "softinteract"

-- Opções do jogo que fazem o soft target funcionar com objetos.
local function DesiredCVars(db)
    return {
        SoftTargetInteract          = "3", -- sempre ativo (teclado/mouse e controle)
        SoftTargetInteractArc       = "1", -- arco à frente do personagem
        SoftTargetInteractRange     = tostring(db.interactRange),
        SoftTargetIconGameObject    = "1", -- ícone do jogo sobre objetos
        SoftTargetIconInteract      = "1",
        SoftTargetNameplateInteract = "1", -- placa de nome sobre o objeto (onde ancoramos)
    }
end

local GetCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCVar = (C_CVar and C_CVar.SetCVar) or SetCVar

function FT:ApplyCVars()
    local saved = self.db.savedCVars
    for name, value in pairs(DesiredCVars(self.db)) do
        local ok, current = pcall(GetCVar, name)
        if ok and current ~= nil then
            if saved[name] == nil then saved[name] = current end
            pcall(SetCVar, name, value)
        end
    end
end

function FT:RestoreCVars()
    for name, value in pairs(self.db.savedCVars) do
        pcall(SetCVar, name, value)
    end
    wipe(self.db.savedCVars)
end

---------------------------------------------------------------------------
-- Visual
---------------------------------------------------------------------------
local ICONS = {
    herb  = "Interface\\Icons\\Trade_Herbalism",
    ore   = "Interface\\Icons\\Trade_Mining",
    other = "Interface\\Icons\\INV_Misc_Gear_01",
}
local COLORS = {
    herb  = { 0.3, 1.0, 0.3 },
    ore   = { 1.0, 0.7, 0.2 },
    other = { 0.6, 0.8, 1.0 },
}

local marker = CreateFrame("Frame", "FarmTimeMarker", UIParent)
marker:SetFrameStrata("LOW")
marker:EnableMouse(false)
marker:Hide()

marker.glow = marker:CreateTexture(nil, "BACKGROUND")
marker.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
marker.glow:SetBlendMode("ADD")
marker.glow:SetPoint("CENTER")

marker.icon = marker:CreateTexture(nil, "ARTWORK")
marker.icon:SetAllPoints()
marker.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

marker.text = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
marker.text:SetPoint("TOP", marker, "BOTTOM", 0, -4)

local pulse = marker:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local grow = pulse:CreateAnimation("Scale")
grow:SetScale(1.25, 1.25)
grow:SetDuration(0.6)
grow:SetSmoothing("IN_OUT")

-- Faixa com o nome do nó, logo abaixo do centro da tela.
local banner = UIParent:CreateFontString("FarmTimeBanner", "OVERLAY", "GameFontNormalHuge")
banner:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
banner:Hide()

---------------------------------------------------------------------------
-- Lógica
---------------------------------------------------------------------------
local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function CurrentGatherTarget()
    if not UnitExists(UNIT) then return nil end
    local guid = UnitGUID(UNIT)
    if not guid or IsSecret(guid) or not guid:find("^GameObject") then return nil end
    local name = UnitName(UNIT)
    if IsSecret(name) then name = nil end
    local kind = FT:Classify(UNIT, name)
    if FT.db.onlyGathering and kind == "other" then return nil end
    return kind, name
end

local function HideAll()
    pulse:Stop()
    marker:Hide()
    banner:Hide()
end

function FT:RefreshHighlight()
    local db = self.db
    if not db or not db.enabled then return HideAll() end

    local kind, name = CurrentGatherTarget()
    if not kind then return HideAll() end

    local c = COLORS[kind]
    local size = db.iconSize

    -- Ícone sobre o objeto, ancorado na placa de nome que o jogo desenha nele.
    local plate = C_NamePlate.GetNamePlateForUnit(UNIT)
    if plate then
        marker:ClearAllPoints()
        marker:SetPoint("BOTTOM", plate, "TOP", 0, 4)
        marker:SetSize(size, size)
        marker.icon:SetTexture(ICONS[kind])
        marker.glow:SetSize(size * 1.9, size * 1.9)
        marker.glow:SetVertexColor(c[1], c[2], c[3])
        marker.text:SetText(name or "")
        marker.text:SetTextColor(c[1], c[2], c[3])
        marker:Show()
        if db.pulse then
            if not pulse:IsPlaying() then pulse:Play() end
        else
            pulse:Stop()
        end
    else
        pulse:Stop()
        marker:Hide()
    end

    if db.showBanner and name then
        banner:SetText(name)
        banner:SetTextColor(c[1], c[2], c[3])
        banner:Show()
    else
        banner:Hide()
    end
end

local function Refresh(self) self:RefreshHighlight() end

FT:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", Refresh)
FT:RegisterEvent("NAME_PLATE_UNIT_ADDED", Refresh)
FT:RegisterEvent("NAME_PLATE_UNIT_REMOVED", Refresh)
FT:RegisterEvent("PLAYER_ENTERING_WORLD", Refresh)
