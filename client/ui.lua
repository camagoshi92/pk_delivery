-- Unico punto del lato client che chiama pk_library. Se cambiano gli export si corregge qui.
UI = {}

function UI.Notify(notificationType, message, title)
    exports.pk_library:Notify({
        type = notificationType,
        title = title or Config.Texts.Title,
        message = message,
    })
end

-- data = { npc, name, tag, lines, buttons = { { label, style, onSelect } }, onClose }
function UI.Dialog(data)
    return exports.pk_library:OpenDialog(data)
end

function UI.IsDialogOpen()
    return exports.pk_library:IsDialogOpen()
end

-- Bloccante: restituisce true se completata, false se interrotta con UI.CancelProgress.
function UI.Progress(label, seconds)
    return exports.pk_library:Progress({
        label = label,
        duration = math.floor(seconds * 1000),
    })
end

function UI.CancelProgress()
    return exports.pk_library:CancelProgress()
end
