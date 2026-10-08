-- Farm Time - Aviso "aperte F"
--
-- Quando o alvo de interação do jogo é uma erva, um minério ou um corpo que
-- pode ser esfolado (skinning), mostra um pequeno aviso abaixo do centro da
-- tela: [F] Coletar Kingsblood. A tecla mostrada é a que está ligada ao
-- "Interagir com o alvo" de verdade (normalmente F, pelo Keybind.lua).

local _, FT = ...

local UNIT = "softinteract"

local COLORS = {
    herb = { 0.3, 1.0, 0.3 },
    ore  = { 1.0, 0.7, 0.2 },
    skin = { 0.9, 0.6, 0.4 },
}

---------------------------------------------------------------------------
-- Visual
---------------------------------------------------------------------------
local prompt = CreateFrame("Frame", "FarmTimePrompt", UIParent)
prompt:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
prompt:SetHeight(30)
prompt:SetFrameStrata("HIGH")
prompt:EnableMouse(false)
prompt:Hide()

prompt.bg = prompt:CreateTexture(nil, "BACKGROUND")
prompt.bg:SetAllPoints()
prompt.bg:SetColorTexture(0.05, 0.05, 0.05, 0.8)

prompt.line = prompt:CreateTexture(nil, "BORDER")
prompt.line:SetPoint("BOTTOMLEFT")
prompt.line:SetPoint("BOTTOMRIGHT")
prompt.line:SetHeight(2)

-- "Tecla" desenhada: quadrado claro com a letra.
prompt.key = CreateFrame("Frame", nil, prompt)
prompt.key:SetSize(22, 22)
prompt.key:SetPoint("LEFT", 5, 0)
prompt.key.bg = prompt.key:CreateTexture(nil, "ARTWORK")
prompt.key.bg:SetAllPoints()
prompt.key.bg:SetColorTexture(0.85, 0.85, 0.85, 1)
prompt.key.inner = prompt.key:CreateTexture(nil, "OVERLAY")
prompt.key.inner:SetPoint("TOPLEFT", 2, -2)
prompt.key.inner:SetPoint("BOTTOMRIGHT", -2, 2)
prompt.key.inner:SetColorTexture(0.15, 0.15, 0.15, 1)
prompt.key.text = prompt.key:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
prompt.key.text:SetPoint("CENTER", 0, 0)
prompt.key.text:SetDrawLayer("OVERLAY", 7)

prompt.text = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
prompt.text:SetPoint("LEFT", prompt.key, "RIGHT", 8, 0)

local fade = prompt:CreateAnimationGroup()
local alpha = fade:CreateAnimation("Alpha")
alpha:SetFromAlpha(0)
alpha:SetToAlpha(1)
alpha:SetDuration(0.15)

---------------------------------------------------------------------------
-- Skinning: o tooltip do corpo diz "Skinnable" (texto do próprio cliente).
---------------------------------------------------------------------------
local scanTip = CreateFrame("GameTooltip", "FarmTimeScanTooltip", UIParent, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")

local function SkinnableTexts()
    local list = {}
    for _, key in ipairs({ "UNIT_SKINNABLE_LEATHER", "UNIT_SKINNABLE_HERB",
                           "UNIT_SKINNABLE_ROCK", "UNIT_SKINNABLE_BOLTS" }) do
        if type(_G[key]) == "string" then table.insert(list, _G[key]) end
    end
    if #list == 0 then list[1] = "Skinnable" end
    return list
end

local function LineMatches(text, patterns)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return false end
    for _, p in ipairs(patterns) do
        if text:find(p, 1, true) then return true end
    end
    return false
end

local function IsSkinnable()
    local patterns = SkinnableTexts()
    -- Clientes novos: dados do tooltip sem precisar de um tooltip na tela.
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, UNIT)
        if ok and data and data.lines then
            for _, line in ipairs(data.lines) do
                if LineMatches(line.leftText, patterns) then return true end
            end
            return false
        end
    end
    -- Clientes antigos: tooltip escondido.
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    if not pcall(scanTip.SetUnit, scanTip, UNIT) then return false end
    for i = 2, scanTip:NumLines() do
        local fs = _G["FarmTimeScanTooltipTextLeft" .. i]
        if fs and LineMatches(fs:GetText(), patterns) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Lógica
---------------------------------------------------------------------------
local function InteractKey()
    local key = GetBindingKey and GetBindingKey("INTERACTTARGET")
    return key or (FT.db and FT.db.interactKey) or "F"
end

-- Retorna tipo ("herb", "ore", "skin") e nome do alvo de interação, ou nil.
local function CurrentPromptTarget()
    local guid, name, kind = FT:GetInteractTarget()
    if not guid then return nil end
    if guid:find("^GameObject") then
        if kind == "herb" or kind == "ore" then return kind, name end
        return nil
    end
    if guid:find("^Creature") or guid:find("^Vehicle") then
        local ok, dead = pcall(UnitIsDead, UNIT)
        if ok and dead == true and IsSkinnable() then return "skin", name end
    end
end

local lastKey

function FT:UpdatePrompt()
    local db = self.db
    local kind, name
    if db and db.showPrompt then kind, name = CurrentPromptTarget() end
    if not kind then
        prompt:Hide()
        lastKey = nil
        return
    end

    local c = COLORS[kind]
    local action = self.L["PROMPT_" .. kind]
    prompt.key.text:SetText(InteractKey())
    local hex = string.format("%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
    prompt.text:SetText(action .. " |cff" .. hex .. (name or "") .. "|r")
    prompt.line:SetColorTexture(c[1], c[2], c[3], 0.9)
    prompt:SetWidth(5 + 22 + 8 + prompt.text:GetStringWidth() + 12)

    local key = kind .. (name or "")
    if not prompt:IsShown() or key ~= lastKey then fade:Play() end
    lastKey = key
    prompt:Show()
end

local function Update(self) self:UpdatePrompt() end

-- Registrado depois do Highlight.lua (ordem do .toc), então o alvo já foi lido.
FT:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", Update)
FT:RegisterEvent("PLAYER_ENTERING_WORLD", Update)
-- Depois de saquear um corpo ele pode virar "esfolável": confere de novo.
FT:RegisterEvent("LOOT_CLOSED", function(self)
    C_Timer.After(0.2, function() self:UpdatePrompt() end)
end)
-- O corpo esfolado deixa de ser esfolável.
FT:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", function(self)
    C_Timer.After(0.2, function() self:UpdatePrompt() end)
end)
