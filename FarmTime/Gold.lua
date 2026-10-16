-- Farm Time - Registro de ouro
--
-- Cada mudança de dinheiro do personagem (PLAYER_MONEY) entra no dia de hoje:
-- aumento = ganho, diminuição = gasto. Fica salvo no próprio addon
-- (FarmTimeDB.gold), por personagem, um registro por dia:
--   FarmTimeDB.gold["Nome-Reino"].days["2026-10-16"] = { e = cobre ganho, s = cobre gasto }
-- Tudo conta: saque, venda, correio, leilão, consertos, treinos, trocas...

local _, FT = ...

local last -- dinheiro conhecido na última mudança (cobre)

local function CharKey()
    local name = UnitName("player") or "?"
    local realm = (GetRealmName and GetRealmName()) or ""
    return name .. "-" .. realm
end
FT.CharKey = CharKey

local function Today()
    return date("%Y-%m-%d")
end

local function CharData(create)
    FT.db.gold = FT.db.gold or {}
    local key = CharKey()
    local c = FT.db.gold[key]
    if not c and create then
        c = { days = {} }
        FT.db.gold[key] = c
    end
    return c
end

FT:RegisterEvent("PLAYER_LOGIN", function(self)
    -- O que mudou com o personagem desconectado não entra (não dá para saber o dia).
    last = GetMoney()
    CharData(true)
end)

FT:RegisterEvent("PLAYER_MONEY", function(self)
    local now = GetMoney()
    if not last then last = now return end
    local diff = now - last
    last = now
    if diff == 0 then return end
    local day = CharData(true).days
    local d = day[Today()] or { e = 0, s = 0 }
    if diff > 0 then d.e = d.e + diff else d.s = d.s - diff end
    day[Today()] = d
    if self.RefreshDashboard then self:RefreshDashboard() end
end)

-- Soma de um mês. allChars = true junta todos os personagens.
-- Retorna { [dia] = { e =, s = } } e os totais ganho, gasto.
function FT:GoldForMonth(year, month, allChars)
    local prefix = string.format("%04d-%02d-", year, month)
    local out, earned, spent = {}, 0, 0
    local chars = {}
    if allChars then
        for _, c in pairs(self.db.gold or {}) do table.insert(chars, c) end
    else
        local c = CharData(false)
        if c then chars[1] = c end
    end
    for _, c in ipairs(chars) do
        for key, d in pairs(c.days or {}) do
            if key:sub(1, 8) == prefix then
                local day = tonumber(key:sub(9, 10))
                local o = out[day] or { e = 0, s = 0 }
                o.e, o.s = o.e + (d.e or 0), o.s + (d.s or 0)
                out[day] = o
                earned, spent = earned + (d.e or 0), spent + (d.s or 0)
            end
        end
    end
    return out, earned, spent
end

-- Cobre -> texto. short = sem ícones, só a maior moeda e a seguinte ("12g 5s").
function FT:FormatMoney(copper, short)
    copper = math.floor(math.abs(copper or 0) + 0.5)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if short then
        if g > 0 then return s > 0 and string.format("%dg %ds", g, s) or string.format("%dg", g) end
        if s > 0 then return c > 0 and string.format("%ds %dc", s, c) or string.format("%ds", s) end
        return string.format("%dc", c)
    end
    if GetCoinTextureString then
        local ok, text = pcall(GetCoinTextureString, copper)
        if ok and text then return text end
    end
    return string.format("%dg %ds %dc", g, s, c)
end
