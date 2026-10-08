-- Farm Time - Idiomas / Languages
--
-- Todo texto que o jogador vê passa por FT.L[chave]. O idioma vem de
-- FT.db.language ("enUS" padrão, ou "ptBR"); chave que faltar num idioma
-- cai no inglês. Textos fixos da interface são registrados com FT:T() para
-- serem trocados na hora quando o idioma muda.

local _, FT = ...

FT.LANGUAGES = {
    { code = "enUS", label = "English" },
    { code = "ptBR", label = "Português (BR)" },
}

FT.Locales = {}

FT.Locales.enUS = {
    -- Chat
    LOADED          = "loaded. Click the minimap icon or type /ft help.",
    MISSING_EVENTS  = "events that don't exist in this client: %s",
    EVENT_ERROR     = "error in %s: %s",
    CMD_ERROR       = "error in command '%s': %s",
    ON              = "on",
    OFF             = "off",
    ENABLED         = "enabled",
    DISABLED        = "disabled",
    USAGE_RANGE     = "usage: %d-%d (current: %s)",
    OPT_HIGHLIGHT   = "highlight",
    OPT_ICON_SIZE   = "icon size",
    OPT_RANGE       = "range (the game may cap it)",
    OPT_KEY         = "%s key to gather",
    OPT_SOUND       = "sound",
    OPT_FASTLOOT    = "fast loot",
    OPT_DEBUG       = "debug",
    OPT_MATS        = "trade goods in session",
    OPT_HUD         = "saved node markers",
    OPT_PROMPT      = "\"press F\" prompt",
    OPT_FOV         = "field of view used by the markers",
    OPT_PITCH       = "camera angle used by the markers",
    CALIBRATE_HELP  = "calibration point saved where you are standing (red square). Walk 20-30 yards away, look at the spot and adjust \"Camera angle\" in the panel (or /ft pitch <degrees>) until the red square sits on the ground where you were.",
    CALIBRATE_NO_POS = "your position isn't available here.",
    NODE_SAVED      = "node saved: %s",
    NODES_COUNT     = "%d saved nodes (%d on this continent)",
    NODES_CLEARED   = "saved nodes on this continent cleared (/ft clearnodes all clears everything)",
    NODES_CLEARED_ALL = "all saved nodes cleared",
    HUD_DISTANCE    = "%d yd",
    ONLY_GATHER_ON  = "highlighting only herbs and ores",
    ONLY_GATHER_OFF = "highlighting any interactable object",
    SESSION_CLEARED = "session reset",
    MINIMAP_HIDDEN  = "minimap button hidden",
    MINIMAP_SHOWN   = "minimap button shown",
    STATUS_CLIENT   = "client",
    STATUS_TARGET   = "interact target",
    STATUS_ERROR    = "error",
    STATUS_MISSING  = "missing events",
    CVAR_MISSING    = "(doesn't exist)",
    CVARS_RESTORED  = "game options restored. Use /ft apply to turn them back on.",
    CVARS_APPLIED   = "game options applied.",
    LANGUAGE_SET    = "language: English",
    DEBUG_TARGET    = "target: %s | %s | %s | exists=%s | plate=%s",
    HELP_TITLE      = "commands:",
    HELP = {
        "/ft               - open/close the settings panel",
        "/ft toggle        - turn the highlight on/off",
        "/ft minimap       - show/hide the minimap button",
        "/ft size <px>     - icon size on the plate",
        "/ft range <yd>    - interact soft target range",
        "/ft all           - toggle: herbs/ores only or any object",
        "/ft key           - turn the F gather key on/off",
        "/ft sound         - turn the sound on/off",
        "/ft loot          - turn fast loot on/off",
        "/ft mats          - track trade goods (meat, cloth...) in the session",
        "/ft session       - show/hide the session window",
        "/ft hud           - turn the saved node markers on/off",
        "/ft prompt        - turn the \"press F to gather\" prompt on/off",
        "/ft fov <deg>     - field of view used by the markers (default 90)",
        "/ft pitch <deg>   - camera angle used by the markers (default 35)",
        "/ft calibrate     - drop a red calibration square to adjust the camera angle",
        "/ft nodes         - how many nodes are saved",
        "/ft clearnodes    - clear saved nodes here (add 'all' for everything)",
        "/ft reset         - reset the session",
        "/ft lang          - switch language (English / Português)",
        "/ft status        - show client version and game options",
        "/ft debug         - print every interact target change",
        "/ft restore       - restore the original soft target options",
        "/ft apply         - re-apply Farm Time's soft target options",
    },

    -- Tecla F / F key
    KEY_BOUND_PREV  = "%s key now gathers (was: %s). Undo it in the settings panel.",
    KEY_BOUND       = "%s key now gathers the highlighted herb/ore.",
    KEY_FAIL        = "could not bind the %s key",
    KEY_COMBAT      = "key bindings can't be changed in combat; try again later.",
    KEY_RESTORED    = "%s key restored to what it did before.",

    -- Placa / Plate
    KIND_herb       = "Herb",
    KIND_ore        = "Ore",
    KIND_other      = "Object",

    -- Painel / Panel
    CFG_ENABLED     = "Enable highlight",
    CFG_ONLY        = "Herbs and ores only",
    CFG_ANCHOR      = "Icon above the node",
    CFG_HIDENAME    = "Hide the game's name on the node",
    CFG_SOUND       = "Sound when a node is found",
    CFG_KEY         = "F key gathers the herb/ore",
    CFG_FASTLOOT    = "Fast loot (Shift skips)",
    CFG_SESSION     = "Session window opens on gather",
    CFG_MATS        = "Session: trade goods too",
    CFG_HUD         = "Saved nodes in view (grey = unconfirmed)",
    CFG_PROMPT      = "\"Press F\" prompt in range",
    PROMPT_herb     = "Gather",
    PROMPT_ore      = "Mine",
    PROMPT_skin     = "Skin",
    CFG_HUD_RANGE   = "Saved node range (yards)",
    CFG_PITCH       = "Camera angle (degrees down)",
    CFG_FOV         = "Field of view (degrees)",
    BTN_CALIBRATE   = "Calibrate",
    CFG_CVARS       = "Game's interact icons",
    CFG_DEBUG       = "Debug in chat",
    CFG_SIZE        = "Icon size",
    CFG_RANGE       = "Range (yards)",
    CFG_MINIMAP     = "Show minimap button",
    CFG_LANGUAGE    = "Language",
    BTN_STATUS      = "Diagnostics",
    BTN_TEST        = "Test alert",
    BTN_SESSION     = "Session",
    TT_CLICK        = "Click: settings",
    TT_RIGHTCLICK   = "Right-click: turn on/off",
    TT_DRAG         = "Drag: move the button",

    -- Sessão / Session
    SESSION_EMPTY   = "Nothing gathered yet.",
    SESSION_TOTAL   = "Total",
    SESSION_NO_AH   = "Auctionator not found: no prices.",
    SESSION_RESET   = "Reset",
    SESSION_RESET_TT  = "Reset the session",
    SESSION_RESET_TT2 = "Clears the list and the timer.",
}

FT.Locales.ptBR = {
    LOADED          = "carregado. Clique no ícone do minimapa ou digite /ft help.",
    MISSING_EVENTS  = "eventos que não existem neste cliente: %s",
    EVENT_ERROR     = "erro em %s: %s",
    CMD_ERROR       = "erro no comando '%s': %s",
    ON              = "ligado",
    OFF             = "desligado",
    ENABLED         = "ativado",
    DISABLED        = "desativado",
    USAGE_RANGE     = "uso: %d-%d (atual: %s)",
    OPT_HIGHLIGHT   = "destaque",
    OPT_ICON_SIZE   = "tamanho do ícone",
    OPT_RANGE       = "alcance (o jogo pode limitar)",
    OPT_KEY         = "tecla %s para coletar",
    OPT_SOUND       = "som",
    OPT_FASTLOOT    = "fast loot",
    OPT_DEBUG       = "debug",
    OPT_MATS        = "materiais de profissão na sessão",
    OPT_HUD         = "marcadores dos nós salvos",
    OPT_PROMPT      = "aviso \"aperte F\"",
    OPT_FOV         = "campo de visão dos marcadores",
    OPT_PITCH       = "ângulo da câmera dos marcadores",
    CALIBRATE_HELP  = "ponto de calibração salvo onde você está (quadrado vermelho). Afaste-se 20-30 jardas, olhe para o local e ajuste \"Ângulo da câmera\" no painel (ou /ft pitch <graus>) até o quadrado vermelho ficar no chão onde você estava.",
    CALIBRATE_NO_POS = "sua posição não está disponível aqui.",
    NODE_SAVED      = "nó salvo: %s",
    NODES_COUNT     = "%d nós salvos (%d neste continente)",
    NODES_CLEARED   = "nós salvos deste continente apagados (/ft clearnodes all apaga tudo)",
    NODES_CLEARED_ALL = "todos os nós salvos apagados",
    HUD_DISTANCE    = "%d jd",
    ONLY_GATHER_ON  = "destacando só ervas e minérios",
    ONLY_GATHER_OFF = "destacando qualquer objeto interagível",
    SESSION_CLEARED = "sessão zerada",
    MINIMAP_HIDDEN  = "botão do minimapa escondido",
    MINIMAP_SHOWN   = "botão do minimapa visível",
    STATUS_CLIENT   = "cliente",
    STATUS_TARGET   = "alvo de interação",
    STATUS_ERROR    = "erro",
    STATUS_MISSING  = "eventos ausentes",
    CVAR_MISSING    = "(não existe)",
    CVARS_RESTORED  = "opções do jogo restauradas. Use /ft apply para religar.",
    CVARS_APPLIED   = "opções do jogo aplicadas.",
    LANGUAGE_SET    = "idioma: Português (BR)",
    DEBUG_TARGET    = "alvo: %s | %s | %s | existe=%s | placa=%s",
    HELP_TITLE      = "comandos:",
    HELP = {
        "/ft               - abre/fecha o painel de configurações",
        "/ft toggle        - liga/desliga o destaque",
        "/ft minimap       - mostra/esconde o botão do minimapa",
        "/ft size <px>     - tamanho do ícone na placa",
        "/ft range <jd>    - alcance do soft target de interação",
        "/ft all           - alterna: só ervas/minérios ou qualquer objeto",
        "/ft key           - liga/desliga a tecla F para coletar",
        "/ft sound         - liga/desliga o som",
        "/ft loot          - liga/desliga o fast loot",
        "/ft mats          - materiais de profissão (carne, pano...) na sessão",
        "/ft session       - mostra/esconde a janela da sessão",
        "/ft hud           - liga/desliga os marcadores dos nós salvos",
        "/ft prompt        - liga/desliga o aviso \"aperte F para coletar\"",
        "/ft fov <graus>   - campo de visão dos marcadores (padrão 90)",
        "/ft pitch <graus> - ângulo da câmera dos marcadores (padrão 35)",
        "/ft calibrate     - coloca um quadrado vermelho para ajustar o ângulo da câmera",
        "/ft nodes         - quantos nós estão salvos",
        "/ft clearnodes    - apaga os nós salvos daqui ('all' apaga tudo)",
        "/ft reset         - zera a sessão",
        "/ft lang          - troca o idioma (English / Português)",
        "/ft status        - mostra versão do cliente e opções do jogo",
        "/ft debug         - imprime cada mudança de alvo de interação",
        "/ft restore       - devolve as opções de soft target originais",
        "/ft apply         - reaplica as opções de soft target do Farm Time",
    },

    KEY_BOUND_PREV  = "tecla %s agora coleta (antes: %s). Desfaça no painel.",
    KEY_BOUND       = "tecla %s agora coleta a erva/minério destacado.",
    KEY_FAIL        = "não foi possível ligar a tecla %s",
    KEY_COMBAT      = "não dá para trocar teclas em combate; tente de novo depois.",
    KEY_RESTORED    = "tecla %s devolvida ao que era antes.",

    KIND_herb       = "Erva",
    KIND_ore        = "Minério",
    KIND_other      = "Objeto",

    CFG_ENABLED     = "Ativar destaque",
    CFG_ONLY        = "Só ervas e minérios",
    CFG_ANCHOR      = "Ícone em cima do nó",
    CFG_HIDENAME    = "Esconder o nome do jogo no nó",
    CFG_SOUND       = "Som ao encontrar um nó",
    CFG_KEY         = "Tecla F coleta a erva/minério",
    CFG_FASTLOOT    = "Fast loot (Shift desativa)",
    CFG_SESSION     = "Janela da sessão abre ao coletar",
    CFG_MATS        = "Sessão: também materiais",
    CFG_HUD         = "Nós salvos na visão (cinza = sem confirmar)",
    CFG_PROMPT      = "Aviso \"aperte F\" no alcance",
    PROMPT_herb     = "Coletar",
    PROMPT_ore      = "Minerar",
    PROMPT_skin     = "Esfolar",
    CFG_HUD_RANGE   = "Alcance dos nós salvos (jardas)",
    CFG_PITCH       = "Ângulo da câmera (graus p/ baixo)",
    CFG_FOV         = "Campo de visão (graus)",
    BTN_CALIBRATE   = "Calibrar",
    CFG_CVARS       = "Ícones de interação do jogo",
    CFG_DEBUG       = "Debug no chat",
    CFG_SIZE        = "Tamanho do ícone",
    CFG_RANGE       = "Alcance (jardas)",
    CFG_MINIMAP     = "Mostrar botão no minimapa",
    CFG_LANGUAGE    = "Idioma",
    BTN_STATUS      = "Diagnóstico",
    BTN_TEST        = "Testar alerta",
    BTN_SESSION     = "Sessão",
    TT_CLICK        = "Clique: configurações",
    TT_RIGHTCLICK   = "Clique direito: liga/desliga",
    TT_DRAG         = "Arraste: mover o botão",

    SESSION_EMPTY   = "Nada coletado ainda.",
    SESSION_TOTAL   = "Total",
    SESSION_NO_AH   = "Auctionator não encontrado: sem preços.",
    SESSION_RESET   = "Reset",
    SESSION_RESET_TT  = "Zerar a sessão",
    SESSION_RESET_TT2 = "Apaga a lista e o timer.",
}

FT.L = setmetatable({}, {
    __index = function(_, key)
        local lang = FT.db and FT.db.language or "enUS"
        local t = FT.Locales[lang]
        return (t and t[key]) or FT.Locales.enUS[key] or key
    end,
})

-- Textos fixos da interface: aplica agora e reaplica quando o idioma muda.
FT.textRegistry = {}

function FT:T(obj, key)
    obj:SetText(self.L[key])
    table.insert(self.textRegistry, { obj = obj, key = key })
end

function FT:ApplyLanguage()
    for _, entry in ipairs(self.textRegistry) do
        entry.obj:SetText(self.L[entry.key])
    end
    if self.RefreshConfig then self:RefreshConfig() end
    if self.RefreshSession then self:RefreshSession() end
    if self.RefreshHighlight then self:RefreshHighlight() end
end
