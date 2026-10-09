-- Farm Time - Saque
--
-- 1. Registra para a janela da sessão o que foi saqueado de coletas (erva,
--    minério, skinning, pesca) e, de qualquer saque, materiais de profissão
--    (carne, pano, couro, elementais...), que são o que vende bem no leilão.
-- 2. Fast loot: pega todos os itens assim que a janela de saque abre.
--    Segurar a tecla de "inverter auto loot" (Shift, por padrão) desativa.

local _, FT = ...

local snapshot = {}  -- [slot] = item que estava no slot quando o saque abriu
local handled = false -- LOOT_READY pode disparar mais de uma vez por saque

local TRADE_GOODS = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

local function ItemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

-- Material de profissão ("Trade Goods": carne, pano, couro, metal, elementais...).
-- GetItemInfoInstant não depende do cache de itens, então funciona na hora.
local function IsTradeGood(itemID)
    if not GetItemInfoInstant then return false end
    local ok, _, _, _, _, _, classID = pcall(GetItemInfoInstant, itemID)
    return ok and classID == TRADE_GOODS
end

-- gatherKind: tipo da coleta deste saque, ou nil se for saque comum (mob, baú...).
local function TakeSnapshot(gatherKind, withTradeGoods)
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local itemID = ItemIDFromLink(link)
        if itemID then -- moedas e moedas especiais não têm link de item
            local icon, name, quantity, _, quality, _, isQuestItem = GetLootSlotInfo(slot)
            local kind = gatherKind
            if not kind and withTradeGoods and not isQuestItem and IsTradeGood(itemID) then
                kind = "mat"
            end
            if kind then
                snapshot[slot] = {
                    id = itemID, link = link, name = name, icon = icon,
                    count = quantity or 1, quality = quality, kind = kind,
                }
            end
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
    TakeSnapshot(self:GetGatherKind(), self.db.trackTradeGoods)
    if self.db.fastLoot then FastLoot() end
end)

-- Um slot só conta quando o item realmente vai para a bolsa.
FT:RegisterEvent("LOOT_SLOT_CLEARED", function(self, slot)
    local item = snapshot[slot]
    if item then
        snapshot[slot] = nil
        self:AddSessionItem(item)
        if item.kind == "fish" and self.ShowFishToast then self:ShowFishToast(item) end
    end
end)

FT:RegisterEvent("LOOT_CLOSED", function(self)
    handled = false
    wipe(snapshot)
    self.gatherContext = nil
end)
