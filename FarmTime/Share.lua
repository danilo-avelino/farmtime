-- Farm Time - Compartilhar nós com outros jogadores
--
-- Usa o canal oficial de mensagens entre addons (C_ChatInfo.SendAddonMessage),
-- o mesmo que GatherMate2/GatherLite usam. Só quem também tem o Farm Time
-- recebe; nada aparece no chat de ninguém.
--
-- O que é enviado (e só se a opção estiver ligada para aquele canal):
--   "C" = um nó foi confirmado agora (está lá) -> fica colorido para os outros
--   "G" = um nó foi coletado agora (sumiu)     -> some para os outros
-- Formato: 1~código~instância~x~y~tipo~nome   (posições em jardas, 1 casa)
-- Canais: GUILD e PARTY/RAID. Limite do jogo: ~255 bytes por mensagem e um
-- ritmo de envio; por isso há uma fila que envia aos poucos.

local _, FT = ...

local PREFIX  = "FarmTime"
local VERSION = "2" -- 2: eixos corrigidos; mensagens "1" (posições trocadas) são ignoradas
local SEP     = "~"
local RESEND_COOLDOWN = 30 -- segundos: não reenvia o mesmo aviso do mesmo nó antes disso

local Register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
local Send     = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage

if Register then pcall(Register, PREFIX) end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

---------------------------------------------------------------------------
-- Envio
---------------------------------------------------------------------------
local queue = {}     -- mensagens esperando a vez
local lastSent = {}  -- [chave do aviso] = GetTime() do último envio

local function Channels()
    local db, list = FT.db, {}
    if db.shareGuild and IsInGuild and IsInGuild() then table.insert(list, "GUILD") end
    if db.shareGroup then
        if IsInRaid and IsInRaid() then
            table.insert(list, "RAID")
        elseif IsInGroup and IsInGroup() then
            table.insert(list, "PARTY")
        end
    end
    return list
end

function FT:ShareNode(code, node, inst)
    if not (node and node.name and inst) then return end
    if #Channels() == 0 then return end
    local key = table.concat({ code, inst, math.floor(node.x), math.floor(node.y), node.name }, SEP)
    if lastSent[key] and GetTime() - lastSent[key] < RESEND_COOLDOWN then return end
    lastSent[key] = GetTime()
    local msg = table.concat({
        VERSION, code, tostring(inst),
        string.format("%.1f", node.x), string.format("%.1f", node.y),
        node.kind, node.name,
    }, SEP)
    if #msg <= 250 then table.insert(queue, msg) end
end

-- Envia uma mensagem da fila a cada meio segundo (para não estourar o limite).
C_Timer.NewTicker(0.5, function()
    local msg = table.remove(queue, 1)
    if not msg or not Send then return end
    for _, channel in ipairs(Channels()) do
        if pcall(Send, PREFIX, msg, channel) then
            FT.sharedSent = (FT.sharedSent or 0) + 1
        end
    end
end)

---------------------------------------------------------------------------
-- Recebimento
---------------------------------------------------------------------------
local function IsMe(sender)
    local me = UnitName("player")
    local short = Ambiguate and Ambiguate(sender, "none") or sender:match("^[^-]+")
    return short == me
end

local function Accepts(channel)
    local db = FT.db
    if channel == "GUILD" then return db.shareGuild end
    if channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT" then return db.shareGroup end
    return false
end

FT:RegisterEvent("CHAT_MSG_ADDON", function(self, prefix, text, channel, sender)
    if IsSecret(prefix) or prefix ~= PREFIX then return end
    if IsSecret(text) or IsSecret(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
    if not Accepts(channel) or IsMe(sender) then return end

    local version, code, inst, x, y, kind, name = strsplit(SEP, text)
    if version ~= VERSION or (code ~= "C" and code ~= "G") then return end
    inst, x, y = tonumber(inst), tonumber(x), tonumber(y)
    if not (inst and x and y and name and #name > 0 and #name <= 64) then return end

    self:ApplySharedNode(code, inst, x, y, kind, name)
    self.sharedReceived = (self.sharedReceived or 0) + 1
    if self.db.debug then
        self:Print(string.format(self.L.SHARE_RECEIVED, code, name, Ambiguate and Ambiguate(sender, "short") or sender))
    end
end)

function FT:ShareStatus()
    local ch = Channels()
    return string.format("share: %s | sent=%d received=%d",
        #ch > 0 and table.concat(ch, ",") or "off", self.sharedSent or 0, self.sharedReceived or 0)
end
