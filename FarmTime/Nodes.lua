-- Farm Time - Nós salvos e marcadores 3D
--
-- 1. Guarda a posição de cada erva/minério que você coleta (a posição do
--    personagem na hora da coleta, a poucas jardas do nó).
-- 2. Desenha o ícone do recurso sobre a visão do personagem, na direção e
--    distância do nó. A API não dá acesso à câmera nem a WorldToScreen, então
--    é uma projeção aproximada: supõe a câmera atrás do personagem, olhando
--    para onde ele está virado (acompanha bem quando você anda/gira com o
--    botão direito do mouse; não acompanha giro de câmera com o esquerdo).
-- 3. O marcador fica CINZA até ser confirmado. Confirma quando:
--    - você passa o mouse sobre o ponto do nó no minimapa (rastreamento de
--      ervas/minérios ligado): o tooltip do minimapa traz o nome, e a posição
--      do cursor no minimapa é convertida para posição no mundo;
--    - ou o jogo escolhe esse nó como alvo de interação (você está perto dele).
--    Depois de coletado, volta a ficar cinza. A confirmação vale por alguns
--    minutos (alguém pode coletar antes de você).

local _, FT = ...

local MERGE_DISTANCE   = 12   -- jardas: mesmo nome a menos disso = mesmo nó
local CONFIRM_DISTANCE = 25   -- jardas: tolerância ao confirmar pelo minimapa
local CONFIRM_TTL      = 300  -- segundos que uma confirmação vale
local CAMERA_BACK      = 8    -- distância aproximada da câmera atrás do personagem
local CAMERA_HEIGHT    = 6
local HORIZON          = 0.55 -- altura do horizonte na tela (0 = base, 1 = topo)

local COLORS = {
    herb = { 0.3, 1.0, 0.3 },
    ore  = { 1.0, 0.7, 0.2 },
}

-- Diâmetro (jardas) da área mostrada no minimapa em cada nível de zoom.
local MINIMAP_YARDS = {
    outdoor = { [0] = 466 + 2/3, [1] = 400, [2] = 333 + 1/3, [3] = 266 + 2/3, [4] = 200, [5] = 133 + 1/3 },
    indoor  = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
}

local sqrt, atan2, sin, cos, tan, rad = math.sqrt, math.atan2 or math.atan, math.sin, math.cos, math.tan, math.rad
local PI, TWO_PI = math.pi, math.pi * 2
local GetCVar = (C_CVar and C_CVar.GetCVar) or GetCVar

---------------------------------------------------------------------------
-- Posição
---------------------------------------------------------------------------
local function Usable(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
end

-- Coordenadas de mundo em jardas: x = norte, y = oeste; z pode ser nil.
-- 1º UnitPosition; se o cliente bloquear (a API nova pode bloquear), usa a
-- posição no mapa convertida para o mundo, como fazem os addons de setas.
local function PlayerPosition()
    local ok, y, x, z, instanceID = pcall(UnitPosition, "player")
    if ok and Usable(x) and Usable(y) then
        FT.positionSource = "UnitPosition"
        return x, y, Usable(z) and z or nil, instanceID
    end
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetWorldPosFromMapPos then
        local okm, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if okm and Usable(mapID) then
            local okp, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
            if okp and pos then
                local okw, continent, world = pcall(C_Map.GetWorldPosFromMapPos, mapID, pos)
                if okw and world and Usable(world.x) and Usable(world.y) then
                    FT.positionSource = "C_Map"
                    return world.x, world.y, nil, continent
                end
            end
        end
    end
    FT.positionSource = nil
end

-- Direção para onde o personagem olha (radianos, 0 = norte, anti-horário).
-- Se GetPlayerFacing estiver bloqueado, estima pela direção do movimento.
local lastX, lastY, movedHeading
local function PlayerFacing(x, y)
    local ok, f = pcall(GetPlayerFacing)
    if ok and Usable(f) then
        FT.facingSource = "GetPlayerFacing"
        return f
    end
    if x then
        if lastX then
            local dx, dy = x - lastX, y - lastY
            if dx * dx + dy * dy > 0.25 then
                movedHeading = atan2(dy, dx)
                lastX, lastY = x, y
            end
        else
            lastX, lastY = x, y
        end
    end
    FT.facingSource = movedHeading and "movement" or nil
    return movedHeading
end

local function Distance2(n, x, y)
    local dx, dy = n.x - x, n.y - y
    return dx * dx + dy * dy
end

local function NodesHere(instanceID, create)
    local list = FT.db.nodes[instanceID]
    if not list and create then
        list = {}
        FT.db.nodes[instanceID] = list
    end
    return list
end

local function FindNode(list, name, x, y, maxDist)
    local best, bestD2 = nil, maxDist * maxDist
    for _, n in ipairs(list) do
        if n.name == name then
            local d2 = Distance2(n, x, y)
            if d2 <= bestD2 then best, bestD2 = n, d2 end
        end
    end
    return best
end

---------------------------------------------------------------------------
-- Gravar ao coletar
---------------------------------------------------------------------------
function FT:RecordNode(kind, name)
    if not (name and (kind == "herb" or kind == "ore")) then return end
    local x, y, z, inst = PlayerPosition()
    if not x then return end
    local list = NodesHere(inst, true)
    local node = FindNode(list, name, x, y, MERGE_DISTANCE)
    if node then
        -- Média com a posição anterior: fica mais perto do nó a cada coleta.
        node.x, node.y = (node.x + x) / 2, (node.y + y) / 2
        node.count = (node.count or 1) + 1
    else
        node = { x = x, y = y, z = z, name = name, kind = kind, count = 1 }
        table.insert(list, node)
        if self.db.debug then self:Print(string.format(self.L.NODE_SAVED, name)) end
    end
    node.gatheredAt = time()
    node.confirmedAt = nil
    self.lastRecordAt = GetTime()
end

FT:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", function(self, unit, castGUID)
    local ctx = self.gatherContext
    if ctx and ctx.castGUID == castGUID then
        self:RecordNode(ctx.kind, ctx.name)
    end
end)

-- Reserva: se o cast não foi reconhecido, grava ao abrir o saque de um objeto
-- (GameObject) logo depois de o jogo ter mostrado uma erva/minério como alvo.
FT:RegisterEvent("LOOT_OPENED", function(self)
    if self.lastRecordAt and GetTime() - self.lastRecordAt < 5 then return end
    local t = self.lastGatherTarget
    if not t or GetTime() - t.time > 15 then return end
    local ok, guid = pcall(GetLootSourceInfo, 1)
    if ok and type(guid) == "string" and guid:find("^GameObject") then
        self:RecordNode(t.kind, t.name)
    end
end)

---------------------------------------------------------------------------
-- Confirmação
---------------------------------------------------------------------------
local function Confirm(name, x, y, inst, tolerance)
    local list = NodesHere(inst)
    if not list then return end
    local node = FindNode(list, name, x, y, tolerance)
    if node then node.confirmedAt = time() end
end

local function IsConfirmed(node)
    if not node.confirmedAt then return false end
    if node.gatheredAt and node.gatheredAt >= node.confirmedAt then return false end
    return time() - node.confirmedAt < CONFIRM_TTL
end

-- a) Alvo de interação do jogo (você está perto do nó).
function FT:ConfirmNodeNearPlayer(name)
    local x, y, _, inst = PlayerPosition()
    if x and name then Confirm(name, x, y, inst, MERGE_DISTANCE) end
end

-- b) Tooltip do minimapa: posição do cursor no minimapa -> posição no mundo.
local function CursorWorldPosition()
    local px, py, _, inst = PlayerPosition()
    if not px then return nil end
    local mx, my = Minimap:GetCenter()
    if not mx then return nil end
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local right, up = cx / scale - mx, cy / scale - my -- pixels a partir do centro

    local indoors = IsIndoors and IsIndoors()
    local zoom = Minimap:GetZoom() or 0
    local yards = (indoors and MINIMAP_YARDS.indoor or MINIMAP_YARDS.outdoor)[zoom]
    if not yards then return nil end
    local perPixel = yards / Minimap:GetWidth()
    right, up = right * perPixel, up * perPixel

    -- Direções do minimapa no mundo (x = norte, y = oeste).
    local upX, upY, rightX, rightY = 1, 0, 0, -1
    if GetCVar("rotateMinimap") == "1" then
        local f = PlayerFacing() or 0
        upX, upY = cos(f), sin(f)
        rightX, rightY = sin(f), -cos(f)
    end
    return px + up * upX + right * rightX, py + up * upY + right * rightY, inst
end

local function CleanLine(text)
    return text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function ScanMinimapTooltip()
    if not (GameTooltip:IsShown() and Minimap:IsMouseOver()) then return end
    local x, y, inst = CursorWorldPosition()
    if not x then return end
    for i = 1, GameTooltip:NumLines() do
        local fs = _G["GameTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text then
            for line in CleanLine(text):gmatch("[^\n]+") do
                local name = line:match("^%s*(.-)%s*$")
                if name ~= "" then Confirm(name, x, y, inst, CONFIRM_DISTANCE) end
            end
        end
    end
end

hooksecurefunc(GameTooltip, "Show", function()
    if FT.db and FT.db.hudEnabled then pcall(ScanMinimapTooltip) end
end)

-- O texto do tooltip do minimapa muda sem novo Show enquanto o mouse anda.
local minimapWatcher = CreateFrame("Frame")
local elapsed = 0
minimapWatcher:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.2 then return end
    elapsed = 0
    if FT.db and FT.db.hudEnabled and Minimap:IsMouseOver() then pcall(ScanMinimapTooltip) end
end)

---------------------------------------------------------------------------
-- Marcadores na tela
---------------------------------------------------------------------------
local overlay = CreateFrame("Frame", "FarmTimeNodeOverlay", UIParent)
overlay:SetAllPoints(WorldFrame)
overlay:SetFrameStrata("BACKGROUND")
overlay:EnableMouse(false)

local markers = {}

local function GetMarker(i)
    local m = markers[i]
    if m then return m end
    m = CreateFrame("Frame", nil, overlay)
    m.bg = m:CreateTexture(nil, "BACKGROUND")
    m.bg:SetPoint("TOPLEFT", -2, 2)
    m.bg:SetPoint("BOTTOMRIGHT", 2, -2)
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetAllPoints()
    m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    m.text = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    m.text:SetPoint("TOP", m, "BOTTOM", 0, -2)
    markers[i] = m
    return m
end

local function NormalizeAngle(a)
    a = a % TWO_PI
    if a > PI then a = a - TWO_PI end
    return a
end

-- Projeção aproximada. Retorna x, y na tela (origem embaixo à esquerda) e a
-- profundidade, ou nil se o nó estiver fora do campo de visão.
local function Project(dx, dy, dz, facing, W, H, fov)
    local rel = NormalizeAngle(atan2(dy, dx) - facing) -- > 0 = à esquerda
    local halfFov = rad(fov) / 2
    if math.abs(rel) > halfFov then return nil end
    local dist = sqrt(dx * dx + dy * dy)
    local depth = dist * cos(rel) + CAMERA_BACK
    if depth <= 1 then return nil end
    local focal = (W / 2) / tan(halfFov)
    local sx = W / 2 - focal * (dist * sin(rel)) / depth
    local sy = H * HORIZON - focal * (CAMERA_HEIGHT - dz) / depth
    return sx, sy, depth
end

local function UpdateMarkers()
    local db = FT.db
    local used = 0
    local x, y, z, inst = PlayerPosition()
    local facing = PlayerFacing(x, y)
    local list = x and facing and NodesHere(inst)

    if list and db.hudEnabled then
        local W, H = overlay:GetWidth(), overlay:GetHeight()
        local range2 = db.hudRange * db.hudRange
        local target = FT.currentTargetName
        for _, n in ipairs(list) do
            local d2 = Distance2(n, x, y)
            -- O nó que já é alvo de interação ganha a placa grande; não duplica.
            local isTarget = target and n.name == target and d2 < MERGE_DISTANCE * MERGE_DISTANCE
            if d2 <= range2 and not isTarget then
                local sx, sy, depth = Project(n.x - x, n.y - y, (n.z and z) and (n.z - z) or 0, facing, W, H, db.hudFov)
                if sx then
                    used = used + 1
                    local m = GetMarker(used)
                    local size = math.max(14, math.min(40, db.iconSize * 22 / depth))
                    local confirmed = IsConfirmed(n)
                    local c = COLORS[n.kind] or COLORS.herb

                    m:SetSize(size, size)
                    m:ClearAllPoints()
                    m:SetPoint("CENTER", overlay, "BOTTOMLEFT", sx, sy)
                    m.icon:SetTexture(FT:GetNodeIcon(n.name) or "Interface\\Icons\\INV_Misc_QuestionMark")
                    m.icon:SetDesaturated(not confirmed)
                    if confirmed then
                        m.bg:SetColorTexture(c[1], c[2], c[3], 0.9)
                        m:SetAlpha(1)
                    else
                        m.bg:SetColorTexture(0, 0, 0, 0.7)
                        m:SetAlpha(0.55)
                    end
                    m.text:SetFormattedText(FT.L.HUD_DISTANCE, math.floor(sqrt(d2) + 0.5))
                    m:Show()
                end
            end
        end
    end
    for i = used + 1, #markers do markers[i]:Hide() end
end

C_Timer.NewTicker(0.05, function()
    if FT.db then UpdateMarkers() end
end)

---------------------------------------------------------------------------
-- Comandos auxiliares
---------------------------------------------------------------------------
function FT:CountNodes()
    local total, here = 0, 0
    local _, _, _, inst = PlayerPosition()
    for id, list in pairs(self.db.nodes) do
        total = total + #list
        if id == inst then here = #list end
    end
    return total, here
end

function FT:ClearNodes(all)
    if all then
        wipe(self.db.nodes)
    else
        local _, _, _, inst = PlayerPosition()
        if inst then self.db.nodes[inst] = nil end
    end
end

-- Diagnóstico para /ft status.
function FT:PositionStatus()
    local x, y, z, inst = PlayerPosition()
    local facing = PlayerFacing(x, y)
    local _, here = self:CountNodes()
    return string.format("pos=%s (%s) facing=%s (%s) inst=%s nodes=%d",
        x and string.format("%.1f,%.1f", x, y) or "nil", tostring(self.positionSource),
        facing and string.format("%.2f", facing) or "nil", tostring(self.facingSource),
        tostring(inst), here)
end
