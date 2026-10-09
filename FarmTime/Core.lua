-- Farm Time - Core
-- Namespace, configurações salvas, eventos e comandos de barra.

local ADDON_NAME, FT = ...
_G.FarmTime = FT

FT.defaults = {
    enabled       = true,
    onlyGathering = true,  -- destacar só ervas/minérios (false = qualquer objeto interagível)
    iconSize      = 36,    -- tamanho do ícone na placa (a placa acompanha)
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
    fastLoot      = true,  -- pega todo o saque na hora (Shift segurado desativa)
    sessionWindow = true,  -- janela da sessão abre sozinha ao coletar
    trackTradeGoods = true, -- sessão também conta materiais (carne, pano, couro...)
    language      = "enUS", -- "enUS" ou "ptBR"
    nodes         = {},    -- [instanceID] = { {x=, y=, z=, name=, kind=, gatheredAt=, confirmedAt=}, ... }
    hudEnabled    = true,  -- marcadores 3D dos nós salvos
    showHerbs     = true,  -- mostrar ervas (placa, marcadores, seta, aviso F)
    showOres      = true,  -- mostrar minérios
    fishToast     = true,  -- "conquista" animada a cada peixe pescado
    hudShowUnconfirmed = false, -- também mostrar (em cinza) nós ainda não confirmados
    arrowEnabled  = true,  -- seta para o nó confirmado mais próximo
    arrowRange    = 400,   -- jardas: alcance da seta
    shareGuild    = false, -- compartilhar nós (confirmados/coletados) com a guilda
    shareGroup    = false, -- compartilhar nós com o grupo/raide
    showPrompt    = true,  -- aviso "aperte F" perto de erva/minério/corpo esfolável
    hudRange      = 150,   -- jardas: nós mais longe que isso não aparecem
    hudFov        = 90,    -- campo de visão horizontal (graus) usado na projeção
    hudPitch      = 35,    -- inclinação da câmera para baixo (graus); calibre com /ft calibrate
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
        if not ok then FT:Print(string.format(FT.L.EVENT_ERROR, event, tostring(err))) end
    end
end)

FT:RegisterEvent("ADDON_LOADED", function(self, name)
    if name ~= ADDON_NAME then return end
    FarmTimeDB = FarmTimeDB or {}
    -- Remove dados da versão 0.1 (HUD por posição), que não são mais usados.
    FarmTimeDB.fov, FarmTimeDB.cameraHeight = nil, nil
    FarmTimeDB.maxRange, FarmTimeDB.updateRate, FarmTimeDB.showEdgeArrows = nil, nil, nil
    FarmTimeDB.showBanner, FarmTimeDB.pulse = nil, nil
    -- 0.7: visual de placa; o ícone ficou menor por padrão.
    if (FarmTimeDB.schema or 0) < 7 then FarmTimeDB.iconSize = nil end
    -- 1.5.1: até aqui os eixos de UnitPosition estavam trocados; nós salvos
    -- antes disso têm posições erradas e são descartados.
    if (FarmTimeDB.schema or 0) < 8 then FarmTimeDB.nodes = nil end
    FarmTimeDB.schema = 8
    CopyDefaults(self.defaults, FarmTimeDB)
    self.db = FarmTimeDB
end)

FT:RegisterEvent("PLAYER_LOGIN", function(self)
    if self.db.manageCVars then self:ApplyCVars() end
    self:ApplyLanguage()
    self:Print(self.L.LOADED)
    if self.missingEvents then
        self:Print(string.format(self.L.MISSING_EVENTS, table.concat(self.missingEvents, ", ")))
    end
end)

---------------------------------------------------------------------------
-- Comandos: /farmtime ou /ft
---------------------------------------------------------------------------
local commands = {}

-- Ervas/minérios podem ser escondidos separadamente (painel: Show herbs / Show ores).
function FT:KindVisible(kind)
    local db = self.db
    if not db then return true end
    if kind == "herb" then return db.showHerbs ~= false end
    if kind == "ore" then return db.showOres ~= false end
    return true
end

-- Muda uma opção e aplica o efeito. Usado pelos comandos e pelo painel.
function FT:SetOption(key, value)
    self.db[key] = value
    if key == "interactRange" then
        if self.db.manageCVars then self:ApplyCVars() end
    elseif key == "manageCVars" then
        if value then self:ApplyCVars() else self:RestoreCVars() end
    elseif key == "bindInteractKey" then
        if value then self:ApplyKeybind() else self:RestoreKeybind() end
    elseif key == "language" then
        self:ApplyLanguage()
    end
    if self.UpdatePrompt then self:UpdatePrompt() end
    self:RefreshHighlight()
    if self.RefreshConfig then self:RefreshConfig() end
end

-- labelKey é uma chave de FT.L, lida na hora (o idioma pode mudar).
local function Toggle(key, labelKey)
    return function()
        FT:SetOption(key, not FT.db[key])
        local label = string.format(FT.L[labelKey], FT.db.interactKey)
        FT:Print(label, FT.db[key] and FT.L.ON or FT.L.OFF)
    end
end

local function Number(key, labelKey, lo, hi)
    return function(arg)
        local v = tonumber(arg)
        if v and v >= lo and v <= hi then
            FT:SetOption(key, v)
            FT:Print(FT.L[labelKey], "=", v)
        else
            FT:Print(string.format(FT.L.USAGE_RANGE, lo, hi, tostring(FT.db[key])))
        end
    end
end

commands[""]    = function() FT:ToggleConfig() end
commands.config = commands[""]
commands.toggle = Toggle("enabled", "OPT_HIGHLIGHT")
commands.size   = Number("iconSize", "OPT_ICON_SIZE", 16, 96)
commands.range  = Number("interactRange", "OPT_RANGE", 5, 60)
commands.all    = function()
    FT:SetOption("onlyGathering", not FT.db.onlyGathering)
    FT:Print(FT.db.onlyGathering and FT.L.ONLY_GATHER_ON or FT.L.ONLY_GATHER_OFF)
end
commands.key    = Toggle("bindInteractKey", "OPT_KEY")
commands.sound  = Toggle("sound", "OPT_SOUND")
commands.loot   = Toggle("fastLoot", "OPT_FASTLOOT")
commands.mats   = Toggle("trackTradeGoods", "OPT_MATS")
commands.session = function() FT:ToggleSessionWindow() end
commands.hud    = Toggle("hudEnabled", "OPT_HUD")
commands.herbs  = Toggle("showHerbs", "OPT_HERBS")
commands.fishtoast = Toggle("fishToast", "OPT_FISHTOAST")
commands.fishtest  = function() FT:TestFishToast() end
commands.ores   = Toggle("showOres", "OPT_ORES")
commands.grey   = Toggle("hudShowUnconfirmed", "OPT_GREY")
commands.arrow  = Toggle("arrowEnabled", "OPT_ARROW")
commands.shareguild = Toggle("shareGuild", "OPT_SHARE_GUILD")
commands.sharegroup = Toggle("shareGroup", "OPT_SHARE_GROUP")
commands.arrowrange = Number("arrowRange", "OPT_ARROW_RANGE", 50, 2000)
commands.prompt = Toggle("showPrompt", "OPT_PROMPT")
commands.fov    = Number("hudFov", "OPT_FOV", 40, 150)
commands.pitch  = Number("hudPitch", "OPT_PITCH", 0, 85)
commands.calibrate = function() FT:StartCalibration() end
commands.nodes  = function()
    local total, here = FT:CountNodes()
    FT:Print(string.format(FT.L.NODES_COUNT, total, here))
end
commands.clearnodes = function(arg)
    FT:ClearNodes(arg == "all")
    FT:Print(arg == "all" and FT.L.NODES_CLEARED_ALL or FT.L.NODES_CLEARED)
end
commands.reset  = function() FT:ResetSession(); FT:Print(FT.L.SESSION_CLEARED) end
commands.debug  = Toggle("debug", "OPT_DEBUG")
commands.minimap = function()
    FT.db.minimap.hide = not FT.db.minimap.hide
    FT:UpdateMinimapButton()
    FT:Print(FT.db.minimap.hide and FT.L.MINIMAP_HIDDEN or FT.L.MINIMAP_SHOWN)
end
-- /ft lang [en|pt]: sem argumento, alterna entre os idiomas.
commands.lang   = function(arg)
    local code
    if arg:find("^en") then code = "enUS"
    elseif arg:find("^pt") then code = "ptBR"
    else code = (FT.db.language == "enUS") and "ptBR" or "enUS" end
    FT:SetOption("language", code)
    FT:Print(FT.L.LANGUAGE_SET)
end

-- Diagnóstico: versão do cliente, opções do jogo e alvo de interação atual.
-- Cada parte roda separada, para que uma falha não esconda o resto.
commands.status = function()
    local ok, err = pcall(function()
        local version, build, _, toc = GetBuildInfo()
        FT:Print(FT.L.STATUS_CLIENT, tostring(version), tostring(build), "interface", tostring(toc))
    end)
    if not ok then FT:Print(FT.L.STATUS_CLIENT .. ": " .. FT.L.STATUS_ERROR, tostring(err)) end

    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    for _, cvar in ipairs({ "SoftTargetInteract", "SoftTargetIconInteract",
        "SoftTargetIconGameObject", "SoftTargetLowPriorityIcons", "SoftTargetInteractRange" }) do
        local okc, v = pcall(getter, cvar)
        print("  " .. cvar .. " = " .. (okc and v ~= nil and tostring(v) or FT.L.CVAR_MISSING))
    end

    local okt, guid, name, kind = pcall(FT.GetInteractTarget, FT)
    if okt then
        print("  " .. FT.L.STATUS_TARGET .. ": " .. tostring(name) .. " / " .. tostring(kind) .. " / " .. tostring(guid))
    else
        print("  " .. FT.L.STATUS_TARGET .. ": " .. FT.L.STATUS_ERROR .. " " .. tostring(guid))
    end
    if FT.ShareStatus then
        local oks, text = pcall(FT.ShareStatus, FT)
        print("  " .. tostring(text))
    end
    if FT.PositionStatus then
        local okp, text = pcall(FT.PositionStatus, FT)
        print("  HUD: " .. tostring(text))
    end
    if FT.missingEvents then
        print("  " .. FT.L.STATUS_MISSING .. ": " .. table.concat(FT.missingEvents, ", "))
    end
end

commands.restore = function()
    FT:SetOption("manageCVars", false)
    FT:Print(FT.L.CVARS_RESTORED)
end

commands.apply = function()
    FT:SetOption("manageCVars", true)
    FT:Print(FT.L.CVARS_APPLIED)
end

commands.help = function()
    FT:Print(FT.L.HELP_TITLE)
    for _, line in ipairs(FT.L.HELP) do print("  " .. line) end
end

SLASH_FARMTIME1 = "/farmtime"
SLASH_FARMTIME2 = "/ft"
SlashCmdList.FARMTIME = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local fn = commands[cmd] or commands.help
    local ok, err = pcall(fn, arg)
    if not ok then FT:Print(string.format(FT.L.CMD_ERROR, cmd, tostring(err))) end
end
