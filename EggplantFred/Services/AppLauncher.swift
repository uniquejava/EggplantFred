import AppKit
import Foundation

enum AppLauncher {
    @discardableResult
    static func open(_ app: AppEntry) -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { _, error in
            if let error {
                NSLog("Failed to open \(app.path): \(error.localizedDescription)")
            }
        }
        return true
    }
}
