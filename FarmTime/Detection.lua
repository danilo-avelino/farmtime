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

-- Item que cada nó dá, para mostrar o ícone do próprio recurso.
local NODE_ITEMS = {
    ["Peacebloom"] = 2447, ["Silverleaf"] = 765, ["Earthroot"] = 2449,
    ["Mageroyal"] = 785, ["Briarthorn"] = 2450, ["Stranglekelp"] = 3820,
    ["Bruiseweed"] = 2453, ["Wild Steelbloom"] = 3355, ["Grave Moss"] = 3369,
    ["Kingsblood"] = 3356, ["Liferoot"] = 3357, ["Fadeleaf"] = 3818,
    ["Goldthorn"] = 3821, ["Khadgar's Whisker"] = 3358, ["Wintersbite"] = 3819,
    ["Firebloom"] = 4625, ["Purple Lotus"] = 8831, ["Arthas' Tears"] = 8836,
    ["Sungrass"] = 8838, ["Blindweed"] = 8839, ["Ghost Mushroom"] = 8845,
    ["Gromsblood"] = 8846, ["Golden Sansam"] = 13464, ["Dreamfoil"] = 13463,
    ["Mountain Silversage"] = 13465, ["Plaguebloom"] = 13466, ["Icecap"] = 13467,
    ["Black Lotus"] = 13468,
    ["Copper Vein"] = 2770, ["Tin Vein"] = 2771, ["Silver Vein"] = 2775,
    ["Iron Deposit"] = 2772, ["Gold Vein"] = 2776, ["Mithril Deposit"] = 3858,
    ["Truesilver Deposit"] = 7911, ["Dark Iron Deposit"] = 11370,
    ["Small Thorium Vein"] = 10620, ["Rich Thorium Vein"] = 10620,
    ["Hakkari Thorium Vein"] = 10620, ["Incendicite Mineral Vein"] = 3340,
    ["Indurium Mineral Vein"] = 5833, ["Lesser Bloodstone Deposit"] = 4278,
}

local GetItemIconByID = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

-- Ícone do recurso do nó: tabela de itens > aprendido na coleta > nil.
function FT:GetNodeIcon(name)
    if not name then return nil end
    local itemID = NODE_ITEMS[name] or NODE_ITEMS[(name:gsub("^Ooze Covered ", ""))]
    if itemID and GetItemIconByID then
        local ok, icon = pcall(GetItemIconByID, itemID)
        if ok and icon then return icon end
    end
    return self.db.nodeIcons[name]
end

local known = {}
for _, n in ipairs(HERBS) do known[n] = "herb" end
for _, n in ipairs(ORES) do known[n] = "ore" end

-- Feitiços de coleta (todos os casts de coleta usam o nome do feitiço base).
local GATHER_SPELLS = { herb = 2366, ore = 2575, skin = 8613 }

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
-- Última coleta iniciada: { kind = "herb"|"ore"|"skin", name =, time = }.
-- Usada para saber de onde veio o saque (sessão e ícones aprendidos).
FT.gatherContext = nil

-- Tipo de coleta do saque aberto agora: "herb", "ore", "skin", "fish" ou nil.
function FT:GetGatherKind()
    if IsFishingLoot and IsFishingLoot() then return "fish" end
    local ctx = self.gatherContext
    if ctx and GetTime() - ctx.time < 10 then return ctx.kind, ctx.name end
end

FT:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player", function(self, unit, target, castGUID, spellID)
    local spellName = spellID and GetSpellName(spellID)
    local kind = spellName and spellNameToKind[spellName]
    if self.db.debug then
        self:Print(string.format("cast: %s (%s) -> %s | %s", tostring(spellName), tostring(spellID), tostring(kind), tostring(target)))
    end
    if not kind then return end
    self.gatherContext = { kind = kind, name = target, time = GetTime(), castGUID = castGUID }
    -- Só ervas e minérios entram na lista de nomes de nós (skinning é em criaturas).
    if kind ~= "skin" and target and target ~= "" and self.db.names[target] ~= kind then
        self.db.names[target] = kind
        self:RefreshHighlight()
    end
end)

-- Ao abrir o saque de uma coleta, grava o ícone do primeiro item como ícone do
-- nó. Assim ervas/minérios novos (do Forever ou em outro idioma) ganham ícone.
FT:RegisterEvent("LOOT_OPENED", function(self)
    local kind, name = self:GetGatherKind()
    if not (kind == "herb" or kind == "ore") or not name or self.db.nodeIcons[name] then return end
    local ok, icon = pcall(GetLootSlotInfo, 1)
    if ok and icon then self.db.nodeIcons[name] = icon end
end)
