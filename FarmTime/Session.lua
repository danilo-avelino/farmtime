-- Farm Time - Sessão de coleta
--
-- Janela móvel que lista tudo o que foi coletado (erva, minério, skinning,
-- pesca e, opcionalmente, materiais de profissão saqueados de qualquer lugar)
-- e quanto vale pelo último preço visto no Auctionator.
-- A sessão fica só na memória: reseta ao relogar (ou /reload) e a janela some
-- até a próxima coleta. Só a posição da janela é salva.

local _, FT = ...

local ROW_HEIGHT = 18
local MAX_ROWS = 15
local WIDTH = 250

local session = { start = nil, items = {} } -- items[itemID] = { id, name, icon, count, quality }

---------------------------------------------------------------------------
-- Preço e dinheiro
---------------------------------------------------------------------------
-- Último preço que o Auctionator viu no leilão, em cobre (nil se não souber).
local function GetPrice(itemID)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemID) then return nil end
    local ok, price = pcall(api.GetAuctionPriceByItemID, "Farm Time", itemID)
    if ok and type(price) == "number" then return price end
end

local function HasAuctionator()
    return Auctionator and Auctionator.API and Auctionator.API.v1 and true or false
end

local CoinString = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString

local function FormatMoney(copper)
    if not copper then return "|cff808080—|r" end
    copper = math.floor(copper + 0.5)
    if CoinString then
        local ok, text = pcall(CoinString, copper)
        if ok and text then return text end
    end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    return string.format("%dg %ds %dc", g, s, c)
end

local function FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

---------------------------------------------------------------------------
-- Janela
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "FarmTimeSession", UIParent)
frame:SetSize(WIDTH, 80)
frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    FT.db.sessionPos = { point = point, relPoint = relPoint, x = x, y = y }
end

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
end)

local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)

local function Edge(p1, p2, horizontal)
    local t = frame:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0.35, 0.8, 0.35, 0.9)
    t:SetPoint(p1)
    t:SetPoint(p2)
    if horizontal then t:SetHeight(1) else t:SetWidth(1) end
end
Edge("TOPLEFT", "TOPRIGHT", true)
Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
Edge("TOPLEFT", "BOTTOMLEFT", false)
Edge("TOPRIGHT", "BOTTOMRIGHT", false)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 8, -7)
title:SetText("Farm Time")

local timer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
timer:SetPoint("LEFT", title, "RIGHT", 8, 0)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetSize(22, 22)
close:SetPoint("TOPRIGHT", 2, 2)

local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
reset:SetSize(54, 18)
reset:SetPoint("RIGHT", close, "LEFT", 0, 0)
FT:T(reset, "SESSION_RESET")
reset:SetScript("OnClick", function() FT:ResetSession() end)
reset:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(FT.L.SESSION_RESET_TT)
    GameTooltip:AddLine(FT.L.SESSION_RESET_TT2, 1, 1, 1)
    GameTooltip:Show()
end)
reset:SetScript("OnLeave", function() GameTooltip:Hide() end)

local divider = frame:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(1, 1, 1, 0.15)
divider:SetPoint("TOPLEFT", 6, -26)
divider:SetPoint("TOPRIGHT", -6, -26)
divider:SetHeight(1)

local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
empty:SetPoint("TOPLEFT", 10, -34)
FT:T(empty, "SESSION_EMPTY")

local totalLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
totalLabel:SetPoint("BOTTOMLEFT", 8, 8)
FT:T(totalLabel, "SESSION_TOTAL")

local totalValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
totalValue:SetPoint("BOTTOMRIGHT", -8, 8)

local note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
note:SetPoint("BOTTOMLEFT", totalLabel, "TOPLEFT", 0, 4)
FT:T(note, "SESSION_NO_AH")

local rows = {}
local function GetRow(i)
    local row = rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, frame)
    row:SetSize(WIDTH - 16, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 8, -30 - (i - 1) * ROW_HEIGHT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetJustifyH("LEFT")
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT")
    row.value:SetJustifyH("RIGHT")
    row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    rows[i] = row
    return row
end

local function QualityHex(quality)
    local c = ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality]
    return c and c.hex or "|cffffffff"
end

local function UpdateTimer()
    timer:SetText(session.start and FormatTime(GetTime() - session.start) or "0:00:00")
end

function FT:RefreshSession()
    UpdateTimer()

    local list, total, anyPrice = {}, 0, false
    for _, item in pairs(session.items) do
        local unit = GetPrice(item.id)
        item.value = unit and unit * item.count or nil
        if item.value then
            total = total + item.value
            anyPrice = true
        end
        table.insert(list, item)
    end
    table.sort(list, function(a, b)
        if (a.value or -1) ~= (b.value or -1) then return (a.value or -1) > (b.value or -1) end
        return a.count > b.count
    end)

    local shown = math.min(#list, MAX_ROWS)
    for i = 1, shown do
        local item, row = list[i], GetRow(i)
        row.icon:SetTexture(item.icon)
        row.name:SetText(string.format("%s%s|r |cffbbbbbbx%d|r", QualityHex(item.quality), item.name or "?", item.count))
        row.value:SetText(FormatMoney(item.value))
        row:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide() end

    empty:SetShown(#list == 0)
    note:SetShown(not HasAuctionator())
    totalValue:SetText(anyPrice and FormatMoney(total) or FormatMoney(nil))

    local listHeight = math.max(shown, 1) * ROW_HEIGHT
    local footer = note:IsShown() and 40 or 26
    frame:SetHeight(30 + listHeight + 6 + footer)
end

local ticker
frame:SetScript("OnShow", function()
    FT:RefreshSession()
    if not ticker then ticker = C_Timer.NewTicker(1, UpdateTimer) end
end)
frame:SetScript("OnHide", function()
    if ticker then ticker:Cancel(); ticker = nil end
end)

---------------------------------------------------------------------------
-- API usada pelo Loot.lua e pelos comandos
---------------------------------------------------------------------------
function FT:AddSessionItem(item)
    if not session.start then session.start = GetTime() end
    local entry = session.items[item.id]
    if entry then
        entry.count = entry.count + item.count
    else
        session.items[item.id] = {
            id = item.id, name = item.name, icon = item.icon,
            count = item.count, quality = item.quality,
        }
    end
    if self.db.sessionWindow then
        if frame:IsShown() then self:RefreshSession() else frame:Show() end
    end
end

function FT:ResetSession()
    session.start = nil
    wipe(session.items)
    self:RefreshSession()
end

function FT:ToggleSessionWindow()
    frame:SetShown(not frame:IsShown())
end

FT:RegisterEvent("PLAYER_LOGIN", function(self)
    local pos = self.db.sessionPos
    if pos and pos.point then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    end
end)
