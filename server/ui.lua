-- The only server-side place that calls pk_library.
UI = {}

function UI.Notify(src, notificationType, message, title)
    exports.pk_library:Notify(src, {
        type = notificationType,
        title = title or Config.Texts.Title,
        message = message,
    })
end
