-- Farm Time - Core
-- Namespace, configurações salvas, eventos e comandos de barra.

local ADDON_NAME, FT = ...
_G.FarmTime = FT

FT.defaults = {
    enabled       = true,
    onlyGathering = true,  -- destacar só ervas/minérios (false = qualquer objeto interagível)
    iconSize      = 36,    -- tamanho do ícone na placa (a placa acompanha)
    pulse         = false, -- animação de pulsar
    anchorToNode  = true,  -- prender o ícone em cima do nó (placa do jogo), se existir
    nodeOffset    = 10,    -- distância (px) entre a placa do jogo e o ícone
    hideGameName  = true,  -- esconde o nome/ícone que o jogo desenha sobre o nó
    sound         = true,  -- som quando uma erva/minério vira alvo de interação
    debug         = false, -- imprime no chat cada mudança de alvo de interação
    interactRange = 30,    -- alcance (jardas) do soft target de interação
    manageCVars   = true,  -- o addon liga as opções de soft target do jogo
    savedCVars    = {},    -- valores originais, para /ft restore
    names         = {},    -- [nome do nó] = "herb" | "ore" (aprendido ao coletar)
    minimap       = { hide = false, angle = 215 }, -- botão no minimapa
    bindInteractKey = true, -- liga a tecla abaixo ao "Interagir com o alvo"
    interactKey   = "F",
    savedBinding  = {},    -- o que a tecla fazia antes, para devolver
    nodeIcons     = {},    -- [nome do nó] = ícone do item coletado (aprendido)
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

-- Registrar um evento que não existe nesse cliente gera erro e interromperia o
-- carregamento do arquivo; com pcall o addon só avisa e continua.
local function SafeRegister(method, event, ...)
    local ok, err = pcall(frame[method], frame, event, ...)
    if not ok then
        FT.missingEvents = FT.missingEvents or {}
        table.insert(FT.missingEvents, event)
    end
    return ok
end

function FT:RegisterEvent(event, fn)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], fn)
    SafeRegister("RegisterEvent", event)
end

function FT:RegisterUnitEvent(event, unit, fn)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], fn)
    SafeRegister("RegisterUnitEvent", event, unit)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = FT.handlers[event]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, FT, ...)
        if not ok then FT:Print("erro em " .. event .. ": " .. tostring(err)) end
    end
end)

FT:RegisterEvent("ADDON_LOADED", function(self, name)
    if name ~= ADDON_NAME then return end
    FarmTimeDB = FarmTimeDB or {}
    -- Remove dados da versão 0.1 (HUD por posição), que não são mais usados.
    FarmTimeDB.nodes, FarmTimeDB.fov, FarmTimeDB.cameraHeight = nil, nil, nil
    FarmTimeDB.maxRange, FarmTimeDB.updateRate, FarmTimeDB.showEdgeArrows = nil, nil, nil
    FarmTimeDB.showBanner = nil
    -- 0.6: o pulsar passou a vir desligado.
    if (FarmTimeDB.schema or 0) < 6 then FarmTimeDB.pulse = false end
    -- 0.7: visual de placa; o ícone ficou menor por padrão.
    if (FarmTimeDB.schema or 0) < 7 then FarmTimeDB.iconSize = nil end
    FarmTimeDB.schema = 7
    CopyDefaults(self.defaults, FarmTimeDB)
    self.db = FarmTimeDB
end)

FT:RegisterEvent("PLAYER_LOGIN", function(self)
    if self.db.manageCVars then self:ApplyCVars() end
    self:Print("carregado. Clique no ícone do minimapa ou digite /ft help.")
    if self.missingEvents then
        self:Print("eventos que não existem neste cliente: " .. table.concat(self.missingEvents, ", "))
    end
end)

---------------------------------------------------------------------------
-- Comandos: /farmtime ou /ft
---------------------------------------------------------------------------
local commands = {}

-- Muda uma opção e aplica o efeito. Usado pelos comandos e pelo painel.
function FT:SetOption(key, value)
    self.db[key] = value
    if key == "interactRange" then
        if self.db.manageCVars then self:ApplyCVars() end
    elseif key == "manageCVars" then
        if value then self:ApplyCVars() else self:RestoreCVars() end
    elseif key == "bindInteractKey" then
        if value then self:ApplyKeybind() else self:RestoreKeybind() end
    end
    self:RefreshHighlight()
    if self.RefreshConfig then self:RefreshConfig() end
end

local function Toggle(key, label)
    return function()
        FT:SetOption(key, not FT.db[key])
        FT:Print(label, FT.db[key] and "ligado" or "desligado")
    end
end

local function Number(key, label, lo, hi)
    return function(arg)
        local v = tonumber(arg)
        if v and v >= lo and v <= hi then
            FT:SetOption(key, v)
            FT:Print(label, "=", v)
        else
            FT:Print(string.format("uso: %d-%d (atual: %s)", lo, hi, tostring(FT.db[key])))
        end
    end
end

commands[""]    = function() FT:ToggleConfig() end
commands.config = commands[""]
commands.toggle = Toggle("enabled", "destaque")
commands.size   = Number("iconSize", "tamanho do ícone", 16, 96)
commands.range  = Number("interactRange", "alcance (o jogo pode limitar)", 5, 60)
commands.all    = function()
    FT:SetOption("onlyGathering", not FT.db.onlyGathering)
    FT:Print(FT.db.onlyGathering and "destacando só ervas e minérios"
        or "destacando qualquer objeto interagível")
end
commands.pulse  = Toggle("pulse", "pulsar")
commands.key    = Toggle("bindInteractKey", "tecla " .. FT.defaults.interactKey .. " para coletar")
commands.sound  = Toggle("sound", "som")
commands.debug  = Toggle("debug", "debug")
commands.minimap = function()
    FT.db.minimap.hide = not FT.db.minimap.hide
    FT:UpdateMinimapButton()
    FT:Print("botão do minimapa", FT.db.minimap.hide and "escondido" or "visível")
end

-- Diagnóstico: versão do cliente, opções do jogo e alvo de interação atual.
-- Cada parte roda separada, para que uma falha não esconda o resto.
commands.status = function()
    local ok, err = pcall(function()
        local version, build, _, toc = GetBuildInfo()
        FT:Print("cliente", tostring(version), tostring(build), "interface", tostring(toc))
    end)
    if not ok then FT:Print("versão: erro", tostring(err)) end

    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    for _, cvar in ipairs({ "SoftTargetInteract", "SoftTargetIconInteract",
        "SoftTargetIconGameObject", "SoftTargetLowPriorityIcons", "SoftTargetInteractRange" }) do
        local okc, v = pcall(getter, cvar)
        print("  " .. cvar .. " = " .. (okc and v ~= nil and tostring(v) or "(não existe)"))
    end

    local okt, guid, name, kind = pcall(FT.GetInteractTarget, FT)
    if okt then
        print("  alvo de interação: " .. tostring(name) .. " / " .. tostring(kind) .. " / " .. tostring(guid))
    else
        print("  alvo de interação: erro " .. tostring(guid))
    end
    if FT.missingEvents then
        print("  eventos ausentes: " .. table.concat(FT.missingEvents, ", "))
    end
end

commands.restore = function()
    FT:SetOption("manageCVars", false)
    FT:Print("opções do jogo restauradas. Use /ft apply para religar.")
end

commands.apply = function()
    FT:SetOption("manageCVars", true)
    FT:Print("opções do jogo aplicadas.")
end

commands.help = function()
    FT:Print("comandos:")
    print("  /ft               - abre/fecha o painel de configurações")
    print("  /ft toggle        - liga/desliga o destaque")
    print("  /ft minimap       - mostra/esconde o botão do minimapa")
    print("  /ft size <px>     - tamanho do ícone na placa")
    print("  /ft range <jd>    - alcance do soft target de interação")
    print("  /ft all           - alterna: só ervas/minérios ou qualquer objeto")
    print("  /ft pulse         - liga/desliga a animação")
    print("  /ft key           - liga/desliga a tecla F para coletar")
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
    local ok, err = pcall(fn, arg)
    if not ok then FT:Print("erro no comando '" .. cmd .. "': " .. tostring(err)) end
end
