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
local COLORS = FT.Style.COLORS


-- Placa no estilo nameplate: [ícone] Nome / Tipo (visual em Style.lua).
local alert = FT.Style.CreatePlate(UIParent, { name = "FarmTimeAlert", titleFont = "GameFontNormalLarge" })
alert:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
alert:SetFrameStrata("HIGH")
alert:Hide()


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

---------------------------------------------------------------------------
-- Esconder o nome/ícone que o jogo desenha sobre o nó
--
-- O nome vem da placa de nome do jogo (Blizzard ou Plater). Procuramos dentro
-- dela o texto igual ao nome do nó e o ícone de interação, e zeramos o alpha.
-- As placas são recicladas pelo jogo, então tudo é restaurado quando o alvo
-- muda ou a placa some.
---------------------------------------------------------------------------
local hidden = {}  -- [região] = alpha original
local hooked = {}

local function HideRegion(region)
    if not region or not region.SetAlpha or hidden[region] then return end
    hidden[region] = region:GetAlpha()
    region:SetAlpha(0)
    -- Se a placa tentar mostrar de novo, volta a esconder enquanto for o nosso alvo.
    if not hooked[region] then
        hooked[region] = true
        hooksecurefunc(region, "SetAlpha", function(self, a)
            if hidden[self] and a ~= 0 then self:SetAlpha(0) end
        end)
    end
end

local function RestoreRegions()
    for region, alpha in pairs(hidden) do
        hidden[region] = nil
        pcall(region.SetAlpha, region, alpha)
    end
end

-- Procura textos com o nome do nó (até 4 níveis de profundidade).
local function HideMatchingText(frame, name, depth)
    if not frame or depth > 4 then return end
    if frame.GetRegions then
        for _, r in ipairs({ frame:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "FontString" then
                local ok, text = pcall(r.GetText, r)
                if ok and text == name then HideRegion(r) end
            end
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            HideMatchingText(child, name, depth + 1)
        end
    end
end

local function HideGameLabel(plate, name)
    local blizz = plate.UnitFrame
    if blizz then
        HideRegion(blizz.name)
        HideRegion(blizz.SoftTargetFrame) -- ícone de interação do jogo
    end
    local plater = plate.unitFrame
    if plater then
        HideRegion(plater.ActorNameSpecial)
        if plater.healthBar then HideRegion(plater.healthBar.unitName) end
    end
    if name then HideMatchingText(plate, name, 0) end
end

local lastGUID

local function ShowAlert(kind, name, unit)
    local db = FT.db
    local c = COLORS[kind]
    local size = db.iconSize

    -- Ícone do próprio recurso (ex.: Kingsblood); se não souber, o ícone que o
    -- jogo usaria no cursor (luva de coleta, picareta...); por último, um genérico.
    local itemIcon = FT:GetNodeIcon(name)
    if not itemIcon then
        alert.icon:SetTexCoord(0, 1, 0, 1)
        if not (unit and SetUnitCursorTexture and SetUnitCursorTexture(alert.icon, unit)) then
            itemIcon = FALLBACK_ICONS[kind]
        end
    end
    local label = FT.L["KIND_" .. kind]
    alert:SetContent(itemIcon, name or label, label, c, size)

    -- Prende o ícone em cima do próprio nó quando o jogo desenha uma placa nele;
    -- senão, fica fixo acima do centro da tela.
    local plate = unit and GetInteractPlate()
    RestoreRegions()
    if plate and db.hideGameName then
        pcall(HideGameLabel, plate, name)
    end
    if not db.anchorToNode then plate = nil end
    alert:ClearAllPoints()
    if not (plate and pcall(alert.SetPoint, alert, "BOTTOM", plate, "TOP", 0, db.nodeOffset)) then
        alert:ClearAllPoints()
        alert:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    end
    alert:Show()
end

local function HideAlert()
    alert:Hide()
    RestoreRegions()
end

local testing = false

function FT:RefreshHighlight()
    local db = self.db
    if not db or testing then return end

    local guid, name, kind = self:GetInteractTarget()
    local isObject = guid and guid:find("^GameObject")
    -- Sem nome não dá para classificar; nesse caso mostra mesmo assim.
    local show = db.enabled and isObject and not (db.onlyGathering and name and kind == "other")

    -- O nó salvo com esse nome, aqui perto, está confirmado (o jogo o vê).
    self.currentTargetName = isObject and (kind == "herb" or kind == "ore") and name or nil
    if self.currentTargetName and self.ConfirmNodeNearPlayer then
        self:ConfirmNodeNearPlayer(name)
    end
    if self.currentTargetName then
        self.lastGatherTarget = { kind = kind, name = name, time = GetTime() }
    end

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
        self:Print(string.format(self.L.DEBUG_TARGET,
            tostring(name), tostring(kind), tostring(guid),
            tostring(Safe(UnitExists, UNIT)), tostring(GetInteractPlate() ~= nil)))
    end
    self:RefreshHighlight()
end)
-- A placa às vezes aparece um instante depois do evento.
FT:RegisterEvent("NAME_PLATE_UNIT_ADDED", Refresh)
FT:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(self)
    RestoreRegions() -- a placa vai ser reciclada para outra unidade
    self:RefreshHighlight()
end)
FT:RegisterEvent("PLAYER_ENTERING_WORLD", Refresh)
