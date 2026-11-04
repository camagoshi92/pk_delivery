-- The only client-side place that calls pk_library. If the exports change, fix them here.
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

-- Blocking: returns true when completed, false when stopped with UI.CancelProgress.
function UI.Progress(label, seconds)
    return exports.pk_library:Progress({
        label = label,
        duration = math.floor(seconds * 1000),
    })
end

function UI.CancelProgress()
    return exports.pk_library:CancelProgress()
end
