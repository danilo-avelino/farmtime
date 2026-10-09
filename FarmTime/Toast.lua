-- Farm Time - "Conquista" de pesca
--
-- A cada item pescado mostra um alerta com o visual do alerta de conquista do
-- próprio WoW (mesmas texturas, tamanhos e animações do AchievementAlertFrame):
-- fundo da conquista, moldura do ícone, brilho que pisca e um reflexo que
-- atravessa a placa. A raridade do item colore a moldura do ícone, o brilho e
-- o nome (cinza, branco, verde, azul, roxo...). Vários itens entram em fila.

local _, FT = ...

local ACH = "Interface\\AchievementFrame\\"
local HOLD_TIME = 4
local MAX_QUEUE = 5

-- Cores de raridade do próprio jogo, com reserva caso a tabela não exista.
local FALLBACK_QUALITY = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 },
    [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
}
local function QualityColor(quality)
    local c = ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality]
    if c and c.r then return { c.r, c.g, c.b } end
    return FALLBACK_QUALITY[quality or 1] or FALLBACK_QUALITY[1]
end

---------------------------------------------------------------------------
-- Som: tocado de um jeito que o "abaixar o volume para pescar" não atinja.
--
-- Addons de pesca costumam baixar o volume geral/efeitos/música para destacar
-- o barulho da boia. O som de conquista é tocado no canal de Diálogo (que
-- esses addons não usam) e, só enquanto ele toca, o volume de Diálogo e o
-- volume geral são subidos; depois voltam ao que eram. Se o som do jogo
-- estiver totalmente desligado pelo jogador, nada é forçado.
---------------------------------------------------------------------------
local ACHIEVEMENT_SOUND = 12891 -- "conquista obtida"
local SOUND_LENGTH = 3

local GetCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCVar = (C_CVar and C_CVar.SetCVar) or SetCVar

local restoreTimer
local function SetTemp(saved, name, value)
    local ok, current = pcall(GetCVar, name)
    if not ok or current == nil then return end
    if saved[name] == nil then saved[name] = current end
    if current ~= value then pcall(SetCVar, name, value) end
end

local function PlayKit(kit, channel)
    local ok, willPlay = pcall(PlaySound, kit, channel)
    return ok and willPlay ~= false
end

function FT:PlayAchievementSound()
    local channel = "Master"
    local saved = {}
    if self.db.loudFishSound and GetCVar("Sound_EnableAllSound") ~= "0" then
        channel = "Dialog"
        local volume = tostring(self.db.fishSoundVolume or 1)
        SetTemp(saved, "Sound_EnableDialog", "1")
        SetTemp(saved, "Sound_DialogVolume", volume)
        local okm, master = pcall(GetCVar, "Sound_MasterVolume")
        if okm and tonumber(master) and tonumber(master) < (self.db.fishSoundVolume or 1) then
            SetTemp(saved, "Sound_MasterVolume", volume)
        end
    end

    local kit = (SOUNDKIT and SOUNDKIT.UI_ALERT_ACHIEVEMENT_GAINED) or ACHIEVEMENT_SOUND
    if not PlayKit(kit, channel) then
        local fallback = SOUNDKIT and (SOUNDKIT.UI_EPICLOOT_TOAST or SOUNDKIT.IG_QUEST_LIST_COMPLETE)
        if fallback then PlayKit(fallback, channel) end
    end

    if next(saved) then
        if restoreTimer then restoreTimer:Cancel() end
        local applied = {}
        for name in pairs(saved) do applied[name] = GetCVar(name) end
        restoreTimer = C_Timer.NewTimer(SOUND_LENGTH, function()
            restoreTimer = nil
            for name, value in pairs(saved) do
                -- Só devolve se ninguém mexeu nesse volume enquanto o som tocava.
                if GetCVar(name) == applied[name] then pcall(SetCVar, name, value) end
            end
        end)
    end
end

---------------------------------------------------------------------------
-- Visual (mesma montagem do AchievementAlertFrame da Blizzard)
---------------------------------------------------------------------------
local toast = CreateFrame("Frame", "FarmTimeFishToast", UIParent)
toast:SetSize(300, 88)
toast:SetPoint("TOP", UIParent, "TOP", 0, -140)
toast:SetFrameStrata("HIGH")
toast:EnableMouse(false)
toast:Hide()

toast.bg = toast:CreateTexture(nil, "BACKGROUND")
toast.bg:SetTexture(ACH .. "UI-Achievement-Alert-Background")
toast.bg:SetTexCoord(0, 0.605, 0, 0.703)
toast.bg:SetAllPoints()

-- "Peixe pescado!" no lugar de "Conquista obtida".
toast.header = toast:CreateFontString(nil, "ARTWORK", "GameFontBlackTiny")
toast.header:SetSize(200, 12)
toast.header:SetPoint("TOP", 7, -23)

toast.name = toast:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
toast.name:SetPoint("BOTTOMLEFT", 72, 36)
toast.name:SetPoint("BOTTOMRIGHT", -24, 36)
toast.name:SetHeight(16)

toast.count = toast:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
toast.count:SetPoint("TOP", toast.name, "BOTTOM", 0, -3)

-- Ícone com a moldura da conquista; a moldura fica na cor da raridade.
toast.iconFrame = CreateFrame("Frame", nil, toast)
toast.iconFrame:SetSize(124, 124)
toast.iconFrame:SetPoint("TOPLEFT", -26, 16)
toast.icon = toast.iconFrame:CreateTexture(nil, "ARTWORK")
toast.icon:SetSize(50, 50)
toast.icon:SetPoint("CENTER", 0, 3)
toast.iconRing = toast.iconFrame:CreateTexture(nil, "OVERLAY")
toast.iconRing:SetTexture(ACH .. "UI-Achievement-IconFrame")
toast.iconRing:SetTexCoord(0, 0.5625, 0, 0.5625)
toast.iconRing:SetSize(72, 72)
toast.iconRing:SetPoint("CENTER", -1, 2)

-- Brilho grande que acende e apaga ao entrar.
toast.glow = toast:CreateTexture(nil, "OVERLAY")
toast.glow:SetTexture(ACH .. "UI-Achievement-Alert-Glow")
toast.glow:SetTexCoord(0, 0.78125, 0, 0.66796875)
toast.glow:SetBlendMode("ADD")
toast.glow:SetSize(400, 171)
toast.glow:SetPoint("CENTER")
toast.glow:SetAlpha(0)

-- Reflexo que atravessa a placa da esquerda para a direita.
toast.shine = toast:CreateTexture(nil, "OVERLAY")
toast.shine:SetTexture(ACH .. "UI-Achievement-Alert-Glow")
toast.shine:SetTexCoord(0.78125, 0.912109375, 0, 0.28125)
toast.shine:SetBlendMode("ADD")
toast.shine:SetSize(67, 72)
toast.shine:SetPoint("BOTTOMLEFT", 0, 8)
toast.shine:SetAlpha(0)

-- Animações (tempos do alerta original).
local fadeIn = toast:CreateAnimationGroup()
local a = fadeIn:CreateAnimation("Alpha")
a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.2)

local glowAnim = toast.glow:CreateAnimationGroup()
local g1 = glowAnim:CreateAnimation("Alpha")
g1:SetFromAlpha(0); g1:SetToAlpha(1); g1:SetDuration(0.2); g1:SetOrder(1)
local g2 = glowAnim:CreateAnimation("Alpha")
g2:SetFromAlpha(1); g2:SetToAlpha(0); g2:SetDuration(0.5); g2:SetOrder(2)

local shineAnim = toast.shine:CreateAnimationGroup()
local s1 = shineAnim:CreateAnimation("Alpha")
s1:SetFromAlpha(0); s1:SetToAlpha(1); s1:SetDuration(0.2); s1:SetOrder(1)
local s2 = shineAnim:CreateAnimation("Translation")
s2:SetOffset(240, 0); s2:SetDuration(0.85); s2:SetOrder(2)
local s3 = shineAnim:CreateAnimation("Alpha")
s3:SetFromAlpha(1); s3:SetToAlpha(0); s3:SetDuration(0.5); s3:SetStartDelay(0.35); s3:SetOrder(2)

local fadeOut = toast:CreateAnimationGroup()
local o = fadeOut:CreateAnimation("Alpha")
o:SetFromAlpha(1); o:SetToAlpha(0); o:SetDuration(1.5)

---------------------------------------------------------------------------
-- Fila
---------------------------------------------------------------------------
local queue = {}
local showing = false
local ShowNext

fadeOut:SetScript("OnFinished", function()
    toast:Hide()
    showing = false
    ShowNext()
end)

function ShowNext()
    if showing then return end
    local item = table.remove(queue, 1)
    if not item then return end
    showing = true

    local c = QualityColor(item.quality)
    toast.header:SetText(FT.L.FISH_CAUGHT)
    toast.name:SetText(item.name or "?")
    toast.name:SetTextColor(c[1], c[2], c[3])
    toast.count:SetText((item.count and item.count > 1) and ("x" .. item.count) or "")
    toast.icon:SetTexture(item.icon)
    -- Moldura dourada da conquista recolorida para a cor da raridade.
    toast.iconRing:SetDesaturated(true)
    toast.iconRing:SetVertexColor(c[1], c[2], c[3])
    toast.glow:SetVertexColor(c[1], c[2], c[3])
    toast.shine:SetVertexColor(1, 1, 1)

    toast:SetAlpha(1)
    toast:Show()
    fadeIn:Play()
    glowAnim:Play()
    shineAnim:Play()

    if FT.db.sound then FT:PlayAchievementSound() end

    C_Timer.After(HOLD_TIME, function() fadeOut:Play() end)
end

function FT:ShowFishToast(item)
    if not (self.db and self.db.fishToast) then return end
    if #queue >= MAX_QUEUE then return end
    table.insert(queue, item)
    ShowNext()
end

-- Prévia: /ft fishtest
function FT:TestFishToast()
    local function icon(id, fallback)
        local ok, tex = pcall(C_Item and C_Item.GetItemIconByID or GetItemIcon, id)
        return (ok and tex) or fallback
    end
    self:ShowFishToast({ name = "Firefin Snapper", icon = icon(6359, "Interface\\Icons\\INV_Misc_Fish_02"), count = 1, quality = 1 })
    self:ShowFishToast({ name = "Raw Sagefish", icon = icon(21071, "Interface\\Icons\\INV_Misc_Fish_20"), count = 2, quality = 2 })
    self:ShowFishToast({ name = "Shiny Bauble", icon = icon(6529, "Interface\\Icons\\INV_Misc_Orb_03"), count = 1, quality = 3 })
end
