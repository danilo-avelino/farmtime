-- Farm Time - Aviso de rastreamento
--
-- O Farm Time depende dos pontos de erva/minério do minimapa, que só aparecem
-- com "Find Herbs" (Achar Ervas) ou "Find Minerals" (Achar Minerais) ligado.
-- Se o personagem conhece um dos dois e nenhum está ativo, mostra um aviso
-- embaixo do minimapa. O X esconde o aviso até o rastreamento mudar.

local _, FT = ...

local FIND_HERBS, FIND_MINERALS = 2383, 2580
-- Ícones dos dois feitiços (reserva, caso não dê para ler do feitiço).
local HERB_ICON, MINERAL_ICON = 133939, 136025

local GetSpellName = (C_Spell and C_Spell.GetSpellName) or function(id) return (GetSpellInfo(id)) end
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture

local function Knows(id)
    return (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or false
end

local function SpellIcon(id, fallback)
    local ok, tex = pcall(GetSpellTexture, id)
    return (ok and tex) or fallback
end

local function IsGatherTracking(name, texture, spellID)
    if spellID == FIND_HERBS or spellID == FIND_MINERALS then return true end
    if name and (name == GetSpellName(FIND_HERBS) or name == GetSpellName(FIND_MINERALS)) then return true end
    if texture then
        if texture == SpellIcon(FIND_HERBS, HERB_ICON) or texture == SpellIcon(FIND_MINERALS, MINERAL_ICON)
            or texture == HERB_ICON or texture == MINERAL_ICON then
            return true
        end
        if type(texture) == "string" then
            local t = texture:lower()
            return t:find("inv_misc_flower_02", 1, true) ~= nil or t:find("spell_nature_earthquake", 1, true) ~= nil
        end
    end
    return false
end

-- true = Find Herbs/Minerals ligado; false = desligado; nil = não deu para saber.
function FT:GatherTrackingActive()
    if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
        local ok, n = pcall(C_Minimap.GetNumTrackingTypes)
        if ok and type(n) == "number" then
            for i = 1, n do
                local okI, a, b, c, _, _, spellID = pcall(C_Minimap.GetTrackingInfo, i)
                if okI then
                    local name, texture, active = a, b, c
                    if type(a) == "table" then
                        name, texture, active, spellID = a.name, a.texture, a.active, a.spellID
                    end
                    if active and IsGatherTracking(name, texture, spellID) then return true end
                end
            end
            return false
        end
    end
    if GetTrackingTexture then
        local ok, texture = pcall(GetTrackingTexture)
        if ok then return texture ~= nil and IsGatherTracking(nil, texture, nil) end
    end
    return nil
end

---------------------------------------------------------------------------
-- Aviso
---------------------------------------------------------------------------
local banner = FT.Style.CreatePlate(UIParent, { name = "FarmTimeTrackingWarning", subFont = "GameFontHighlightSmall" })
banner:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -28)
banner:SetFrameStrata("MEDIUM")
banner:Hide()

banner.close = CreateFrame("Button", nil, banner, "UIPanelCloseButton")
banner.close:SetSize(20, 20)
banner.close:SetPoint("TOPRIGHT", banner, "TOPRIGHT", 6, 6)

local dismissed = false
banner.close:SetScript("OnClick", function()
    dismissed = true
    banner:Hide()
end)

function FT:UpdateTrackingWarning()
    if not self.db then return end
    local herbs, minerals = Knows(FIND_HERBS), Knows(FIND_MINERALS)
    local active = self:GatherTrackingActive()
    if active then dismissed = false end -- volta a avisar se desligar de novo
    local show = self.db.trackingWarning and self.db.enabled and (herbs or minerals)
        and active == false and not dismissed
    if not show then
        banner:Hide()
        return
    end
    local L = self.L
    local spell = herbs and minerals and L.TRACK_BOTH
        or (herbs and (GetSpellName(FIND_HERBS) or "Find Herbs"))
        or (GetSpellName(FIND_MINERALS) or "Find Minerals")
    local icon = herbs and SpellIcon(FIND_HERBS, HERB_ICON) or SpellIcon(FIND_MINERALS, MINERAL_ICON)
    banner:SetContent(icon, L.TRACK_OFF_TITLE, string.format(L.TRACK_OFF_SUB, spell), FT.Style.COLORS.unknown, 30)
    banner:SetWidth(banner:GetWidth() + 14) -- espaço para o X
    banner:Show()
end

local function Update(self) self:UpdateTrackingWarning() end
FT:RegisterEvent("PLAYER_LOGIN", function(self)
    C_Timer.After(5, function() self:UpdateTrackingWarning() end)
    -- O rastreamento some ao morrer/ressuscitar e alguns clientes não avisam:
    -- confere de tempos em tempos.
    C_Timer.NewTicker(5, function() self:UpdateTrackingWarning() end)
end)
FT:RegisterEvent("MINIMAP_UPDATE_TRACKING", Update)
FT:RegisterEvent("SPELLS_CHANGED", Update)
