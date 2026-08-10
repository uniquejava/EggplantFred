import AppKit
import SwiftUI

@main
struct EggplantFredApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Template SF Symbol → monochrome like other menu bar icons (emoji stays colorful).
        MenuBarExtra("EggplantFred", systemImage: "hat.widebrim.fill") {
            AppStatusMenuContent()
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

/// Shared by menu bar and the launcher hat icon (Alfred-style).
struct AppStatusMenuContent: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        Button("Open Launcher") {
            appState.launcher.toggle()
        }
        .keyboardShortcut("l", modifiers: [.command])

        Divider()

        Button("Preferences...") {
            appState.openPreferences()
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button("Quit EggplantFred") {
            appState.quit()
        }
        .keyboardShortcut("q", modifiers: [.command])
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppState.shared.start()
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
        2. Run in Terminal: tccutil reset Accessibility com.eggplantfred.EggplantFred
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
            let cmd = "tccutil reset Accessibility com.eggplantfred.EggplantFred"
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
        NSApp.activate(ignoringOtherApps: true)
        // SwiftUI `Settings` scene (macOS 13+); fall back for older selectors.
        let settingsSelector = Selector(("showSettingsWindow:"))
        let prefsSelector = Selector(("showPreferencesWindow:"))
        if NSApp.responds(to: settingsSelector) {
            NSApp.sendAction(settingsSelector, to: nil, from: nil)
        } else {
            NSApp.sendAction(prefsSelector, to: nil, from: nil)
        }
        NSApp.setActivationPolicy(.regular)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
