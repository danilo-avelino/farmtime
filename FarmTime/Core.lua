-- Farm Time - Core
-- Namespace, configurações salvas, eventos e comandos de barra.

local ADDON_NAME, FT = ...
_G.FarmTime = FT

FT.defaults = {
    enabled     = true,
    maxRange    = 120,   -- jardas: nós além disso não são desenhados
    fov         = 90,    -- campo de visão horizontal assumido (graus)
    cameraHeight = 6,    -- altura aproximada da câmera (jardas) usada na projeção
    iconSize    = 48,    -- tamanho do ícone a ~20 jardas
    updateRate  = 0.05,  -- segundos entre atualizações do overlay
    showEdgeArrows = true, -- mostra nós fora do campo de visão na borda da tela
    hideInCombat = true,
    nodes = {},          -- [instanceID] = { {x=, y=, z=, kind=, name=, t=}, ... }
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function FT:Print(...)
    print("|cff33ff99Farm Time|r:", ...)
end

-- Posição do jogador em coordenadas de mundo (jardas).
-- UnitPosition retorna (posY, posX, posZ, instanceID); X aponta para o norte,
-- Y aponta para o oeste. Retorna nil dentro de instâncias (restrição da API).
function FT:GetPlayerWorldPosition()
    local y, x, z, instanceID = UnitPosition("player")
    if not x then return nil end
    return x, y, z or 0, instanceID
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
FT.eventFrame = frame
FT.handlers = {}

function FT:RegisterEvent(event, fn)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], fn)
    frame:RegisterEvent(event)
end

function FT:RegisterUnitEvent(event, unit, fn)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], fn)
    frame:RegisterUnitEvent(event, unit)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = FT.handlers[event]
    if not list then return end
    for _, fn in ipairs(list) do fn(FT, ...) end
end)

FT:RegisterEvent("ADDON_LOADED", function(self, name)
    if name ~= ADDON_NAME then return end
    FarmTimeDB = FarmTimeDB or {}
    CopyDefaults(self.defaults, FarmTimeDB)
    self.db = FarmTimeDB
    if self.OnInitialize then self:OnInitialize() end
end)

---------------------------------------------------------------------------
-- Comandos: /farmtime ou /ft
---------------------------------------------------------------------------
local function CountNodes()
    local total = 0
    for _, list in pairs(FT.db.nodes) do total = total + #list end
    return total
end

local commands = {}

commands[""] = function()
    FT.db.enabled = not FT.db.enabled
    FT:Print(FT.db.enabled and "ativado" or "desativado")
    FT:RefreshOverlayState()
end

commands.fov = function(arg)
    local v = tonumber(arg)
    if v and v >= 30 and v <= 150 then
        FT.db.fov = v
        FT:Print("FOV =", v)
    else
        FT:Print("uso: /ft fov <30-150>  (atual:", FT.db.fov .. ")")
    end
end

commands.range = function(arg)
    local v = tonumber(arg)
    if v and v >= 10 and v <= 500 then
        FT.db.maxRange = v
        FT:Print("alcance =", v, "jardas")
    else
        FT:Print("uso: /ft range <10-500>  (atual:", FT.db.maxRange .. ")")
    end
end

commands.height = function(arg)
    local v = tonumber(arg)
    if v and v > 0 and v <= 50 then
        FT.db.cameraHeight = v
        FT:Print("altura da câmera =", v)
    else
        FT:Print("uso: /ft height <1-50>  (atual:", FT.db.cameraHeight .. ")")
    end
end

commands.size = function(arg)
    local v = tonumber(arg)
    if v and v >= 16 and v <= 128 then
        FT.db.iconSize = v
        FT:Print("tamanho do ícone =", v)
    else
        FT:Print("uso: /ft size <16-128>  (atual:", FT.db.iconSize .. ")")
    end
end

commands.list = function()
    FT:Print(CountNodes(), "nós salvos no total")
    local px, py, _, inst = FT:GetPlayerWorldPosition()
    if not px then return end
    for _, n in ipairs(FT.db.nodes[inst] or {}) do
        local d = math.sqrt((n.x - px) ^ 2 + (n.y - py) ^ 2)
        if d <= FT.db.maxRange then
            FT:Print(string.format("  %s (%s) - %.0f jd", n.name or "?", n.kind, d))
        end
    end
end

commands.clear = function(arg)
    if arg == "all" then
        wipe(FT.db.nodes)
        FT:Print("todos os nós apagados")
    else
        local _, _, _, inst = FT:GetPlayerWorldPosition()
        if inst then FT.db.nodes[inst] = nil end
        FT:Print("nós deste continente apagados (use '/ft clear all' para tudo)")
    end
end

-- Cria um nó falso 30 jardas à frente do personagem para calibrar FOV/altura.
commands.test = function()
    local px, py, pz, inst = FT:GetPlayerWorldPosition()
    local facing = GetPlayerFacing()
    if not px or not facing then
        FT:Print("posição indisponível aqui (instância?)")
        return
    end
    local x = px + math.cos(facing) * 30
    local y = py + math.sin(facing) * 30
    FT:AddNode(inst, x, y, pz, "herb", "Nó de teste")
    FT:Print("nó de teste criado 30 jardas à frente")
end

commands.help = function()
    FT:Print("comandos:")
    print("  /ft                 - liga/desliga o overlay")
    print("  /ft fov <graus>     - campo de visão usado na projeção")
    print("  /ft range <jardas>  - alcance máximo de exibição")
    print("  /ft height <jardas> - altura da câmera (ajusta a posição vertical)")
    print("  /ft size <px>       - tamanho base dos ícones")
    print("  /ft list            - lista nós próximos")
    print("  /ft test            - cria um nó de teste à frente")
    print("  /ft clear [all]     - apaga nós do continente atual (ou todos)")
end

SLASH_FARMTIME1 = "/farmtime"
SLASH_FARMTIME2 = "/ft"
SlashCmdList.FARMTIME = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local fn = commands[cmd] or commands.help
    fn(arg)
end
