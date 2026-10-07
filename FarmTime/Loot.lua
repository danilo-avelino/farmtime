-- Farm Time - Saque
--
-- 1. Registra o que foi saqueado de coletas (erva, minério, skinning, pesca)
--    para a janela da sessão.
-- 2. Fast loot: pega todos os itens assim que a janela de saque abre.
--    Segurar a tecla de "inverter auto loot" (Shift, por padrão) desativa.

local _, FT = ...

local snapshot = {}  -- [slot] = item que estava no slot quando o saque abriu
local handled = false -- LOOT_READY pode disparar mais de uma vez por saque

local function ItemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function TakeSnapshot(kind)
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local itemID = ItemIDFromLink(link)
        if itemID then -- moedas e moedas especiais não têm link de item
            local icon, name, quantity, _, quality = GetLootSlotInfo(slot)
            snapshot[slot] = {
                id = itemID, link = link, name = name, icon = icon,
                count = quantity or 1, quality = quality, kind = kind,
            }
        end
    end
end

local function FastLoot()
    if IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") then return end
    for slot = GetNumLootItems(), 1, -1 do
        LootSlot(slot)
    end
end

FT:RegisterEvent("LOOT_READY", function(self)
    if handled then return end
    handled = true
    wipe(snapshot)
    -- A foto do saque tem que vir antes do fast loot esvaziar os slots.
    local kind = self:GetGatherKind()
    if kind then TakeSnapshot(kind) end
    if self.db.fastLoot then FastLoot() end
end)

-- Um slot só conta quando o item realmente vai para a bolsa.
FT:RegisterEvent("LOOT_SLOT_CLEARED", function(self, slot)
    local item = snapshot[slot]
    if item then
        snapshot[slot] = nil
        self:AddSessionItem(item)
    end
end)

FT:RegisterEvent("LOOT_CLOSED", function(self)
    handled = false
    wipe(snapshot)
    self.gatherContext = nil
end)
