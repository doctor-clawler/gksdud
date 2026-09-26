import AppKit

// Session events may arrive without a HID keyboard (for example over NoMachine).
// This is explicitly enabled by the user; it does not infer a remote origin.
struct RemoteTrigger {
    let name: String
    let code: Int64
    let modifier: CGEventFlags
    let sideMask: UInt64
}
let remoteTriggers = [
    RemoteTrigger(name: "우측 Option ⌥ (Alt)", code: 61, modifier: .maskAlternate, sideMask: 0x40),
    RemoteTrigger(name: "우측 Command ⌘", code: 54, modifier: .maskCommand, sideMask: 0x10),
    RemoteTrigger(name: "우측 Control ⌃", code: 62, modifier: .maskControl, sideMask: 0x2000)
] + targets.map { RemoteTrigger(name: $0.name, code: Int64($0.keyCode), modifier: [], sideMask: 0) }

struct RemoteKeyGate {
    private(set) var held = false
    // nil passes through; true/false maps a down/up to the internal F-key.
    mutating func transition(type: CGEventType, code: Int64, flags: CGEventFlags, repeated: Bool,
                             trigger: RemoteTrigger) -> Bool? {
        guard code == trigger.code else { return nil }
        let down: Bool
        if type == .flagsChanged && trigger.sideMask != 0 {
            if flags.rawValue & trigger.sideMask != 0 { down = true }
            else if !flags.contains(trigger.modifier) { down = false }
            else {
                // Some remote clients omit side-specific flags. A flagsChanged
                // event for this exact key toggles it even if the left key is held.
                down = !held
            }
        } else if type == .keyDown || type == .keyUp { down = type == .keyDown }
        else { return nil }
        if down {
            guard !held, !repeated else { return nil }
            // Preserve shortcuts using another modifier; this option owns a bare key.
            let other = flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).subtracting(trigger.modifier)
            guard other.isEmpty else { return nil }
            held = true
        } else {
            guard held else { return nil }
            held = false
        }
        return down
    }
    mutating func reset() { held = false }
}

extension Engine {
    var remoteEnabled: Bool { defaults.bool(forKey: "remoteInputEnabled") }
    var remoteTrigger: RemoteTrigger {
        remoteTriggers.first { $0.code == (defaults.object(forKey: "remoteInputCode") as? NSNumber)?.int64Value } ?? remoteTriggers[0]
    }
}

extension AppDelegate {
    func releaseRemoteKey() {
        if let target = remoteHeldTarget, let up = CGEvent(keyboardEventSource: nil, virtualKey: target, keyDown: false) {
            up.flags = []; up.setIntegerValueField(.eventSourceUserData, value: remoteMarker)
            up.post(tap: .cghidEventTap)
        }
        remoteHeldTarget = nil; remoteGate.reset()
    }
    func handleRemoteInput(_ event: CGEvent) -> Bool {
        let marker = event.getIntegerValueField(.eventSourceUserData)
        guard marker != remoteMarker, marker != nativePulseMarker else { return false }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if remoteWindow?.isVisible == true, Date() < remoteProbeUntil,
           event.type == .keyDown || event.type == .keyUp || event.type == .flagsChanged {
            // Only key identity, never characters; transient UI only, no persistent log.
            remoteLastEvent = "수신: 코드 \(code), 종류 \(event.type.rawValue), flags 0x\(String(event.flags.rawValue, radix: 16))"
        }
        guard engine.active, engine.remoteEnabled else { return false }
        let trigger = engine.remoteTrigger
        let wasHeld = remoteGate.held
        guard let down = remoteGate.transition(type: event.type, code: code, flags: event.flags,
                                              repeated: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                                              trigger: trigger) else {
            // Suppress repeats of an owned key without losing the eventual release.
            return wasHeld && code == trigger.code && (event.type == .keyDown || event.type == .flagsChanged)
        }
        let target = down ? CGKeyCode(engine.target.keyCode) : (remoteHeldTarget ?? CGKeyCode(engine.target.keyCode))
        guard let mapped = CGEvent(keyboardEventSource: nil, virtualKey: target, keyDown: down) else {
            remoteGate.reset(); remoteHeldTarget = nil; return false
        }
        mapped.flags = []; mapped.setIntegerValueField(.eventSourceUserData, value: remoteMarker)
        remoteHeldTarget = down ? target : nil
        // Re-enter before native shortcut handling. The marker prevents a loop
        // even if the selected remote key equals the internal F-key.
        mapped.post(tap: .cghidEventTap)
        if down { remoteReceived += 1 }
        return true
    }
    @objc func showRemoteSettings() {
        if remoteWindow == nil { buildRemoteWindow() }
        refreshRemoteStatus()
        remoteWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func remoteSelectionChanged() {
        releaseRemoteKey(); cancelLongPress()
        engine.defaults.set(remoteSwitch.state == .on, forKey: "remoteInputEnabled")
        engine.defaults.set(remoteTriggers[remotePicker.indexOfSelectedItem].code, forKey: "remoteInputCode")
        ensureKeyTap(); refreshRemoteStatus(); refreshStatus()
    }
    @objc func probeRemoteInput() {
        remoteProbeUntil = Date().addingTimeInterval(15)
        remoteLastEvent = "15초 동안 전환 키를 눌러보세요. 문자는 기록하지 않습니다."
        ensureKeyTap(); refreshRemoteStatus()
    }
    @objc func openRemoteGuide() {
        NSWorkspace.shared.open(URL(string: "https://github.com/doctor-clawler/gksdud/blob/main/docs/nomachine-windows.md")!)
    }
    func refreshRemoteStatus() {
        remoteSwitch.state = engine.remoteEnabled ? .on : .off
        remotePicker.selectItem(at: remoteTriggers.firstIndex { $0.code == engine.remoteTrigger.code } ?? 0)
        let ready = keyTap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
        remoteState.stringValue = !AXIsProcessTrusted() ? "접근성 권한이 필요합니다. 일반 설정에서 허용하세요."
            : !engine.active ? "일반 설정의 활성화를 켜세요."
            : !engine.remoteEnabled ? "이벤트 기반 전환이 꺼져 있습니다."
            : !ready ? "키 이벤트 처리를 시작하지 못했습니다."
            : "이벤트 처리 중 · 전환 키 수신 \(remoteReceived)회"
        remoteDiagnostic.stringValue = remoteLastEvent + (Date() >= remoteProbeUntil && !remoteLastEvent.isEmpty ? "\n확인 종료 — 다시 확인하려면 버튼을 누르세요." : "")
    }
    func buildRemoteWindow() {
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 390), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "원격 입력 · gksdud"; panel.isReleasedWhenClosed = false; panel.center()
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false; panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: panel.contentView!.bottomAnchor, constant: -24)
        ])
        func label(_ text: String) -> NSTextField {
            let field = NSTextField(wrappingLabelWithString: text); field.font = .systemFont(ofSize: 12)
            stack.addArrangedSubview(field); field.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            return field
        }
        _ = label("NoMachine처럼 HID 키보드 없이 전달되는 키를 처리합니다.\n선택한 키는 로컬 키보드에서도 전환 키로 동작합니다.")
        remoteSwitch.target = self; remoteSwitch.action = #selector(remoteSelectionChanged)
        stack.addArrangedSubview(remoteSwitch)
        remotePicker.addItems(withTitles: remoteTriggers.map(\.name)); remotePicker.target = self
        remotePicker.action = #selector(remoteSelectionChanged); remotePicker.setAccessibilityLabel("원격 전환 키")
        stack.addArrangedSubview(NSStackView(views: [NSTextField(labelWithString: "전달받을 키"), remotePicker]))
        _ = label("Windows 한영키 → 우측 Alt로 보낸다면 우측 Option을 선택하세요.\n추가 보조키 없이 누르면 내부 전환 키로 전달합니다.")
        remoteState.font = .systemFont(ofSize: 12); stack.addArrangedSubview(remoteState)
        remoteState.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let probe = NSButton(title: "키 수신 확인 (15초)", target: self, action: #selector(probeRemoteInput)); probe.bezelStyle = .rounded
        let guide = NSButton(title: "Windows 설정 가이드", target: self, action: #selector(openRemoteGuide)); guide.bezelStyle = .rounded
        stack.addArrangedSubview(NSStackView(views: [probe, guide]))
        remoteDiagnostic.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        stack.addArrangedSubview(remoteDiagnostic); remoteDiagnostic.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        remoteWindow = panel
    }
}
