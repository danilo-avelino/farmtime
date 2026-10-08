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
local HEAD_HEIGHT      = 2    -- jardas: a câmera mira mais ou menos a cabeça do personagem

local COLORS = FT.Style.COLORS

-- Diâmetro (jardas) da área mostrada no minimapa em cada nível de zoom.
local MINIMAP_YARDS = {
    outdoor = { [0] = 466 + 2/3, [1] = 400, [2] = 333 + 1/3, [3] = 266 + 2/3, [4] = 200, [5] = 133 + 1/3 },
    indoor  = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
}

local sqrt, atan2, sin, cos, tan, rad = math.sqrt, math.atan2 or math.atan, math.sin, math.cos, math.tan, math.rad
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
    -- Ordem do retorno: norte, oeste, altura, instância (o mesmo que o .gps X, Y).
    local ok, x, y, z, instanceID = pcall(UnitPosition, "player")
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
    if self.ShareNode then self:ShareNode("G", node, inst) end
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
local function IsConfirmed(node)
    if not node.confirmedAt then return false end
    if node.gatheredAt and node.gatheredAt >= node.confirmedAt then return false end
    return time() - node.confirmedAt < CONFIRM_TTL
end

-- grace: segundos após a coleta em que o nó NÃO pode ser reconfirmado
-- (o objeto ainda existe enquanto o saque está aberto e o ponto do minimapa
-- demora um pouco para sumir).
local GRACE_NEAR    = 120
local GRACE_MINIMAP = 15

local function Confirm(name, x, y, inst, tolerance, grace)
    local list = NodesHere(inst)
    if not list then return end
    local node = FindNode(list, name, x, y, tolerance)
    if not node then return end
    if grace and node.gatheredAt and time() - node.gatheredAt < grace then return end
    node.missSince = nil
    if FT.db.debug and not IsConfirmed(node) then
        FT:Print(string.format(FT.L.NODE_CONFIRMED, node.name))
    end
    local was = IsConfirmed(node)
    node.confirmedAt = time()
    -- Só avisa os outros na mudança "não confirmado -> confirmado".
    if not was and FT.ShareNode then FT:ShareNode("C", node, inst) end
end

-- Nó recebido de outro jogador (Share.lua). code: "C" = confirmado agora,
-- "G" = coletado agora (sumiu). Cria o nó se você ainda não tinha.
function FT:ApplySharedNode(code, inst, x, y, kind, name)
    if not (name and (kind == "herb" or kind == "ore")) then return end
    local list = NodesHere(inst, true)
    local node = FindNode(list, name, x, y, MERGE_DISTANCE)
    if not node then
        node = { x = x, y = y, name = name, kind = kind, count = 0, shared = true }
        table.insert(list, node)
    end
    if code == "C" then
        node.confirmedAt = time()
    elseif code == "G" then
        node.gatheredAt = time()
        node.confirmedAt = nil
    end
end

-- a) Alvo de interação do jogo (você está perto do nó).
function FT:ConfirmNodeNearPlayer(name)
    local x, y, _, inst = PlayerPosition()
    if x and name then Confirm(name, x, y, inst, MERGE_DISTANCE, GRACE_NEAR) end
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
    return px + up * upX + right * rightX, py + up * upY + right * rightY, inst, perPixel
end

local function CleanLine(text)
    return text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

-- Mouse sobre o minimapa:
--  * o tooltip traz o nome de um nó salvo naquele ponto -> confirmado;
--  * o cursor está bem em cima de um nó confirmado e o tooltip NÃO traz o
--    nome dele (meio segundo seguido) -> o ponto não está lá; perde a confirmação.
local MISS_PIXELS = 4    -- quão perto (em pixels do minimapa) o cursor precisa estar do nó
local MISS_TIME   = 0.5

-- Frame sob o mouse (GetMouseFoci nos clientes novos, GetMouseFocus nos antigos).
local function MouseFocus()
    if GetMouseFoci then
        local ok, foci = pcall(GetMouseFoci)
        if ok and type(foci) == "table" then return foci[1] end
    end
    if GetMouseFocus then
        local ok, f = pcall(GetMouseFocus)
        if ok then return f end
    end
end

local function ScanMinimapTooltip()
    if not Minimap:IsMouseOver() then return end
    -- Se o mouse está sobre um marcador de OUTRO addon no minimapa (GatherLite,
    -- GatherMate2, HandyNotes, Questie...), o tooltip é desse marcador e mostra
    -- onde a erva JÁ EXISTIU, não o ponto de rastreamento do jogo. Ignora.
    local focus = MouseFocus()
    if focus and focus ~= Minimap then return end
    local x, y, inst, perPixel = CursorWorldPosition()
    if not x then return end

    local names = {}
    if GameTooltip:IsShown() then
        for i = 1, GameTooltip:NumLines() do
            local fs = _G["GameTooltipTextLeft" .. i]
            local text = fs and fs:GetText()
            if text then
                for line in CleanLine(text):gmatch("[^\n]+") do
                    local name = line:match("^%s*(.-)%s*$")
                    if name ~= "" then
                        names[name] = true
                        Confirm(name, x, y, inst, CONFIRM_DISTANCE, GRACE_MINIMAP)
                    end
                end
            end
        end
    end

    local list = NodesHere(inst)
    if not list then return end
    local near = math.max(6, MISS_PIXELS * perPixel)
    for _, n in ipairs(list) do
        if n.confirmedAt and not names[n.name] and Distance2(n, x, y) <= near * near then
            n.missSince = n.missSince or GetTime()
            if GetTime() - n.missSince >= MISS_TIME then
                n.confirmedAt, n.missSince = nil, nil
                if FT.db.debug then FT:Print(string.format(FT.L.NODE_MISSING, n.name)) end
            end
        elseif n.missSince and names[n.name] then
            n.missSince = nil
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

-- Cada marcador é uma placa compacta: ícone do recurso + distância.
local function GetMarker(i)
    local m = markers[i]
    if m then return m end
    m = FT.Style.CreatePlate(overlay, { titleFont = "GameFontHighlightSmall", barHeight = 2 })
    markers[i] = m
    return m
end

-- Põe a placa com o centro do ícone exatamente no ponto projetado.
local function PlaceMarker(m, sx, sy, size)
    m:ClearAllPoints()
    m:SetPoint("LEFT", overlay, "BOTTOMLEFT", sx - size / 2 - 4, sy)
end

-- Modelo de câmera: atrás do personagem, a GetCameraZoom() jardas, inclinada
-- "pitch" graus para baixo, mirando a cabeça (que fica no centro da tela).
-- O jogo não informa a inclinação nem o giro da câmera para addons, então o
-- ângulo vem da configuração (calibre com /ft calibrate) e o giro é o do
-- personagem. Retorna x, y na tela (origem embaixo à esquerda) e a
-- profundidade, ou nil se o ponto estiver fora da tela ou atrás da câmera.
local function CameraDistance()
    local ok, zoom = pcall(GetCameraZoom)
    if ok and type(zoom) == "number" and not (issecretvalue and issecretvalue(zoom)) then return zoom end
    return 15
end

local function Project(dx, dy, dz, facing, W, H)
    local db = FT.db
    local pitch = rad(db.hudPitch)
    local d = CameraDistance()
    local cf, sf = cos(facing), sin(facing)
    local cp, sp = cos(pitch), sin(pitch)

    -- Vetor câmera -> ponto, nas direções frente (F), cima (U) e direita (R)
    -- do personagem. F = (cos f, sin f), R = (sin f, -cos f) no plano x/y.
    local vF = dx * cf + dy * sf + d * cp
    local vU = dz - HEAD_HEIGHT - d * sp
    local vR = dx * sf - dy * cf

    -- Para os eixos da câmera inclinada.
    local depth = cp * vF - sp * vU
    if depth <= 1 then return nil end
    local up = cp * vU + sp * vF

    local focal = (W / 2) / tan(rad(db.hudFov) / 2)
    local sx = W / 2 + focal * vR / depth
    local sy = H / 2 + focal * up / depth
    if sx < -40 or sx > W + 40 or sy < -40 or sy > H + 40 then return nil end
    return sx, sy, depth
end

-- Marcador temporário de calibração: fica onde você estava ao usar /ft calibrate.
local calibration -- { x, y, z, inst, until }

function FT:StartCalibration()
    local x, y, z, inst = PlayerPosition()
    if not x then
        self:Print(self.L.CALIBRATE_NO_POS)
        return
    end
    calibration = { x = x, y = y, z = z, inst = inst, expires = GetTime() + 300 }
    self:Print(self.L.CALIBRATE_HELP)
end

---------------------------------------------------------------------------
-- Seta para o nó confirmado mais próximo (estilo TomTom)
---------------------------------------------------------------------------
local ARROW_TEXTURE = "Interface\\AddOns\\FarmTime\\Media\\Arrow"

local arrow = CreateFrame("Frame", "FarmTimeArrow", UIParent)
arrow:SetSize(56, 56)
arrow:SetPoint("TOP", UIParent, "TOP", 0, -110)
arrow:SetFrameStrata("MEDIUM")
arrow:SetClampedToScreen(true)
arrow:SetMovable(true)
arrow:EnableMouse(true)
arrow:RegisterForDrag("LeftButton")
arrow:Hide()

arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
arrow.tex:SetAllPoints()
arrow.tex:SetTexture(ARROW_TEXTURE)

-- Embaixo da seta, a mesma placa dos nós: [ícone] Nome / distância.
arrow.plate = FT.Style.CreatePlate(arrow)
arrow.plate:SetPoint("TOP", arrow, "BOTTOM", 0, -2)

arrow:SetScript("OnDragStart", arrow.StartMoving)
arrow:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, px, py = self:GetPoint(1)
    FT.db.arrowPos = { point = point, relPoint = relPoint, x = px, y = py }
end)

FT:RegisterEvent("PLAYER_LOGIN", function(self)
    local pos = self.db.arrowPos
    if pos and pos.point then
        arrow:ClearAllPoints()
        arrow:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    end
end)

local function UpdateArrow(list, x, y, facing)
    local db = FT.db
    local best, bestD2
    if list and db.arrowEnabled then
        local maxD2 = db.arrowRange * db.arrowRange
        local target = FT.currentTargetName
        for _, n in ipairs(list) do
            local d2 = Distance2(n, x, y)
            local isTarget = target and n.name == target and d2 < MERGE_DISTANCE * MERGE_DISTANCE
            -- A seta só aponta para nós DISPONÍVEIS (confirmados), mesmo com a
            -- opção de mostrar os indisponíveis ligada.
            if d2 <= maxD2 and not isTarget and IsConfirmed(n) and FT:KindVisible(n.kind)
                and (not bestD2 or d2 < bestD2) then
                best, bestD2 = n, d2
            end
        end
    end
    if not best then
        arrow:Hide()
        return
    end

    -- Ângulo do nó em relação à frente do personagem (> 0 = à esquerda).
    -- A seta desenhada aponta para cima; SetRotation gira no sentido anti-horário.
    local rel = atan2(best.y - y, best.x - x) - facing
    arrow.tex:SetRotation(rel)

    local confirmed = IsConfirmed(best)
    local c = confirmed and (COLORS[best.kind] or COLORS.herb) or COLORS.grey
    arrow.tex:SetVertexColor(c[1], c[2], c[3])
    arrow.plate:SetContent(FT:GetNodeIcon(best.name) or "Interface\\Icons\\INV_Misc_QuestionMark",
        best.name, string.format(FT.L.HUD_DISTANCE, math.floor(sqrt(bestD2) + 0.5)),
        COLORS[best.kind] or COLORS.herb, 24, not confirmed)
    arrow.plate:SetAlpha(1)
    arrow:Show()
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
            local confirmed = IsConfirmed(n)
            if d2 <= range2 and not isTarget and (confirmed or db.hudShowUnconfirmed)
                and FT:KindVisible(n.kind) then
                local sx, sy, depth = Project(n.x - x, n.y - y, (n.z and z) and (n.z - z) or 0, facing, W, H)
                if sx then
                    used = used + 1
                    local m = GetMarker(used)
                    local size = math.floor(math.max(14, math.min(40, db.iconSize * 30 / depth)))
                    m.icon:SetVertexColor(1, 1, 1)
                    m:SetContent(FT:GetNodeIcon(n.name) or "Interface\\Icons\\INV_Misc_QuestionMark",
                        string.format(FT.L.HUD_DISTANCE, math.floor(sqrt(d2) + 0.5)), nil,
                        COLORS[n.kind] or COLORS.herb, size, not confirmed)
                    PlaceMarker(m, sx, sy, size)
                    m:Show()
                end
            end
        end
    end
    -- Marcador de calibração (losango branco no ponto salvo).
    if calibration and x and facing and db.hudEnabled then
        if GetTime() > calibration.expires or calibration.inst ~= inst then
            calibration = nil
        else
            local cz = (calibration.z and z) and (calibration.z - z) or 0
            local sx, sy, depth = Project(calibration.x - x, calibration.y - y, cz, facing, overlay:GetWidth(), overlay:GetHeight())
            if sx then
                used = used + 1
                local m = GetMarker(used)
                local dist = sqrt((calibration.x - x) ^ 2 + (calibration.y - y) ^ 2)
                m:SetContent("Interface\\Buttons\\WHITE8X8",
                    string.format(FT.L.HUD_DISTANCE, math.floor(dist + 0.5)), nil, { 1, 0.25, 0.25 }, 16)
                m.icon:SetVertexColor(1, 0.25, 0.25)
                PlaceMarker(m, sx, sy, 16)
                m:Show()
            end
        end
    end
    for i = used + 1, #markers do markers[i]:Hide() end
    UpdateArrow(list, x, y, facing)
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
