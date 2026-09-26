import AppKit

func runRemoteInputTests() {
    let option = remoteTriggers[0]
    func step(_ gate: inout RemoteKeyGate, _ type: CGEventType, _ code: Int64 = 61,
              _ flags: CGEventFlags = [], _ repeated: Bool = false, _ trigger: RemoteTrigger? = nil) -> Bool? {
        gate.transition(type: type, code: code, flags: flags, repeated: repeated, trigger: trigger ?? option)
    }
    var gate = RemoteKeyGate()
    featureCheck(step(&gate, .flagsChanged, 58, .maskAlternate) == nil, "Left Option is preserved")
    featureCheck(step(&gate, .flagsChanged, 61, CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x40)) == true)
    featureCheck(step(&gate, .keyDown, 61, .maskAlternate, true) == nil && gate.held, "Repeat must not switch again")
    featureCheck(step(&gate, .flagsChanged, 61, []) == false && !gate.held)
    featureCheck(step(&gate, .flagsChanged, 61, []) == nil, "Unowned release passes through")
    featureCheck(step(&gate, .flagsChanged, 61, [.maskAlternate, .maskCommand]) == nil && !gate.held, "Other shortcuts are preserved")
    featureCheck(step(&gate, .flagsChanged, 61, .maskAlternate) == true)
    featureCheck(step(&gate, .flagsChanged, 61, .maskAlternate) == false, "Missing side flags with left modifier still held")
    for trigger in remoteTriggers {
        gate.reset()
        featureCheck(step(&gate, .keyDown, trigger.code, [], false, trigger) == true)
        featureCheck(step(&gate, .keyDown, trigger.code, [], true, trigger) == nil)
        featureCheck(step(&gate, .keyUp, trigger.code, [], false, trigger) == false)
        featureCheck(step(&gate, .keyDown, trigger.code, .maskShift, false, trigger) == nil)
    }
    for trigger in remoteTriggers.prefix(3) {
        gate.reset()
        featureCheck(step(&gate, .flagsChanged, trigger.code, CGEventFlags(rawValue: trigger.modifier.rawValue | trigger.sideMask), false, trigger) == true)
        featureCheck(step(&gate, .flagsChanged, trigger.code, [], false, trigger) == false)
    }
    let suite = "io.gksdud.remote-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var shortcuts: [String: Any] = [:]
    let engine = Engine(defaults: defaults, discover: { [] }, shortcutPreferences: .init(read: { shortcuts }, write: { shortcuts = $0 }, activate: {}))
    featureCheck(!engine.remoteEnabled && engine.remoteTrigger.code == 61, "Default off, right Option preselected")
    defaults.set(true, forKey: "remoteInputEnabled"); defaults.set(54, forKey: "remoteInputCode")
    featureCheck(engine.remoteEnabled && engine.remoteTrigger.code == 54)
    defaults.set(999, forKey: "remoteInputCode"); featureCheck(engine.remoteTrigger.code == 61, "Invalid preference falls back safely")
    try! engine.shortcut(target: targets[6])
    featureCheck(try! engine.reconcile() == 0, "No physical keyboard is required for the reserved shortcut")
    featureCheck(Engine.ownsShortcut(shortcuts["60"], keyCode: 80))
    print("PASS: remote modifiers and F13-F20, repeat/release ownership, shortcut preservation, no-HID preferences and shortcut")
}
