-- Farm Time - Classificação de nós
--
-- O objeto que o jogo escolhe como alvo de interação chega pelo token de
-- unidade "softinteract". Aqui decidimos se ele é erva, minério ou outra coisa
-- (baú, caixa de missão etc.) pelo nome:
--   1. listas de ervas/minérios do Classic (cliente em inglês)
--   2. nomes aprendidos: todo nó que você coleta fica gravado (serve para
--      outros idiomas e para nós novos do WoW Forever)

local _, FT = ...

local HERBS = {
    "Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn",
    "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood",
    "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Wintersbite",
    "Firebloom", "Purple Lotus", "Arthas' Tears", "Sungrass", "Blindweed",
    "Ghost Mushroom", "Gromsblood", "Golden Sansam", "Dreamfoil",
    "Mountain Silversage", "Plaguebloom", "Icecap", "Black Lotus",
}

local ORES = {
    "Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein",
    "Mithril Deposit", "Truesilver Deposit", "Dark Iron Deposit",
    "Small Thorium Vein", "Rich Thorium Vein", "Hakkari Thorium Vein",
    "Incendicite Mineral Vein", "Indurium Mineral Vein", "Lesser Bloodstone Deposit",
    "Small Obsidian Chunk", "Large Obsidian Chunk",
}

local known = {}
for _, n in ipairs(HERBS) do known[n] = "herb" end
for _, n in ipairs(ORES) do known[n] = "ore" end

-- Feitiços de coleta (todos os casts de coleta usam o nome do feitiço base).
local GATHER_SPELLS = { herb = 2366, ore = 2575 }

local GetSpellName = (C_Spell and C_Spell.GetSpellName) or function(id)
    return (GetSpellInfo(id))
end

local spellNameToKind = {}
FT:RegisterEvent("PLAYER_LOGIN", function()
    for kind, id in pairs(GATHER_SPELLS) do
        local name = GetSpellName(id)
        if name then spellNameToKind[name] = kind end
    end
end)

-- Retorna "herb", "ore" ou "other".
function FT:Classify(name)
    if not name then return "other" end
    local kind = self.db.names[name] or known[name]
    if kind then return kind end
    -- Variações em inglês ("Ooze Covered Silver Vein" etc.)
    if name:find(" Vein$") or name:find(" Deposit$") then return "ore" end
    return "other"
end

---------------------------------------------------------------------------
-- Aprendizado: grava o nome de cada nó coletado
---------------------------------------------------------------------------
FT:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player", function(self, unit, target, castGUID, spellID)
    local spellName = spellID and GetSpellName(spellID)
    local kind = spellName and spellNameToKind[spellName]
    if kind and target and target ~= "" and self.db.names[target] ~= kind then
        self.db.names[target] = kind
        self:RefreshHighlight()
    end
end)
