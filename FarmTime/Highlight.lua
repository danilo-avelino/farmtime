-- Farm Time - Destaque
--
-- Addons não conseguem enxergar objetos do mundo nem converter posição 3D em
-- posição de tela. O que existe é o "alvo de interação" (tecla Interagir):
-- o jogo escolhe o objeto interagível à sua frente (erva, minério, baú...),
-- expõe ele pelo token "softinteract" e, com as opções certas, desenha um
-- ícone em cima do próprio objeto.
--
-- O Farm Time:
--   1. liga essas opções do jogo (ícone sobre objetos, inclusive ervas);
--   2. quando o alvo de interação é uma erva/minério, mostra um alerta grande
--      perto do centro da tela, com o ícone que o jogo usaria no cursor,
--      o nome do nó e um som.
-- Limitação: o jogo escolhe UM objeto por vez (o mais à frente).

local _, FT = ...

local UNIT = "softinteract"

-- Opções do jogo. Os nomes foram conferidos na interface do Classic 1.15.9;
-- as que não existirem no seu cliente são ignoradas.
local function DesiredCVars(db)
    return {
        SoftTargetInteract          = "3", -- Enum.SoftTargetEnableFlags.Any
        SoftTargetIconInteract      = "1",
        SoftTargetIconGameObject    = "1", -- ícone sobre objetos (desligado por padrão)
        SoftTargetLowPriorityIcons  = "1", -- inclui objetos "de baixa prioridade" (desligado por padrão)
        SoftTargetInteractRange     = tostring(db.interactRange),
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
local FALLBACK_ICONS = {
    herb  = "Interface\\Icons\\INV_Misc_Flower_02",
    ore   = "Interface\\Icons\\INV_Pick_02",
    other = "Interface\\Icons\\INV_Misc_Gear_01",
}
local COLORS = {
    herb  = { 0.3, 1.0, 0.3 },
    ore   = { 1.0, 0.7, 0.2 },
    other = { 0.6, 0.8, 1.0 },
}

local LABELS = { herb = "Erva", ore = "Minério", other = "Objeto" }

-- Moldura feita de 4 texturas finas (funciona igual em todos os clientes,
-- sem depender de BackdropTemplate).
local function CreateBorder(parent, layer, thickness, inset)
    local edges = {}
    for i = 1, 4 do edges[i] = parent:CreateTexture(nil, layer) end
    local t, o = thickness, inset or 0
    edges[1]:SetPoint("TOPLEFT", -o, o);         edges[1]:SetPoint("TOPRIGHT", o, o);        edges[1]:SetHeight(t)
    edges[2]:SetPoint("BOTTOMLEFT", -o, -o);     edges[2]:SetPoint("BOTTOMRIGHT", o, -o);    edges[2]:SetHeight(t)
    edges[3]:SetPoint("TOPLEFT", -o, o);         edges[3]:SetPoint("BOTTOMLEFT", -o, -o);    edges[3]:SetWidth(t)
    edges[4]:SetPoint("TOPRIGHT", o, o);         edges[4]:SetPoint("BOTTOMRIGHT", o, -o);    edges[4]:SetWidth(t)
    return {
        SetColor = function(_, r, g, b, a)
            for _, e in ipairs(edges) do e:SetColorTexture(r, g, b, a or 1) end
        end,
    }
end

-- Placa no estilo nameplate: [ícone] Nome / Tipo
local alert = CreateFrame("Frame", "FarmTimeAlert", UIParent)
alert:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
alert:SetFrameStrata("HIGH")
alert:EnableMouse(false)
alert:Hide()

alert.bg = alert:CreateTexture(nil, "BACKGROUND")
alert.bg:SetAllPoints()
alert.bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)

-- Faixa colorida na base, como a barra de vida de uma nameplate.
alert.bar = alert:CreateTexture(nil, "BORDER")
alert.bar:SetPoint("BOTTOMLEFT", 2, 2)
alert.bar:SetPoint("BOTTOMRIGHT", -2, 2)
alert.bar:SetHeight(3)

alert.outer = CreateBorder(alert, "OVERLAY", 1, 1)  -- contorno preto
alert.outer:SetColor(0, 0, 0, 1)
alert.border = CreateBorder(alert, "BORDER", 2, 0)  -- borda colorida

alert.iconFrame = CreateFrame("Frame", nil, alert)
alert.iconFrame:SetPoint("LEFT", alert, "LEFT", 4, 1)
alert.icon = alert.iconFrame:CreateTexture(nil, "ARTWORK")
alert.icon:SetAllPoints()
alert.iconBorder = CreateBorder(alert.iconFrame, "OVERLAY", 1, 1)
alert.iconBorder:SetColor(0, 0, 0, 1)

alert.text = alert:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
alert.text:SetPoint("TOPLEFT", alert.iconFrame, "TOPRIGHT", 8, -2)
alert.text:SetJustifyH("LEFT")
alert.text:SetShadowOffset(1, -1)

alert.sub = alert:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
alert.sub:SetPoint("BOTTOMLEFT", alert.iconFrame, "BOTTOMRIGHT", 8, 2)
alert.sub:SetJustifyH("LEFT")
alert.sub:SetTextColor(0.75, 0.75, 0.75)

local pulse = alert:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local grow = pulse:CreateAnimation("Scale")
grow:SetScale(1.25, 1.25)
grow:SetDuration(0.5)
grow:SetSmoothing("IN_OUT")

---------------------------------------------------------------------------
-- Lógica
---------------------------------------------------------------------------
local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local eventGUID -- GUID recebido no último PLAYER_SOFT_INTERACT_CHANGED

local function Safe(fn, ...)
    if not fn then return nil end
    local ok, a = pcall(fn, ...)
    if ok and not IsSecret(a) then return a end
end

-- Placa de nome que o jogo desenha sobre o alvo de interação (se existir).
local function GetInteractPlate()
    return C_NamePlate and Safe(C_NamePlate.GetNamePlateForUnit, UNIT)
end

-- Lê o alvo de interação atual. Retorna guid, nome, tipo (ou nil).
-- UnitExists() costuma ser falso para objetos (não são unidades), então não
-- dependemos dele: usamos o GUID do token ou o que veio no evento.
function FT:GetInteractTarget()
    local guid = Safe(UnitGUID, UNIT) or eventGUID
    if not guid then return nil end
    local name = Safe(UnitName, UNIT)
    return guid, name, self:Classify(name)
end

local lastGUID

local function ShowAlert(kind, name, unit)
    local db = FT.db
    local c = COLORS[kind]
    local size = db.iconSize

    -- Ícone do próprio recurso (ex.: Kingsblood); se não souber, o ícone que o
    -- jogo usaria no cursor (luva de coleta, picareta...); por último, um genérico.
    local itemIcon = FT:GetNodeIcon(name)
    alert.icon:SetTexCoord(0, 1, 0, 1)
    if itemIcon then
        alert.icon:SetTexture(itemIcon)
        alert.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif not (unit and SetUnitCursorTexture and SetUnitCursorTexture(alert.icon, unit)) then
        alert.icon:SetTexture(FALLBACK_ICONS[kind])
    end

    alert.text:SetText(name or LABELS[kind])
    alert.text:SetTextColor(c[1], c[2], c[3])
    alert.sub:SetText(LABELS[kind])
    alert.border:SetColor(c[1] * 0.8, c[2] * 0.8, c[3] * 0.8, 1)
    alert.bar:SetColorTexture(c[1], c[2], c[3], 0.9)

    -- Tamanho: o ícone define a altura da placa; a largura acompanha o nome.
    local textWidth = math.max(alert.text:GetStringWidth(), alert.sub:GetStringWidth())
    alert.iconFrame:SetSize(size, size)
    alert:SetSize(size + 8 + 8 + textWidth + 12, size + 10)

    -- Prende o ícone em cima do próprio nó quando o jogo desenha uma placa nele;
    -- senão, fica fixo acima do centro da tela.
    local plate = db.anchorToNode and unit and GetInteractPlate()
    alert:ClearAllPoints()
    if not (plate and pcall(alert.SetPoint, alert, "BOTTOM", plate, "TOP", 0, db.nodeOffset)) then
        alert:ClearAllPoints()
        alert:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    end
    alert:Show()

    if db.pulse then
        if not pulse:IsPlaying() then pulse:Play() end
    else
        pulse:Stop()
    end
end

local function HideAlert()
    pulse:Stop()
    alert:Hide()
end

local testing = false

function FT:RefreshHighlight()
    local db = self.db
    if not db or testing then return end

    local guid, name, kind = self:GetInteractTarget()
    local isObject = guid and guid:find("^GameObject")
    -- Sem nome não dá para classificar; nesse caso mostra mesmo assim.
    local show = db.enabled and isObject and not (db.onlyGathering and name and kind == "other")

    if not show then
        HideAlert()
        lastGUID = nil
        return
    end

    ShowAlert(kind, name, UNIT)
    if guid ~= lastGUID and db.sound then
        PlaySound(SOUNDKIT and SOUNDKIT.UI_SOFT_TARGET_INTERACT_AVAILABLE or 8959)
    end
    lastGUID = guid
end

-- Mostra o alerta por 3 segundos, para ajustar tamanho/posição sem precisar de uma erva.
function FT:ShowTestAlert()
    testing = true
    ShowAlert("herb", "Kingsblood")
    C_Timer.After(3, function()
        testing = false
        HideAlert()
        FT:RefreshHighlight()
    end)
end

local function Refresh(self) self:RefreshHighlight() end

FT:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", function(self, oldGUID, newGUID)
    eventGUID = (not IsSecret(newGUID)) and newGUID or nil
    if self.db and self.db.debug then
        local guid, name, kind = self:GetInteractTarget()
        self:Print(string.format("alvo: %s | %s | %s | existe=%s | placa=%s",
            tostring(name), tostring(kind), tostring(guid),
            tostring(Safe(UnitExists, UNIT)), tostring(GetInteractPlate() ~= nil)))
    end
    self:RefreshHighlight()
end)
-- A placa às vezes aparece um instante depois do evento.
FT:RegisterEvent("NAME_PLATE_UNIT_ADDED", Refresh)
FT:RegisterEvent("PLAYER_ENTERING_WORLD", Refresh)
