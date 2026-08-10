import AppKit
import SwiftUI

@main
struct EggplantFredApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra("EggplantFred", systemImage: "magnifyingglass") {
            Button("Open Launcher") {
                appState.launcher.toggle()
            }
            .keyboardShortcut("l", modifiers: [.command])

            Divider()

            Button("Settings…") {
                appState.openSettings()
            }
            .keyboardShortcut(",", modifiers: [.command])

            Divider()

            Button("Quit EggplantFred") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppState.shared.start()
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
        alert.informativeText = "EggplantFred needs Accessibility permission to listen for global hotkeys like Double Option."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            requestAccessibility()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func stop() {
        hotkeyMonitor.stop()
    }

    func refreshAccessibilityStatus() {
        accessibilityTrusted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        hotkeyMonitor.restart()
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    func applyHotkey(_ shortcut: HotkeyShortcut) {
        hotkeySettings.shortcut = shortcut
        hotkeyMonitor.updateShortcut(shortcut)
    }
}
