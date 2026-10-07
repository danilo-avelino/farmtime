-- Farm Time - Overlay (HUD)
--
-- O WoW não expõe uma função WorldToScreen nem a posição/orientação real da
-- câmera para addons. Então a projeção abaixo é uma APROXIMAÇÃO em perspectiva
-- usando o que a API oferece:
--   * posição do personagem (UnitPosition)
--   * direção para onde o personagem está virado (GetPlayerFacing)
-- Ela assume que a câmera está atrás do personagem, olhando na mesma direção
-- (o que acontece ao andar/girar com o botão direito do mouse). Se você girar
-- a câmera com o botão esquerdo, os ícones não acompanham esse giro.

local _, FT = ...

local CAMERA_BACK = 8      -- distância aproximada da câmera atrás do personagem (jardas)
local HORIZON = 0.55       -- altura do horizonte na tela (0 = base, 1 = topo)
local MIN_SCALE, MAX_SCALE = 0.45, 1.6

local ICONS = {
    herb = "Interface\\Icons\\Trade_Herbalism",
    ore  = "Interface\\Icons\\Trade_Mining",
}
local COLORS = {
    herb = { 0.3, 1.0, 0.3 },
    ore  = { 1.0, 0.7, 0.2 },
}

local PI, TWO_PI = math.pi, math.pi * 2
local atan2, sin, cos, tan, sqrt, rad = math.atan2, math.sin, math.cos, math.tan, math.sqrt, math.rad
local min, max = math.min, math.max

-- Frame raiz: cobre exatamente o WorldFrame (a área onde o mundo 3D é desenhado).
local overlay = CreateFrame("Frame", "FarmTimeOverlay", UIParent)
overlay:SetAllPoints(WorldFrame)
overlay:SetFrameStrata("BACKGROUND")
overlay:EnableMouse(false)
overlay:Hide()
FT.overlay = overlay

---------------------------------------------------------------------------
-- Pool de marcadores
---------------------------------------------------------------------------
local markers = {}

local function CreateMarker()
    local m = CreateFrame("Frame", nil, overlay)
    m:SetSize(48, 48)

    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetAllPoints()
    m.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    m.glow = m:CreateTexture(nil, "OVERLAY")
    m.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    m.glow:SetBlendMode("ADD")
    m.glow:SetPoint("CENTER")

    m.text = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    m.text:SetPoint("TOP", m, "BOTTOM", 0, -2)
    return m
end

local function GetMarker(i)
    local m = markers[i]
    if not m then
        m = CreateMarker()
        markers[i] = m
    end
    return m
end

---------------------------------------------------------------------------
-- Projeção mundo -> tela
---------------------------------------------------------------------------
local function NormalizeAngle(a)
    a = a % TWO_PI
    if a > PI then a = a - TWO_PI end
    return a
end

-- Retorna sx, sy (coordenadas no overlay, origem no canto inferior esquerdo),
-- escala, e se o ponto está dentro do campo de visão.
local function Project(dx, dy, dz, facing, W, H)
    local db = FT.db
    local halfFov = rad(db.fov) / 2
    local focal = (W / 2) / tan(halfFov)

    -- X = norte, Y = oeste; ângulos crescem no sentido anti-horário (igual GetPlayerFacing)
    local rel = NormalizeAngle(atan2(dy, dx) - facing) -- >0 = à esquerda
    local dist = sqrt(dx * dx + dy * dy)

    local depth = dist * cos(rel) + CAMERA_BACK  -- distância "para frente" a partir da câmera
    local side  = dist * sin(rel)                 -- deslocamento lateral (positivo = esquerda)

    if depth <= 1 or math.abs(rel) > halfFov then
        -- Fora do campo de visão: prende na borda esquerda/direita.
        local sx = (rel > 0) and 40 or (W - 40)
        local sy = H * HORIZON
        return sx, sy, MIN_SCALE, false
    end

    local sx = W / 2 - focal * side / depth
    local sy = H * HORIZON - focal * (db.cameraHeight - dz) / depth
    local scale = max(MIN_SCALE, min(MAX_SCALE, 20 / depth * 1.4))
    return sx, sy, scale, true
end

---------------------------------------------------------------------------
-- Atualização
---------------------------------------------------------------------------
local function Update()
    local db = FT.db
    local px, py, pz, inst = FT:GetPlayerWorldPosition()
    local facing = GetPlayerFacing()
    local nodes = inst and FT:GetNodes(inst)

    local used = 0
    if px and facing and nodes then
        local W, H = overlay:GetWidth(), overlay:GetHeight()
        local range2 = db.maxRange * db.maxRange

        for _, n in ipairs(nodes) do
            local dx, dy = n.x - px, n.y - py
            local d2 = dx * dx + dy * dy
            if d2 <= range2 then
                local sx, sy, scale, inView = Project(dx, dy, (n.z or pz) - pz, facing, W, H)
                if inView or db.showEdgeArrows then
                    used = used + 1
                    local m = GetMarker(used)
                    local size = db.iconSize * scale
                    local c = COLORS[n.kind] or COLORS.herb

                    m:SetSize(size, size)
                    m:ClearAllPoints()
                    m:SetPoint("CENTER", overlay, "BOTTOMLEFT", sx, sy)
                    m.icon:SetTexture(ICONS[n.kind] or ICONS.herb)
                    m.glow:SetSize(size * 1.8, size * 1.8)
                    m.glow:SetVertexColor(c[1], c[2], c[3])
                    m.text:SetFormattedText("%s\n%d jd", n.name or "", sqrt(d2))
                    m:SetAlpha(inView and 1 or 0.5)
                    m:Show()
                end
            end
        end
    end

    for i = used + 1, #markers do
        markers[i]:Hide()
    end
end

---------------------------------------------------------------------------
-- Controle (liga/desliga, combate, ticker)
---------------------------------------------------------------------------
local ticker
local inCombat = false

local function ShouldShow()
    local db = FT.db
    if not db or not db.enabled then return false end
    if db.hideInCombat and inCombat then return false end
    return true
end

function FT:RefreshOverlayState()
    if ShouldShow() then
        overlay:Show()
        if not ticker then
            ticker = C_Timer.NewTicker(self.db.updateRate, Update)
        end
    else
        overlay:Hide()
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
    end
end

function FT:OnInitialize()
    self:Print("carregado. Digite /ft help para os comandos.")
end

-- InCombatLockdown() ainda retorna false durante PLAYER_REGEN_DISABLED,
-- então o estado de combate é controlado pelos próprios eventos.
FT:RegisterEvent("PLAYER_ENTERING_WORLD", function(self)
    inCombat = UnitAffectingCombat("player") and true or false
    self:RefreshOverlayState()
end)
FT:RegisterEvent("PLAYER_REGEN_DISABLED", function(self)
    inCombat = true
    self:RefreshOverlayState()
end)
FT:RegisterEvent("PLAYER_REGEN_ENABLED", function(self)
    inCombat = false
    self:RefreshOverlayState()
end)
