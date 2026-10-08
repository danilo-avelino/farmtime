-- Farm Time - Estilo visual compartilhado
--
-- "Placa" no estilo nameplate, usada pela placa sobre o nó, pelos marcadores
-- dos nós salvos e pela seta:
--   fundo escuro, contorno preto, borda e faixa de baixo na cor do recurso,
--   ícone emoldurado à esquerda, título e subtítulo à direita.
-- Feita só com texturas de cor (sem BackdropTemplate), igual em todos os clientes.

local _, FT = ...

local Style = {}
FT.Style = Style

Style.COLORS = {
    herb  = { 0.3, 1.0, 0.3 },
    ore   = { 1.0, 0.7, 0.2 },
    skin  = { 0.9, 0.6, 0.4 },
    other = { 0.6, 0.8, 1.0 },
    grey  = { 0.55, 0.55, 0.55 },
}

-- Moldura de 4 texturas finas. inset > 0 desenha por fora do frame.
function Style.CreateBorder(parent, layer, thickness, inset)
    local edges = {}
    for i = 1, 4 do edges[i] = parent:CreateTexture(nil, layer) end
    local t, o = thickness, inset or 0
    edges[1]:SetPoint("TOPLEFT", -o, o);     edges[1]:SetPoint("TOPRIGHT", o, o);     edges[1]:SetHeight(t)
    edges[2]:SetPoint("BOTTOMLEFT", -o, -o); edges[2]:SetPoint("BOTTOMRIGHT", o, -o); edges[2]:SetHeight(t)
    edges[3]:SetPoint("TOPLEFT", -o, o);     edges[3]:SetPoint("BOTTOMLEFT", -o, -o); edges[3]:SetWidth(t)
    edges[4]:SetPoint("TOPRIGHT", o, o);     edges[4]:SetPoint("BOTTOMRIGHT", o, -o); edges[4]:SetWidth(t)
    return {
        SetColor = function(_, r, g, b, a)
            for _, e in ipairs(edges) do e:SetColorTexture(r, g, b, a or 1) end
        end,
    }
end

local Plate = {}

-- opts.titleFont / opts.subFont: fontes (padrão GameFontNormal / GameFontHighlightSmall).
function Style.CreatePlate(parent, opts)
    opts = opts or {}
    local p = CreateFrame("Frame", opts.name, parent)
    p:EnableMouse(false)

    p.bg = p:CreateTexture(nil, "BACKGROUND")
    p.bg:SetAllPoints()
    p.bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)

    -- Faixa colorida na base, como a barra de vida de uma nameplate.
    p.bar = p:CreateTexture(nil, "BORDER")
    p.bar:SetPoint("BOTTOMLEFT", 2, 2)
    p.bar:SetPoint("BOTTOMRIGHT", -2, 2)
    p.bar:SetHeight(opts.barHeight or 3)

    p.outer = Style.CreateBorder(p, "OVERLAY", 1, 1)  -- contorno preto
    p.outer:SetColor(0, 0, 0, 1)
    p.border = Style.CreateBorder(p, "BORDER", opts.borderSize or 2, 0) -- borda colorida

    p.iconFrame = CreateFrame("Frame", nil, p)
    p.iconFrame:SetPoint("LEFT", p, "LEFT", 4, 1)
    p.icon = p.iconFrame:CreateTexture(nil, "ARTWORK")
    p.icon:SetAllPoints()
    p.iconBorder = Style.CreateBorder(p.iconFrame, "OVERLAY", 1, 1)
    p.iconBorder:SetColor(0, 0, 0, 1)

    p.text = p:CreateFontString(nil, "OVERLAY", opts.titleFont or "GameFontNormal")
    p.text:SetJustifyH("LEFT")
    p.text:SetShadowOffset(1, -1)

    p.sub = p:CreateFontString(nil, "OVERLAY", opts.subFont or "GameFontHighlightSmall")
    p.sub:SetJustifyH("LEFT")
    p.sub:SetTextColor(0.75, 0.75, 0.75)

    for k, f in pairs(Plate) do p[k] = f end
    return p
end

-- Ajusta a placa. icon: textura (ou nil para deixar como está, ex. cursor);
-- title/sub: textos (sub pode ser nil); color: {r,g,b}; size: lado do ícone.
-- dim = true deixa tudo cinza e meio transparente (nó não confirmado).
function Plate:SetContent(icon, title, sub, color, size, dim)
    if icon then
        self.icon:SetTexture(icon)
        self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    self.icon:SetDesaturated(dim and true or false)

    local c = dim and Style.COLORS.grey or color or Style.COLORS.other
    self.text:SetText(title or "")
    self.text:SetTextColor(c[1], c[2], c[3])
    self.sub:SetText(sub or "")
    self.sub:SetShown(sub ~= nil and sub ~= "")
    self.border:SetColor(c[1] * 0.8, c[2] * 0.8, c[3] * 0.8, 1)
    self.bar:SetColorTexture(c[1], c[2], c[3], 0.9)

    -- Título sozinho fica centralizado na altura do ícone; com subtítulo, empilha.
    self.text:ClearAllPoints()
    self.sub:ClearAllPoints()
    if self.sub:IsShown() then
        self.text:SetPoint("TOPLEFT", self.iconFrame, "TOPRIGHT", 7, -1)
        self.sub:SetPoint("BOTTOMLEFT", self.iconFrame, "BOTTOMRIGHT", 7, 1)
    else
        self.text:SetPoint("LEFT", self.iconFrame, "RIGHT", 6, 0)
    end

    local textWidth = 0
    if (title and title ~= "") or self.sub:IsShown() then
        textWidth = math.max(self.text:GetStringWidth() or 0, self.sub:IsShown() and self.sub:GetStringWidth() or 0) + 6 + 6
    end
    self.iconFrame:SetSize(size, size)
    self:SetSize(4 + size + textWidth + 4, size + 9)
    self:SetAlpha(dim and 0.65 or 1)
end
