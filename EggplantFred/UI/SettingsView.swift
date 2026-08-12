import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsPane()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 560, height: 320)
    }
}

private struct GeneralSettingsPane: View {
    @EnvironmentObject private var appState: AppState
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

    private let labelWidth: CGFloat = 130

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            startupRow
            hotkeyRow
            permissionsRow
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            appState.refreshAccessibilityStatus()
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
            appState.ensureHotkeyMonitorRunning()
        }
        .onDisappear {
            // Safety: never leave the global hotkey permanently paused if the recorder was focused.
            appState.hotkeyMonitor.setPaused(false)
        }
    }

    // MARK: - Rows

    private var startupRow: some View {
        settingsRow(label: "Startup:") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Toggle("Launch EggplantFred at login", isOn: Binding(
                        get: { launchAtLoginEnabled },
                        set: { newValue in
                            do {
                                launchAtLoginEnabled = try LaunchAtLogin.setEnabled(newValue)
                                launchAtLoginError = nil
                            } catch {
                                launchAtLoginError = error.localizedDescription
                                launchAtLoginEnabled = LaunchAtLogin.isEnabled
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)

                    Button("Quit EggplantFred") {
                        NSApplication.shared.terminate(nil)
                    }
                }

                Text("If selected, EggplantFred will still launch at login after using the “Quit EggplantFred” button.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var hotkeyRow: some View {
        settingsRow(label: "Hotkey:") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    HotkeyRecorderRepresentable(
                        shortcut: appState.hotkeySettings.shortcut,
                        onShortcutChange: { appState.applyHotkey($0) }
                    )
                    .frame(height: 36)

                    Button {
                        appState.applyHotkey(.doubleOption)
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reset to ⌥ double tap")
                }

                Text("Click the field, then double-tap ⌃ / ⌥ / ⇧ / ⌘ or type a shortcut — changes apply immediately while focused. Esc or click away to finish.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var permissionsRow: some View {
        settingsRow(label: "Permissions:") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Button("Request Permissions...") {
                        appState.requestAccessibility()
                        appState.openAccessibilitySettings()
                    }

                    if appState.accessibilityTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.green)
                    } else {
                        Label("Required", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                }

                Text("EggplantFred requires Accessibility permission to listen for global hotkeys such as ⌥ double tap.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .frame(width: labelWidth, alignment: .trailing)
                .padding(.top, 4)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - AppKit hotkey recorder

private struct HotkeyRecorderRepresentable: NSViewRepresentable {
    let shortcut: HotkeyShortcut
    let onShortcutChange: (HotkeyShortcut) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderView {
        let view = HotkeyRecorderView()
        view.shortcut = shortcut
        view.onShortcutChange = onShortcutChange
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderView, context: Context) {
        nsView.shortcut = shortcut
        nsView.onShortcutChange = onShortcutChange
        nsView.refreshDisplay()
    }
}

final class HotkeyRecorderView: NSView {
    var shortcut: HotkeyShortcut = .doubleOption
    var onShortcutChange: ((HotkeyShortcut) -> Void)?

    private var isRecording = false
    private var lastTapModifier: ModifierKind?
    private var lastTapTime: CFAbsoluteTime = 0
    private var downModifiers: Set<ModifierKind> = []

    private let accent = NSColor(red: 0.45, green: 0.22, blue: 0.72, alpha: 1)
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        refreshDisplay()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        beginRecording()
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { beginRecording() }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        endRecording(cancelOnly: true)
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 { // Esc
            endRecording(cancelOnly: true)
            window?.makeFirstResponder(nil)
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else { return }

        commit(.keyCombo(keyCode: event.keyCode, modifiers: modifiers.rawValue))
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }

        let keyCode = Int64(event.keyCode)
        guard let kind = ModifierKind.from(keyCode: keyCode) else { return }

        let isDown = event.modifierFlags.contains(kind.nsFlag)
        let othersDown = ModifierKind.allCases
            .filter { $0 != kind }
            .contains { event.modifierFlags.contains($0.nsFlag) }

        if othersDown {
            lastTapModifier = nil
            lastTapTime = 0
            downModifiers = Set(ModifierKind.allCases.filter { event.modifierFlags.contains($0.nsFlag) })
            return
        }

        if isDown {
            guard !downModifiers.contains(kind) else { return }
            downModifiers.insert(kind)

            let now = CFAbsoluteTimeGetCurrent()
            if lastTapModifier == kind, now - lastTapTime <= 0.4 {
                lastTapModifier = nil
                lastTapTime = 0
                let next = HotkeyShortcut.doubleTap(modifier: kind)
                // Same as the already-saved binding → let the global monitor open the launcher.
                if next == shortcut {
                    resetTapState()
                    return
                }
                commit(next)
            } else {
                lastTapModifier = kind
                lastTapTime = now
            }
        } else {
            downModifiers.remove(kind)
        }
    }

    func refreshDisplay() {
        // Focused: accent border; always show the current shortcut (ready for the next input).
        layer?.borderColor = isRecording ? accent.cgColor : NSColor.separatorColor.cgColor

        switch shortcut {
        case .doubleTap(let modifier):
            label.attributedStringValue = alfredStyleString(
                activeModifiers: [modifier],
                suffix: "double tap",
                suffixColor: accent
            )
        case .keyCombo(_, let modifierRaw):
            let flags: NSEvent.ModifierFlags = .init(rawValue: modifierRaw)
            var active: [ModifierKind] = []
            if flags.contains(.control) { active.append(.control) }
            if flags.contains(.option) { active.append(.option) }
            if flags.contains(.shift) { active.append(.shift) }
            if flags.contains(.command) { active.append(.command) }
            label.attributedStringValue = alfredStyleString(
                activeModifiers: active,
                suffix: shortcut.comboKeyLabel ?? "",
                suffixColor: accent
            )
        }
    }

    /// Alfred-style: always show ⌃⌥⇧⌘; only the live combo (+ key / “double tap”) is purple.
    private func alfredStyleString(
        activeModifiers: [ModifierKind],
        suffix: String,
        suffixColor: NSColor
    ) -> NSAttributedString {
        let inactive = NSColor.secondaryLabelColor.withAlphaComponent(0.45)
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let result = NSMutableAttributedString()
        let order: [ModifierKind] = [.control, .option, .shift, .command]

        for (index, kind) in order.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: " ", attributes: [.font: font]))
            }
            let on = activeModifiers.contains(kind)
            result.append(NSAttributedString(
                string: kind.symbol,
                attributes: [
                    .font: font,
                    .foregroundColor: on ? accent : inactive,
                ]
            ))
        }

        if !suffix.isEmpty {
            result.append(NSAttributedString(string: " ", attributes: [.font: font]))
            result.append(NSAttributedString(
                string: suffix,
                attributes: [
                    .font: font,
                    .foregroundColor: suffixColor,
                ]
            ))
        }
        return result
    }

    private func beginRecording() {
        guard !isRecording else {
            refreshDisplay()
            return
        }
        isRecording = true
        resetTapState()
        refreshDisplay()
    }

    private func endRecording(cancelOnly: Bool) {
        guard isRecording else { return }
        isRecording = false
        resetTapState()
        AppState.shared.hotkeyMonitor.setPaused(false)
        if cancelOnly {
            refreshDisplay()
        }
    }

    /// Apply immediately; stay focused for the next gesture. Global hotkey stays live so
    /// re-triggering the current binding (e.g. ⌘ double tap) opens the launcher.
    private func commit(_ shortcut: HotkeyShortcut) {
        self.shortcut = shortcut
        resetTapState()
        refreshDisplay()
        onShortcutChange?(shortcut)
    }

    private func resetTapState() {
        lastTapModifier = nil
        lastTapTime = 0
        downModifiers = []
    }
}
