-- Farm Time - F para pescar
--
-- Com uma vara de pescar equipada e NENHUM alvo de interação, a tecla de
-- coleta (F) passa a lançar Pescaria. Assim que aparece algo para interagir
-- (erva, minério, corpo, ou a própria boia), F volta a ser "Interagir".
-- Durante a pescaria (canalizando) F também é "Interagir", para recolher a
-- boia em vez de relançar.
--
-- Usa uma binding de sobreposição (SetOverrideBindingSpell), que o jogo só
-- permite trocar fora de combate; em combate a troca espera o fim da luta.

local _, FT = ...

local owner = CreateFrame("Frame")
local active = false   -- a sobreposição está ligada?
local pending = false  -- uma troca ficou para depois do combate

-- Pescaria em todos os ranks do Classic e o ID do retail. O jogo lança o
-- maior rank pelo nome.
local FISHING_SPELLS = { 18248, 7732, 7731, 7620, 131474 }
local FISHING_POLE = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole) or 20
local WEAPON = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2

local GetSpellName = (C_Spell and C_Spell.GetSpellName) or function(id) return (GetSpellInfo(id)) end
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

local function FishingSpellName()
    for _, id in ipairs(FISHING_SPELLS) do
        local known = (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))
        if known then return GetSpellName(id) end
    end
end

-- Vara na mão principal (16) ou no espaço de ferramenta de profissão (28).
local function PoleEquipped()
    for _, slot in ipairs({ 16, 28 }) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID and GetItemInfoInstant then
            local ok, _, _, _, _, _, classID, subclassID = pcall(GetItemInfoInstant, itemID)
            if ok and classID == WEAPON and subclassID == FISHING_POLE then return true end
        end
    end
    return false
end

local function Channeling()
    local ok, name = pcall(UnitChannelInfo, "player")
    return ok and name ~= nil
end

function FT:UpdateFishingKey()
    if not self.db then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false

    local spell = self.db.fishingKey and self.db.bindInteractKey and PoleEquipped() and FishingSpellName()
    local want = spell and not self:GetInteractTarget() and not Channeling()

    if want and not active then
        SetOverrideBindingSpell(owner, true, self.db.interactKey, spell)
        active = true
    elseif not want and active then
        ClearOverrideBindings(owner)
        active = false
    end
end

function FT:IsFishingKeyActive()
    return active
end

local function Update(self) self:UpdateFishingKey() end

FT:RegisterEvent("PLAYER_LOGIN", Update)
FT:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", Update)
FT:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", Update)
FT:RegisterEvent("SPELLS_CHANGED", Update)
FT:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player", Update)
FT:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", Update)
FT:RegisterEvent("PLAYER_REGEN_ENABLED", function(self)
    if pending then self:UpdateFishingKey() end
end)
