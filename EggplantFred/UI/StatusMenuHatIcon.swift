import AppKit
import SwiftUI

/// Hat icon that pops the same status menu as the menu bar on right-click.
struct StatusMenuHatIcon: View {
    var body: some View {
        StatusMenuHatIconRepresentable()
            .frame(width: 28, height: 20)
            .help("Right-click for menu")
            .accessibilityLabel("EggplantFred menu")
    }
}

/// Menu-bar glyph — vector PDF template.
/// Spec (Bjango / common practice): working height ≤22pt, optical ~16pt;
/// width follows content. Forcing a wide `.frame` inflates the status item (~50pt).
enum HatTemplateImage {
    static func menuBar() -> NSImage { load(height: 16) }
    static func launcher() -> NSImage { load(height: 16) }

    private static func load(height: CGFloat) -> NSImage {
        if let named = NSImage(named: "HatGlyph") {
            let image = named.copy() as? NSImage ?? named
            let aspect = max(image.size.width / max(image.size.height, 1), 22.0 / 16.0)
            image.size = NSSize(width: (height * aspect).rounded(.toNearestOrAwayFromZero), height: height)
            image.isTemplate = true
            return image
        }
        return fallback(height: height)
    }

    private static func fallback(height: CGFloat) -> NSImage {
        let width = height * (22.0 / 16.0)
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        let inset = NSRect(origin: .zero, size: size)
            .insetBy(dx: width * 0.04, dy: height * 0.06)
        let brim = NSBezierPath(
            ovalIn: NSRect(
                x: inset.minX,
                y: inset.minY + inset.height * 0.08,
                width: inset.width,
                height: inset.height * 0.28
            )
        )
        let crownW = inset.width * 0.48
        let crown = NSBezierPath(
            roundedRect: NSRect(
                x: inset.midX - crownW / 2,
                y: inset.minY + inset.height * 0.22,
                width: crownW,
                height: inset.height * 0.68
            ),
            xRadius: crownW * 0.28,
            yRadius: inset.height * 0.14
        )
        NSColor.black.setFill()
        brim.fill()
        crown.fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
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
        imageView.image = HatTemplateImage.launcher()
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
