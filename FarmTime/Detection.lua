-- Farm Time - Detecção de nós
--
-- A API de addons NÃO permite listar objetos do mundo (ervas, minérios etc.)
-- nem ler os pontos do minimapa. Por isso a detecção aqui é por aprendizado:
-- toda vez que você coleta um nó, o addon grava a posição do personagem
-- naquele momento. Nas próximas passagens pela área o nó aparece no overlay.

local _, FT = ...

local MERGE_DISTANCE = 10 -- jardas: nós mais próximos que isso são o mesmo nó

-- Nomes localizados dos feitiços de coleta. Em todas as expansões os casts
-- de coleta usam o mesmo nome dos feitiços base (vários IDs, mesmo nome).
local GetSpellName = (C_Spell and C_Spell.GetSpellName) or function(id)
    return (GetSpellInfo(id))
end

local BASE_SPELLS = {
    herb = 2366, -- Herb Gathering / Herborismo
    ore  = 2575, -- Mining / Mineração
}

local spellNameToKind = {}

local function BuildSpellNames()
    for kind, id in pairs(BASE_SPELLS) do
        local name = GetSpellName(id)
        if name then spellNameToKind[name] = kind end
    end
end

local function KindForSpell(spellID)
    local name = spellID and GetSpellName(spellID)
    return name and spellNameToKind[name]
end

function FT:AddNode(instanceID, x, y, z, kind, name)
    local list = self.db.nodes[instanceID]
    if not list then
        list = {}
        self.db.nodes[instanceID] = list
    end
    for _, n in ipairs(list) do
        if n.kind == kind and (n.x - x) ^ 2 + (n.y - y) ^ 2 < MERGE_DISTANCE ^ 2 then
            n.t = time()
            n.count = (n.count or 1) + 1
            if name then n.name = name end
            return n, false
        end
    end
    local node = { x = x, y = y, z = z, kind = kind, name = name, t = time(), count = 1 }
    table.insert(list, node)
    return node, true
end

-- Nós do continente/instância atual (usado pelo overlay).
function FT:GetNodes(instanceID)
    return self.db.nodes[instanceID]
end

---------------------------------------------------------------------------
-- Eventos de cast
---------------------------------------------------------------------------
local pending = {} -- [castGUID] = { kind, target }

FT:RegisterEvent("PLAYER_LOGIN", function()
    BuildSpellNames()
end)

FT:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player", function(self, unit, target, castGUID, spellID)
    local kind = KindForSpell(spellID)
    if kind then
        pending[castGUID] = { kind = kind, target = target }
    end
end)

FT:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", function(self, unit, castGUID, spellID)
    local info = pending[castGUID]
    if not info then return end
    pending[castGUID] = nil

    local x, y, z, inst = self:GetPlayerWorldPosition()
    if not x then return end

    local name = info.target ~= "" and info.target or nil
    local _, isNew = self:AddNode(inst, x, y, z, info.kind, name)
    if isNew then
        self:Print("novo nó registrado:", name or info.kind)
    end
end)

local function Forget(self, unit, castGUID)
    if castGUID then pending[castGUID] = nil end
end
FT:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player", Forget)
FT:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player", Forget)
