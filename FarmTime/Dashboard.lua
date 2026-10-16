-- Farm Time - Painel inicial (abre pelo ícone do minimapa e por /ft)
--
-- Mostra o ouro ganho e gasto por dia no mês escolhido: quatro números de
-- resumo e um gráfico de barras divergente (ganho para cima, gasto para baixo,
-- a partir da linha do zero). Passe o mouse num dia para ver os valores.
-- Embaixo, atalhos para Configurações, Sessão e Tutorial.

local _, FT = ...

local W, H = 620, 470
local CHART_W, CHART_H = 572, 190
-- Cores validadas para fundo escuro (azul = ganho, vermelho = gasto). A
-- posição (acima/abaixo do zero) também separa os dois, não só a cor.
local EARN  = { 0x39 / 255, 0x87 / 255, 0xe5 / 255 }
local SPEND = { 0xe6 / 255, 0x67 / 255, 0x67 / 255 }
local INK_MUTED = { 0.62, 0.62, 0.62 }

local f = CreateFrame("Frame", "FarmTimeDashboard", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(W, H)
f:SetPoint("CENTER")
f:SetFrameStrata("DIALOG")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetClampedToScreen(true)
f:Hide()
table.insert(UISpecialFrames, "FarmTimeDashboard") -- fecha com ESC

f.header = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.header:SetPoint("TOP", 0, -5)
f.header:SetText("Farm Time")

-- Mês visível
local view = {}
local function ResetView()
    local t = date("*t")
    view.year, view.month = t.year, t.month
end
ResetView()

local function DaysInMonth(y, m)
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if m == 2 and (y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)) then return 29 end
    return days[m]
end

---------------------------------------------------------------------------
-- Filtros: < mês >  e  "todos os personagens" (uma linha, acima de tudo)
---------------------------------------------------------------------------
f.prevMonth = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.prevMonth:SetSize(28, 22)
f.prevMonth:SetPoint("TOPLEFT", 18, -32)
f.prevMonth:SetText("<")

f.monthLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
f.monthLabel:SetPoint("LEFT", f.prevMonth, "RIGHT", 8, 0)
f.monthLabel:SetWidth(180)

f.nextMonth = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.nextMonth:SetSize(28, 22)
f.nextMonth:SetPoint("LEFT", f.monthLabel, "RIGHT", 8, 0)
f.nextMonth:SetText(">")

f.allChars = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
f.allChars:SetPoint("TOPRIGHT", -170, -30)
f.allChars.Text:SetFontObject("GameFontHighlight")

---------------------------------------------------------------------------
-- Resumo: quatro números
---------------------------------------------------------------------------
local tiles = {}
local TILE_W = (CHART_W - 3 * 8) / 4
for i = 1, 4 do
    local t = CreateFrame("Frame", nil, f)
    t:SetSize(TILE_W, 52)
    t:SetPoint("TOPLEFT", 24 + (i - 1) * (TILE_W + 8), -68)
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints()
    t.bg:SetColorTexture(0, 0, 0, 0.35)
    t.swatch = t:CreateTexture(nil, "ARTWORK")
    t.swatch:SetSize(8, 8)
    t.swatch:SetPoint("TOPLEFT", 8, -9)
    t.label = t:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t.label:SetPoint("TOPLEFT", 20, -8)
    t.value = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t.value:SetPoint("BOTTOMLEFT", 8, 9)
    t.value:SetPoint("RIGHT", -6, 0)
    t.value:SetJustifyH("LEFT")
    tiles[i] = t
end

---------------------------------------------------------------------------
-- Gráfico
---------------------------------------------------------------------------
local chart = CreateFrame("Frame", nil, f)
chart:SetSize(CHART_W, CHART_H)
chart:SetPoint("TOPLEFT", 24, -168)

-- Legenda (dois itens) acima do gráfico.
local function LegendItem(color, anchor, x)
    local sw = chart:CreateTexture(nil, "ARTWORK")
    sw:SetSize(10, 10)
    sw:SetColorTexture(color[1], color[2], color[3])
    sw:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", x, 8)
    local text = chart:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", sw, "RIGHT", 4, 0)
    return text
end
chart.legendEarn = LegendItem(EARN, chart, 0)
chart.legendSpend = LegendItem(SPEND, chart, 90)

chart.zero = chart:CreateTexture(nil, "BORDER")
chart.zero:SetHeight(1)
chart.zero:SetPoint("LEFT", chart, "LEFT", 0, 0)
chart.zero:SetPoint("RIGHT", chart, "RIGHT", 0, 0)
chart.zero:SetColorTexture(0.45, 0.45, 0.45, 0.9)

chart.topGrid = chart:CreateTexture(nil, "BACKGROUND")
chart.topGrid:SetHeight(1)
chart.topGrid:SetPoint("TOPLEFT"); chart.topGrid:SetPoint("TOPRIGHT")
chart.topGrid:SetColorTexture(0.3, 0.3, 0.3, 0.5)
chart.bottomGrid = chart:CreateTexture(nil, "BACKGROUND")
chart.bottomGrid:SetHeight(1)
chart.bottomGrid:SetPoint("BOTTOMLEFT"); chart.bottomGrid:SetPoint("BOTTOMRIGHT")
chart.bottomGrid:SetColorTexture(0.3, 0.3, 0.3, 0.5)

chart.maxLabel = chart:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
chart.maxLabel:SetPoint("BOTTOMRIGHT", chart, "TOPRIGHT", 0, 3)
chart.minLabel = chart:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
chart.minLabel:SetPoint("TOPRIGHT", chart, "BOTTOMRIGHT", 0, -3)

chart.empty = chart:CreateFontString(nil, "OVERLAY", "GameFontDisable")
chart.empty:SetPoint("CENTER", 0, 24)

local columns = {}
local SLOT = CHART_W / 31
local BAR_W = math.max(4, math.floor(SLOT - 6))

local function Column(i)
    local c = columns[i]
    if c then return c end
    c = CreateFrame("Button", nil, chart)
    c:SetSize(SLOT, CHART_H)
    c:SetPoint("TOPLEFT", (i - 1) * SLOT, 0)
    c.hover = c:CreateTexture(nil, "BACKGROUND")
    c.hover:SetAllPoints()
    c.hover:SetColorTexture(1, 1, 1, 0.06)
    c.hover:Hide()
    c.today = c:CreateTexture(nil, "BACKGROUND")
    c.today:SetAllPoints()
    c.today:SetColorTexture(1, 0.82, 0, 0.06)
    c.up = c:CreateTexture(nil, "ARTWORK")
    c.up:SetWidth(BAR_W)
    c.up:SetPoint("BOTTOM", c, "CENTER", 0, 1) -- 1 px de folga da linha do zero
    c.up:SetColorTexture(EARN[1], EARN[2], EARN[3])
    c.down = c:CreateTexture(nil, "ARTWORK")
    c.down:SetWidth(BAR_W)
    c.down:SetPoint("TOP", c, "CENTER", 0, -1)
    c.down:SetColorTexture(SPEND[1], SPEND[2], SPEND[3])
    c.dayLabel = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c.dayLabel:SetPoint("TOP", c, "BOTTOM", 0, -16)
    c:SetScript("OnEnter", function(self)
        self.hover:Show()
        local L = FT.L
        local d = self.data or { e = 0, s = 0 }
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(string.format(L.DASH_DAY_FMT, self.day, L.MONTHS[view.month], view.year))
        GameTooltip:AddDoubleLine(L.DASH_EARNED, FT:FormatMoney(d.e), EARN[1], EARN[2], EARN[3], 1, 1, 1)
        GameTooltip:AddDoubleLine(L.DASH_SPENT, FT:FormatMoney(d.s), SPEND[1], SPEND[2], SPEND[3], 1, 1, 1)
        local net = d.e - d.s
        GameTooltip:AddDoubleLine(L.DASH_NET, (net < 0 and "-" or "+") .. FT:FormatMoney(net), 1, 1, 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    columns[i] = c
    return c
end

---------------------------------------------------------------------------
-- Botões de baixo
---------------------------------------------------------------------------
local function BottomButton(key, onClick, anchor)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(130, 24)
    if anchor then b:SetPoint("LEFT", anchor, "RIGHT", 8, 0) else b:SetPoint("BOTTOMLEFT", 18, 14) end
    FT:T(b, key)
    b:SetScript("OnClick", onClick)
    return b
end
-- Configurações e Tutorial trocam de tela: o painel fecha.
f.configBtn = BottomButton("BTN_SETTINGS", function() f:Hide(); FT:ShowConfig() end)
f.sessionBtn = BottomButton("BTN_SESSION", function() FT:ToggleSessionWindow() end, f.configBtn)
f.tutorialBtn = BottomButton("BTN_TUTORIAL", function() f:Hide(); FT:ShowTutorial() end, f.sessionBtn)

f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
f.note:SetPoint("BOTTOMRIGHT", -20, 20)
f.note:SetWidth(170)
f.note:SetJustifyH("RIGHT")

---------------------------------------------------------------------------
-- Desenho
---------------------------------------------------------------------------
local function Render()
    if not FT.db then return end
    local L = FT.L
    local all = FT.db.dashAllChars and true or false
    f.monthLabel:SetText(string.format("%s %d", L.MONTHS[view.month], view.year))
    f.allChars.Text:SetText(L.DASH_ALL_CHARS)
    f.allChars:SetChecked(all)
    local t = date("*t")
    f.nextMonth:SetEnabled(view.year < t.year or (view.year == t.year and view.month < t.month))

    local days, earned, spent = FT:GoldForMonth(view.year, view.month, all)
    local isCurrent = view.year == t.year and view.month == t.month
    local today = isCurrent and days[t.day] or { e = 0, s = 0 }

    local function Tile(i, label, value, color, signed)
        local tile = tiles[i]
        tile.label:SetText(label)
        tile.value:SetText(signed and ((value < 0 and "-" or "+") .. FT:FormatMoney(value)) or FT:FormatMoney(value))
        tile.swatch:SetShown(color ~= nil)
        if color then tile.swatch:SetColorTexture(color[1], color[2], color[3]) end
        tile.label:ClearAllPoints()
        tile.label:SetPoint("TOPLEFT", color and 20 or 8, -8)
    end
    Tile(1, L.DASH_EARNED_MONTH, earned, EARN)
    Tile(2, L.DASH_SPENT_MONTH, spent, SPEND)
    Tile(3, L.DASH_NET_MONTH, earned - spent, nil, true)
    Tile(4, isCurrent and L.DASH_TODAY or L.DASH_BEST_DAY, 0, nil, true)
    if isCurrent then
        tiles[4].value:SetText(((today.e - today.s) < 0 and "-" or "+") .. FT:FormatMoney(today.e - today.s))
    else
        local best, bestDay = nil, nil
        for day, d in pairs(days) do
            if not best or d.e - d.s > best then best, bestDay = d.e - d.s, day end
        end
        tiles[4].value:SetText(bestDay and string.format("%d: %s%s", bestDay, best < 0 and "-" or "+", FT:FormatMoney(best)) or "-")
    end

    chart.legendEarn:SetText(L.DASH_EARNED)
    chart.legendSpend:SetText(L.DASH_SPENT)

    local n = DaysInMonth(view.year, view.month)
    local maxV = 0
    for _, d in pairs(days) do maxV = math.max(maxV, d.e, d.s) end
    local half = CHART_H / 2 - 2
    chart.maxLabel:SetText(maxV > 0 and ("+" .. FT:FormatMoney(maxV, true)) or "")
    chart.minLabel:SetText(maxV > 0 and ("-" .. FT:FormatMoney(maxV, true)) or "")
    chart.empty:SetText(maxV > 0 and "" or L.DASH_EMPTY)

    for i = 1, 31 do
        local c = Column(i)
        if i > n then
            c:Hide()
        else
            local d = days[i]
            c.day, c.data = i, d
            local hUp = (d and maxV > 0) and math.floor(d.e / maxV * half + 0.5) or 0
            local hDown = (d and maxV > 0) and math.floor(d.s / maxV * half + 0.5) or 0
            c.up:SetHeight(math.max(hUp, 1)); c.up:SetShown(hUp > 0)
            c.down:SetHeight(math.max(hDown, 1)); c.down:SetShown(hDown > 0)
            c.today:SetShown(isCurrent and i == t.day)
            -- Rótulo só em alguns dias (1, 5, 10, ...) para não amontoar.
            c.dayLabel:SetText((i == 1 or i % 5 == 0) and tostring(i) or "")
            c:Show()
        end
    end
    f.note:SetText(L.DASH_NOTE)
end

f.prevMonth:SetScript("OnClick", function()
    view.month = view.month - 1
    if view.month < 1 then view.month, view.year = 12, view.year - 1 end
    Render()
end)
f.nextMonth:SetScript("OnClick", function()
    view.month = view.month + 1
    if view.month > 12 then view.month, view.year = 1, view.year + 1 end
    Render()
end)
f.allChars:SetScript("OnClick", function(self)
    FT.db.dashAllChars = self:GetChecked() and true or false
    Render()
end)
f:SetScript("OnShow", Render)

function FT:ToggleDashboard()
    if f:IsShown() then
        f:Hide()
    else
        ResetView()
        f:Show()
        Render()
    end
end

function FT:RefreshDashboard()
    if f:IsShown() then Render() end
end
