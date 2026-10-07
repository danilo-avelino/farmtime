-- Farm Time - Classificação de nós
--
-- O objeto que o jogo escolhe como "soft target" de interação chega como o
-- token de unidade "softinteract". Aqui decidimos se ele é erva, minério ou
-- outra coisa (baú, caixa de missão etc.), usando duas fontes:
--   1. o tooltip do objeto (linha "Herborismo"/"Mineração" que o jogo mostra)
--   2. nomes aprendidos: todo nó que você coleta fica gravado por nome

local _, FT = ...

local GetSpellName = (C_Spell and C_Spell.GetSpellName) or function(id)
    return (GetSpellInfo(id))
end

-- Feitiços de coleta (todos os casts de coleta usam o nome do feitiço base).
local GATHER_SPELLS = { herb = 2366, ore = 2575 }
-- Linhas de profissão (texto que aparece no tooltip do nó).
local SKILL_LINES   = { herb = 182,  ore = 186 }

local spellNameToKind = {}
local skillNameToKind = {}

local function BuildLookups()
    for kind, id in pairs(GATHER_SPELLS) do
        local name = GetSpellName(id)
        if name then spellNameToKind[name] = kind end
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
        for kind, id in pairs(SKILL_LINES) do
            local ok, name = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, id)
            if ok and name and name ~= "" then skillNameToKind[name] = kind end
        end
    end
end

FT:RegisterEvent("PLAYER_LOGIN", BuildLookups)

local function KindFromTooltip(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or not data or not data.lines then return nil end
    for i = 2, #data.lines do
        local text = data.lines[i].leftText
        if text then
            for skill, kind in pairs(skillNameToKind) do
                if text:find(skill, 1, true) then return kind end
            end
        end
    end
end

-- Retorna "herb", "ore" ou "other" para um token de unidade de objeto.
function FT:Classify(unit, name)
    if name and self.db.names[name] then
        return self.db.names[name]
    end
    local kind = KindFromTooltip(unit)
    if kind and name then self.db.names[name] = kind end
    return kind or "other"
end

---------------------------------------------------------------------------
-- Aprendizado: grava o nome de cada nó coletado
---------------------------------------------------------------------------
FT:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player", function(self, unit, target, castGUID, spellID)
    local spellName = spellID and GetSpellName(spellID)
    local kind = spellName and spellNameToKind[spellName]
    if kind and target and target ~= "" and not self.db.names[target] then
        self.db.names[target] = kind
    end
end)
