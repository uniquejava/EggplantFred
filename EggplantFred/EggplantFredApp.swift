import AppKit
import SwiftUI

extension Notification.Name {
    static let openAppPreferences = Notification.Name("EggplantFred.openAppPreferences")
}

@main
struct EggplantFredApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Vector PDF template (~16pt tall). Width follows content — do not force
        // a wide frame (that was making the status item ~50pt with big gaps).
        MenuBarExtra {
            AppStatusMenuContent()
        } label: {
            Image(nsImage: HatTemplateImage.menuBar())
                .renderingMode(.template)
                .background(PreferencesEnvironmentBridge())
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .onAppear {
                    // Bring Preferences above other apps; show briefly in Dock while open.
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onDisappear {
                    NSApp.setActivationPolicy(.accessory)
                }
        }
    }
}

/// Bridges AppKit status menus → SwiftUI `openSettings` (required; `showSettingsWindow:` is rejected).
private struct PreferencesEnvironmentBridge: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                OpenSettingsGateway.shared.open = { [openSettings] in
                    openSettings()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openAppPreferences)) { _ in
                OpenSettingsGateway.shared.open?()
                NSApp.activate(ignoringOtherApps: true)
                NSApp.setActivationPolicy(.regular)
            }
    }
}

@MainActor
enum OpenSettingsGateway {
    static let shared = Gateway()
    final class Gateway {
        var open: (() -> Void)?
    }
}

/// Shared by menu bar and the launcher hat icon (Alfred-style).
struct AppStatusMenuContent: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        Button("Toggle EggplantFred") {
            appState.launcher.toggle()
        }

        Button(AppStatusMenuLabels.versionLine) {}
            .disabled(true)

        Divider()

        SettingsLink {
            Text("Preferences...")
        }
        .keyboardShortcut(",", modifiers: [.command])
        .simultaneousGesture(TapGesture().onEnded {
            // Menu bar (LSUIElement) apps need an explicit activate so Settings comes forward.
            NSApp.activate(ignoringOtherApps: true)
        })

        Divider()

        Button("Quit") {
            appState.quit()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppState.shared.start()

        // Finder / Applications open → show search. Login Items → stay quiet (hotkey only).
        if !LaunchAtLogin.wasLaunchedAtLogin {
            DispatchQueue.main.async {
                AppState.shared.launcher.show()
            }
        }
    }

    /// App already running: double-click in Finder / Applications again.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppState.shared.launcher.show()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppState.shared.ensureHotkeyMonitorRunning()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.stop()
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let launcher = LauncherController()
    let appIndex = AppIndex()
    let hotkeyMonitor = HotkeyMonitor()
    let hotkeySettings = HotkeySettings()

    @Published var accessibilityTrusted = false

    private var accessibilityPollTimer: Timer?

    private init() {}

    func start() {
        refreshAccessibilityStatus()
        appIndex.refresh()
        hotkeyMonitor.onTrigger = { [weak self] in
            self?.launcher.toggle()
        }
        hotkeyMonitor.updateShortcut(hotkeySettings.shortcut)
        hotkeyMonitor.start()
        launcher.configure(appIndex: appIndex)
        startAccessibilityPollingIfNeeded()

        if !accessibilityTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.promptAccessibilityIfNeeded()
            }
        }
    }

    private func promptAccessibilityIfNeeded() {
        refreshAccessibilityStatus()
        guard !accessibilityTrusted else { return }

        let alert = NSAlert()
        alert.messageText = "Accessibility Access Needed"
        alert.informativeText = """
        EggplantFred needs Accessibility to listen for ⌥ double tap.

        If EggplantFred is already checked in System Settings but hotkeys still fail:
        1. Quit EggplantFred
        2. Run in Terminal: tccutil reset Accessibility click.yinsb.EggplantFred
        3. Reopen the app and enable it again when prompted

        (Ad-hoc rebuilds used to invalidate permission even when the checkbox stayed on. The project now uses your Apple Development certificate so this should stop happening.)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Copy Reset Command")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            requestAccessibility()
            openAccessibilitySettings()
        } else if response == .alertSecondButtonReturn {
            let cmd = "tccutil reset Accessibility click.yinsb.EggplantFred"
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cmd, forType: .string)
            openAccessibilitySettings()
        }
    }

    func stop() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
        hotkeyMonitor.stop()
    }

    func refreshAccessibilityStatus() {
        accessibilityTrusted = AXIsProcessTrusted()
    }

    /// After the user grants Accessibility in System Settings, rebuild the event tap.
    func ensureHotkeyMonitorRunning() {
        let wasTrusted = accessibilityTrusted
        refreshAccessibilityStatus()
        if accessibilityTrusted {
            accessibilityPollTimer?.invalidate()
            accessibilityPollTimer = nil
            if !wasTrusted || !hotkeyMonitor.isRunning {
                hotkeyMonitor.restart()
            }
        } else {
            startAccessibilityPollingIfNeeded()
        }
    }

    private func startAccessibilityPollingIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        guard accessibilityPollTimer == nil else { return }
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.ensureHotkeyMonitorRunning()
            }
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        ensureHotkeyMonitorRunning()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func applyHotkey(_ shortcut: HotkeyShortcut) {
        hotkeySettings.shortcut = shortcut
        hotkeyMonitor.updateShortcut(shortcut)
        hotkeyMonitor.setPaused(false)
        if !hotkeyMonitor.isRunning {
            ensureHotkeyMonitorRunning()
        }
        objectWillChange.send()
    }

    func openPreferences() {
        // Must go through SwiftUI `openSettings` / SettingsLink — AppKit
        // `showSettingsWindow:` logs "Please use SettingsLink" and does nothing.
        if let open = OpenSettingsGateway.shared.open {
            open()
            NSApp.activate(ignoringOtherApps: true)
            NSApp.setActivationPolicy(.regular)
        } else {
            NotificationCenter.default.post(name: .openAppPreferences, object: nil)
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
