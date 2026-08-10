import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isRecording = false
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?
    @State private var eventMonitor: Any?

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Current")
                    Spacer()
                    Text(appState.hotkeySettings.shortcut.displayName)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }

                HStack {
                    Button(isRecording ? "Press a shortcut…" : "Record Shortcut") {
                        beginRecording()
                    }
                    .disabled(isRecording)

                    Button("Use Double Option") {
                        endRecording()
                        appState.applyHotkey(.doubleOption)
                    }
                }

                if isRecording {
                    Text("Press the key combination you want, or Esc to cancel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Permissions") {
                HStack {
                    Label(
                        appState.accessibilityTrusted ? "Accessibility granted" : "Accessibility required",
                        systemImage: appState.accessibilityTrusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(appState.accessibilityTrusted ? .green : .orange)
                    Spacer()
                    Button(appState.accessibilityTrusted ? "Recheck" : "Grant…") {
                        appState.refreshAccessibilityStatus()
                        if !appState.accessibilityTrusted {
                            appState.requestAccessibility()
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        appState.hotkeyMonitor.restart()
                    }
                }

                Text("Global hotkeys (including Double Option) need Accessibility access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Launch at Login", isOn: Binding(
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

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Refresh App Index") {
                    appState.appIndex.refresh()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 360)
        .onAppear {
            appState.refreshAccessibilityStatus()
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
        }
        .onDisappear {
            endRecording()
        }
    }

    private func beginRecording() {
        endRecording()
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                Task { @MainActor in
                    self.endRecording()
                }
                return nil
            }

            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !modifiers.isEmpty else { return event }

            let shortcut = HotkeyShortcut.keyCombo(
                keyCode: event.keyCode,
                modifiers: modifiers.rawValue
            )
            Task { @MainActor in
                self.appState.applyHotkey(shortcut)
                self.endRecording()
            }
            return nil
        }
    }

    private func endRecording() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        isRecording = false
    }
}
