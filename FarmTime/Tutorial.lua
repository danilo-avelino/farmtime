-- Farm Time - Tutorial
--
-- Na primeira vez que o addon carrega, mostra uma janela com as duas funções
-- principais: achar ervas/minérios (minimapa -> marcador na tela -> F) e
-- pescar com F. Depois só abre pelo painel (botão Tutorial) ou /ft tutorial.

local _, FT = ...

local PAGES = {
    { title = "TUT_NODES_TITLE", body = "TUT_NODES_BODY",
      icons = { "Interface\\Icons\\INV_Misc_Flower_02", "Interface\\Icons\\INV_Ore_Copper_01" } },
    { title = "TUT_FISH_TITLE", body = "TUT_FISH_BODY",
      icons = { "Interface\\Icons\\Trade_Fishing", "Interface\\Icons\\INV_Misc_Fish_02" } },
}

local f = CreateFrame("Frame", "FarmTimeTutorial", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(500, 340)
f:SetPoint("CENTER", 0, 60)
f:SetFrameStrata("DIALOG")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetClampedToScreen(true)
f:Hide()
table.insert(UISpecialFrames, "FarmTimeTutorial") -- fecha com ESC

f.header = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.header:SetPoint("TOP", 0, -5)

f.icons = {}
for i = 1, 2 do
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(40, 40)
    holder:SetPoint("TOPLEFT", 20 + (i - 1) * 46, -36)
    holder.tex = holder:CreateTexture(nil, "ARTWORK")
    holder.tex:SetAllPoints()
    holder.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    holder.border = FT.Style.CreateBorder(holder, "OVERLAY", 1, 1)
    holder.border:SetColor(0, 0, 0, 1)
    f.icons[i] = holder
end

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
f.title:SetPoint("LEFT", f.icons[2], "RIGHT", 12, 0)
f.title:SetPoint("RIGHT", f, "RIGHT", -20, 0)
f.title:SetJustifyH("LEFT")

f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.body:SetPoint("TOPLEFT", 22, -92)
f.body:SetPoint("RIGHT", f, "RIGHT", -22, 0)
f.body:SetJustifyH("LEFT")
f.body:SetJustifyV("TOP")
f.body:SetSpacing(4)

f.pageText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
f.pageText:SetPoint("BOTTOM", 0, 20)

f.prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.prev:SetSize(110, 22)
f.prev:SetPoint("BOTTOMLEFT", 16, 14)

f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.next:SetSize(110, 22)
f.next:SetPoint("BOTTOMRIGHT", -16, 14)

local page = 1

local function Render()
    local L = FT.L
    local p = PAGES[page]
    f.header:SetText(L.TUT_HEADER)
    for i, holder in ipairs(f.icons) do
        holder.tex:SetTexture(p.icons[i])
        holder:SetShown(p.icons[i] ~= nil)
    end
    f.title:SetText(L[p.title])
    local key = FT.db and FT.db.interactKey or "F"
    f.body:SetText(string.format(L[p.body], key, key))
    f.pageText:SetText(string.format("%d / %d", page, #PAGES))
    f.prev:SetText(L.TUT_BACK)
    f.prev:SetEnabled(page > 1)
    f.next:SetText(page < #PAGES and L.TUT_NEXT or L.TUT_DONE)
end

f.prev:SetScript("OnClick", function()
    page = math.max(1, page - 1)
    Render()
end)

f.next:SetScript("OnClick", function()
    if page < #PAGES then
        page = page + 1
        Render()
    else
        f:Hide()
    end
end)

-- Fechou (Entendi, X ou ESC): não abre mais sozinho.
f:SetScript("OnHide", function()
    if FT.db then FT.db.tutorialSeen = true end
end)

function FT:ShowTutorial()
    page = 1
    Render()
    f:Show()
end

function FT:RefreshTutorial()
    if f:IsShown() then Render() end
end

FT:RegisterEvent("PLAYER_LOGIN", function(self)
    if not self.db.tutorialSeen then
        C_Timer.After(4, function() self:ShowTutorial() end)
    end
end)
