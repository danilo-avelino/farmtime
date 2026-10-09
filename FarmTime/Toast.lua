-- Farm Time - "Conquista" de pesca
--
-- A cada item pescado, mostra uma placa grande no estilo das placas do addon,
-- com a borda e o brilho na cor da raridade do item (cinza, branco, verde,
-- azul, roxo...). Entra deslizando com um "pop", brilha, espera e some.
-- Vários itens da mesma pescaria entram em fila.

local _, FT = ...

local ICON_SIZE = 52
local HOLD_TIME = 3.5
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
-- Visual: placa grande + brilho atrás + cabeçalho
---------------------------------------------------------------------------
local toast = CreateFrame("Frame", "FarmTimeFishToast", UIParent)
toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
toast:SetFrameStrata("HIGH")
toast:EnableMouse(false)
toast:Hide()

-- Brilho: retângulo na cor da raridade um pouco maior que a placa, pulsando.
toast.glow = toast:CreateTexture(nil, "BACKGROUND")
toast.glow:SetTexture("Interface\\Buttons\\WHITE8X8")
toast.glow:SetBlendMode("ADD")

toast.plate = FT.Style.CreatePlate(toast, {
    titleFont = "GameFontNormalHuge", subFont = "GameFontHighlight",
    borderSize = 3, barHeight = 4,
})
toast.plate:SetPoint("CENTER")

-- Cabeçalho acima da placa ("Peixe pescado!").
toast.header = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
toast.header:SetPoint("BOTTOM", toast.plate, "TOP", 0, 4)
toast.header:SetShadowOffset(1, -1)

-- Entrada: desce 40 px enquanto aparece, com um leve "pop" de escala.
local enter = toast:CreateAnimationGroup()
local slide = enter:CreateAnimation("Translation")
slide:SetOffset(0, -40)
slide:SetDuration(0.35)
slide:SetSmoothing("OUT")
local fadeIn = enter:CreateAnimation("Alpha")
fadeIn:SetFromAlpha(0)
fadeIn:SetToAlpha(1)
fadeIn:SetDuration(0.25)
local pop = enter:CreateAnimation("Scale")
if pop.SetScaleFrom then
    pop:SetScaleFrom(0.8, 0.8)
    pop:SetScaleTo(1, 1)
else
    pop:SetScale(1.25, 1.25)
end
pop:SetDuration(0.35)
pop:SetSmoothing("OUT")

-- Brilho piscando duas vezes depois de entrar.
local shine = toast.glow:CreateAnimationGroup()
shine:SetLooping("BOUNCE")
local shineAlpha = shine:CreateAnimation("Alpha")
shineAlpha:SetFromAlpha(0.15)
shineAlpha:SetToAlpha(0.6)
shineAlpha:SetDuration(0.45)

-- Saída.
local leave = toast:CreateAnimationGroup()
local fadeOut = leave:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1)
fadeOut:SetToAlpha(0)
fadeOut:SetDuration(0.6)

---------------------------------------------------------------------------
-- Fila
---------------------------------------------------------------------------
local queue = {}
local showing = false
local ShowNext

local function Finish()
    shine:Stop()
    toast:Hide()
    toast:SetAlpha(1)
    showing = false
    ShowNext()
end

leave:SetScript("OnFinished", Finish)

-- Depois da entrada, o frame volta para a posição de origem (a animação de
-- deslocamento não move o frame de verdade); por isso ele começa 40 px acima.
enter:SetScript("OnFinished", function()
    toast:ClearAllPoints()
    toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
end)

function ShowNext()
    if showing then return end
    local item = table.remove(queue, 1)
    if not item then return end
    showing = true

    local c = QualityColor(item.quality)
    local title = item.name or "?"
    local sub = (item.count and item.count > 1) and ("x" .. item.count) or nil
    toast.plate:SetContent(item.icon, title, sub, c, ICON_SIZE)
    toast.plate:SetAlpha(1)
    toast.header:SetText(FT.L.FISH_CAUGHT)
    toast.header:SetTextColor(c[1], c[2], c[3])

    local w, h = toast.plate:GetSize()
    toast:SetSize(w, h)
    toast.glow:ClearAllPoints()
    toast.glow:SetPoint("TOPLEFT", toast.plate, "TOPLEFT", -6, 6)
    toast.glow:SetPoint("BOTTOMRIGHT", toast.plate, "BOTTOMRIGHT", 6, -6)
    toast.glow:SetVertexColor(c[1], c[2], c[3])
    toast.glow:SetAlpha(0.15)

    toast:ClearAllPoints()
    toast:SetPoint("TOP", UIParent, "TOP", 0, -110) -- desce 40 px até -150
    toast:SetAlpha(1)
    toast:Show()
    enter:Play()
    shine:Play()

    if FT.db.sound then
        local kit = SOUNDKIT and (SOUNDKIT.UI_EPICLOOT_TOAST or SOUNDKIT.IG_QUEST_LIST_COMPLETE)
        if kit then pcall(PlaySound, kit) end
    end

    C_Timer.After(HOLD_TIME, function()
        shine:Stop()
        leave:Play()
    end)
end

function FT:ShowFishToast(item)
    if not (self.db and self.db.fishToast) then return end
    if #queue >= MAX_QUEUE then return end
    table.insert(queue, item)
    ShowNext()
end

-- Prévia: /ft fishtest
function FT:TestFishToast()
    local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(6359))
        or (GetItemIcon and GetItemIcon(6359)) or "Interface\\Icons\\INV_Misc_Fish_02"
    self:ShowFishToast({ name = "Firefin Snapper", icon = icon, count = 1, quality = 1 })
    self:ShowFishToast({ name = "Raw Sagefish", icon = "Interface\\Icons\\INV_Misc_Fish_20", count = 2, quality = 2 })
    self:ShowFishToast({ name = "Shiny Bauble", icon = "Interface\\Icons\\INV_Misc_Orb_03", count = 1, quality = 3 })
end
