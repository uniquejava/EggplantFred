import AppKit
import SwiftUI

/// Hat icon that pops the same status menu as the menu bar on right-click.
struct StatusMenuHatIcon: View {
    var body: some View {
        StatusMenuHatIconRepresentable()
            .frame(width: 28, height: 28)
            .help("Right-click for menu")
            .accessibilityLabel("EggplantFred menu")
    }
}

private struct StatusMenuHatIconRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> StatusMenuHatNSView {
        StatusMenuHatNSView()
    }

    func updateNSView(_ nsView: StatusMenuHatNSView, context: Context) {}
}

private final class StatusMenuHatNSView: NSView {
    private let imageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = Self.hatImage()
        imageView.contentTintColor = .secondaryLabelColor
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = AppStatusNSMenu.make()
        AppState.shared.launcher.beginExternalMenuPresentation()
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: bounds.midX, y: 0),
            in: self
        )
        AppState.shared.launcher.endExternalMenuPresentation()
    }

    private static func hatImage() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = NSImage(systemSymbolName: "hat.widebrim.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
            ?? NSImage()
        image.isTemplate = true
        return image
    }
}

enum AppStatusNSMenu {
    @MainActor
    static func make() -> NSMenu {
        let menu = NSMenu()

        let open = NSMenuItem(
            title: "Open Launcher",
            action: #selector(AppStatusMenuTarget.openLauncher(_:)),
            keyEquivalent: "l"
        )
        open.keyEquivalentModifierMask = [.command]
        open.target = AppStatusMenuTarget.shared

        let prefs = NSMenuItem(
            title: "Preferences...",
            action: #selector(AppStatusMenuTarget.openPreferences(_:)),
            keyEquivalent: ","
        )
        prefs.keyEquivalentModifierMask = [.command]
        prefs.target = AppStatusMenuTarget.shared

        let quit = NSMenuItem(
            title: "Quit EggplantFred",
            action: #selector(AppStatusMenuTarget.quit(_:)),
            keyEquivalent: "q"
        )
        quit.keyEquivalentModifierMask = [.command]
        quit.target = AppStatusMenuTarget.shared

        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(prefs)
        menu.addItem(.separator())
        menu.addItem(quit)
        return menu
    }
}

@MainActor
private final class AppStatusMenuTarget: NSObject {
    static let shared = AppStatusMenuTarget()

    @objc func openLauncher(_ sender: Any?) {
        AppState.shared.launcher.toggle()
    }

    @objc func openPreferences(_ sender: Any?) {
        AppState.shared.openPreferences()
    }

    @objc func quit(_ sender: Any?) {
        AppState.shared.quit()
    }
}
