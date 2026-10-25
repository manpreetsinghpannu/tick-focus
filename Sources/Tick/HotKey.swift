import Carbon

/// System-wide ⌥⌘P via Carbon's RegisterEventHotKey, which needs no Accessibility permission.
final class HotKey {
    private static var handler: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(action: @escaping () -> Void) {
        HotKey.handler = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.handler?() }
            return noErr
        }, 1, &spec, nil, &eventHandlerRef)

        let id = EventHotKeyID(signature: OSType(0x5449_434B), id: 1) // "TICK"
        RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(cmdKey | optionKey), id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
