-- Farm Time - Core
-- Namespace, configurações salvas, eventos e comandos de barra.

local ADDON_NAME, FT = ...
_G.FarmTime = FT

FT.defaults = {
    enabled       = true,
    onlyGathering = true,  -- destacar só ervas/minérios (false = qualquer objeto interagível)
    iconSize      = 64,    -- tamanho do ícone do alerta
    pulse         = true,  -- animação de pulsar
    sound         = true,  -- som quando uma erva/minério vira alvo de interação
    debug         = false, -- imprime no chat cada mudança de alvo de interação
    interactRange = 30,    -- alcance (jardas) do soft target de interação
    manageCVars   = true,  -- o addon liga as opções de soft target do jogo
    savedCVars    = {},    -- valores originais, para /ft restore
    names         = {},    -- [nome do nó] = "herb" | "ore" (aprendido ao coletar)
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function FT:Print(...)
    print("|cff33ff99Farm Time|r:", ...)
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
FT.handlers = {}

function FT:RegisterEvent(event, fn)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], fn)
    frame:RegisterEvent(event)
end

function FT:RegisterUnitEvent(event, unit, fn)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], fn)
    frame:RegisterUnitEvent(event, unit)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = FT.handlers[event]
    if not list then return end
    for _, fn in ipairs(list) do fn(FT, ...) end
end)

FT:RegisterEvent("ADDON_LOADED", function(self, name)
    if name ~= ADDON_NAME then return end
    FarmTimeDB = FarmTimeDB or {}
    -- Remove dados da versão 0.1 (HUD por posição), que não são mais usados.
    FarmTimeDB.nodes, FarmTimeDB.fov, FarmTimeDB.cameraHeight = nil, nil, nil
    FarmTimeDB.maxRange, FarmTimeDB.updateRate, FarmTimeDB.showEdgeArrows = nil, nil, nil
    FarmTimeDB.showBanner = nil
    CopyDefaults(self.defaults, FarmTimeDB)
    self.db = FarmTimeDB
end)

FT:RegisterEvent("PLAYER_LOGIN", function(self)
    if self.db.manageCVars then self:ApplyCVars() end
    self:Print("carregado. Digite /ft help para os comandos.")
end)

---------------------------------------------------------------------------
-- Comandos: /farmtime ou /ft
---------------------------------------------------------------------------
local commands = {}

commands[""] = function()
    FT.db.enabled = not FT.db.enabled
    FT:Print(FT.db.enabled and "ativado" or "desativado")
    FT:RefreshHighlight()
end

commands.size = function(arg)
    local v = tonumber(arg)
    if v and v >= 16 and v <= 160 then
        FT.db.iconSize = v
        FT:Print("tamanho do ícone =", v)
        FT:RefreshHighlight()
    else
        FT:Print("uso: /ft size <16-160>  (atual:", FT.db.iconSize .. ")")
    end
end

commands.range = function(arg)
    local v = tonumber(arg)
    if v and v >= 5 and v <= 60 then
        FT.db.interactRange = v
        FT:ApplyCVars()
        FT:Print("alcance =", v, "jardas (o jogo pode limitar a um valor menor)")
    else
        FT:Print("uso: /ft range <5-60>  (atual:", FT.db.interactRange .. ")")
    end
end

commands.all = function()
    FT.db.onlyGathering = not FT.db.onlyGathering
    FT:Print(FT.db.onlyGathering and "destacando só ervas e minérios"
        or "destacando qualquer objeto interagível")
    FT:RefreshHighlight()
end

commands.pulse = function()
    FT.db.pulse = not FT.db.pulse
    FT:Print("pulsar", FT.db.pulse and "ligado" or "desligado")
    FT:RefreshHighlight()
end

commands.sound = function()
    FT.db.sound = not FT.db.sound
    FT:Print("som", FT.db.sound and "ligado" or "desligado")
end

commands.debug = function()
    FT.db.debug = not FT.db.debug
    FT:Print("debug", FT.db.debug and "ligado" or "desligado")
end

-- Diagnóstico: versão do cliente, opções do jogo e alvo de interação atual.
commands.status = function()
    local _, build, _, toc = GetBuildInfo()
    FT:Print("cliente", build, "interface", toc)
    local GetCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
    for _, cvar in ipairs({ "SoftTargetInteract", "SoftTargetIconInteract",
        "SoftTargetIconGameObject", "SoftTargetLowPriorityIcons", "SoftTargetInteractRange" }) do
        local ok, v = pcall(GetCVar, cvar)
        print("  " .. cvar .. " = " .. tostring(ok and v or "(não existe)"))
    end
    local guid, name, kind = FT:GetInteractTarget()
    print("  alvo de interação: " .. tostring(name) .. " / " .. tostring(kind) .. " / " .. tostring(guid))
end

commands.restore = function()
    FT:RestoreCVars()
    FT.db.manageCVars = false
    FT:Print("opções de soft target restauradas. Use /ft apply para religar.")
end

commands.apply = function()
    FT.db.manageCVars = true
    FT:ApplyCVars()
    FT:Print("opções de soft target aplicadas.")
end

commands.help = function()
    FT:Print("comandos:")
    print("  /ft               - liga/desliga o destaque")
    print("  /ft size <px>     - tamanho do ícone do alerta")
    print("  /ft range <jd>    - alcance do soft target de interação")
    print("  /ft all           - alterna: só ervas/minérios ou qualquer objeto")
    print("  /ft pulse         - liga/desliga a animação")
    print("  /ft sound         - liga/desliga o som")
    print("  /ft status        - mostra versão do cliente e opções do jogo")
    print("  /ft debug         - imprime cada mudança de alvo de interação")
    print("  /ft restore       - devolve as opções de soft target originais")
    print("  /ft apply         - reaplica as opções de soft target do Farm Time")
end

SLASH_FARMTIME1 = "/farmtime"
SLASH_FARMTIME2 = "/ft"
SlashCmdList.FARMTIME = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local fn = commands[cmd] or commands.help
    fn(arg)
end
