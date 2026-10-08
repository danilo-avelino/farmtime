-- Farm Time - Tecla de coleta
--
-- Liga uma tecla (padrão F) ao comando "Interagir com o alvo"
-- (INTERACTTARGET), que interage com o objeto escolhido pelo jogo — a erva
-- ou o minério destacado. A tecla que estava antes é guardada para poder ser
-- devolvida. Atalhos não podem ser trocados em combate, então nesse caso a
-- troca espera o fim do combate.

local _, FT = ...

local ACTION = "INTERACTTARGET"
local pending = false

local function SaveCurrentBindings()
    if SaveBindings and GetCurrentBindingSet then
        SaveBindings(GetCurrentBindingSet())
    end
end

function FT:ApplyKeybind()
    local db = self.db
    if not db.bindInteractKey then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false

    local key = db.interactKey
    local current = GetBindingAction(key)
    if current == ACTION then return end

    -- Guarda o que a tecla fazia antes (só na primeira vez).
    if db.savedBinding.key ~= key then
        db.savedBinding.key = key
        db.savedBinding.action = current or ""
    end

    if SetBinding(key, ACTION) then
        SaveCurrentBindings()
        if current and current ~= "" then
            self:Print(string.format(self.L.KEY_BOUND_PREV, key, _G["BINDING_NAME_" .. current] or current))
        else
            self:Print(string.format(self.L.KEY_BOUND, key))
        end
    else
        self:Print(string.format(self.L.KEY_FAIL, key))
    end
end

function FT:RestoreKeybind()
    if InCombatLockdown() then
        self:Print(self.L.KEY_COMBAT)
        return
    end
    local saved = self.db.savedBinding
    if not saved.key then return end
    if GetBindingAction(saved.key) == ACTION then
        if saved.action and saved.action ~= "" then
            SetBinding(saved.key, saved.action)
        else
            SetBinding(saved.key)
        end
        SaveCurrentBindings()
    end
    self:Print(string.format(self.L.KEY_RESTORED, saved.key))
    saved.key, saved.action = nil, nil
end

FT:RegisterEvent("PLAYER_LOGIN", function(self)
    self:ApplyKeybind()
end)

FT:RegisterEvent("PLAYER_REGEN_ENABLED", function(self)
    if pending then self:ApplyKeybind() end
end)
