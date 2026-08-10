import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class LauncherController: NSObject, ObservableObject {
    private var panel: KeyablePanel?
    private var appIndex: AppIndex?
    private var viewModel: SearchViewModel?
    private var localMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var sizeCancellable: AnyCancellable?

    @Published var isVisible = false

    private let panelWidth = SearchWindowView.panelWidth
    private let compactHeight = SearchWindowView.compactHeight

    func configure(appIndex: AppIndex) {
        self.appIndex = appIndex
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let appIndex else { return }
        if panel == nil {
            createPanel(appIndex: appIndex)
        }
        resizePanel(resultCount: 0, animate: false)
        positionPanel()
        guard let panel else { return }

        panel.alphaValue = 0
        // Above other floating panels (e.g. Alfred). `.floating` sits under them.
        panel.level = .popUpMenu
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
        NotificationCenter.default.post(name: .launcherDidShow, object: nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel, isVisible, panel.alphaValue > 0.01 else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            NotificationCenter.default.post(name: .launcherDidHide, object: nil)
        })
    }

    private func createPanel(appIndex: AppIndex) {
        let viewModel = SearchViewModel(appIndex: appIndex) { [weak self] in
            self?.hide()
        }
        self.viewModel = viewModel

        sizeCancellable = viewModel.$results
            .receive(on: RunLoop.main)
            .sink { [weak self] results in
                guard let self else { return }
                Task { @MainActor in
                    guard self.isVisible else { return }
                    self.resizePanel(resultCount: results.count, animate: true)
                }
            }

        let root = SearchWindowView(viewModel: viewModel)
        let hostingView = ClearHostingView(rootView: root)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: compactHeight)

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: compactHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Higher than `.floating` so we stack above Alfred / other launchers.
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Rectangular AppKit shadow leaves pale square "ears" at the four
        // corners of a rounded clear panel (obvious on white wallpapers).
        // Soft rounded shadow is drawn in SwiftUI instead.
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.contentView = hostingView
        panel.delegate = self

        self.panel = panel

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleLocalKey(event) ?? event
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }

    private func resizePanel(resultCount: Int, animate: Bool) {
        guard let panel else { return }
        let height = SearchWindowView.contentHeight(resultCount: resultCount)
        let compact = SearchWindowView.compactHeight
        let currentlyExpanded = panel.frame.height > compact + 0.5
        let willExpand = resultCount > 0
        // Animate only compact ↔ first results. While typing (c→co) height may
        // change with result count — do that instantly so the query field
        // doesn't ease/jitter.
        let shouldAnimate = animate && (currentlyExpanded != willExpand)

        guard abs(panel.frame.height - height) > 0.5 else {
            if let hosting = panel.contentView {
                hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: height)
            }
            return
        }

        let frame = panel.frame
        // Keep the top edge fixed so the query field never moves.
        let newFrame = NSRect(
            x: frame.origin.x,
            y: frame.maxY - height,
            width: panelWidth,
            height: height
        )

        if let hosting = panel.contentView {
            hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: height)
        }

        if shouldAnimate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }
    }

    private func handleLocalKey(_ event: NSEvent) -> NSEvent? {
        guard isVisible, let viewModel else { return event }

        // Esc
        if event.keyCode == 53 {
            hide()
            return nil
        }

        // ↑/↓ are handled in SearchWindowView.onKeyPress so the TextField
        // caret does not jump to start/end.

        // ⌘1…⌘9
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           let number = Int(chars),
           (1...9).contains(number) {
            viewModel.selectIndex(number - 1)
            return nil
        }

        return event
    }

    private func positionPanel() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }

        let visible = screen.visibleFrame
        let width = panel.frame.width
        let height = panel.frame.height
        let x = visible.midX - width / 2
        // Compact bar sits higher; when expanded it grows downward from this top.
        let topY = visible.maxY - 140
        let y = topY - height
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// `NSHostingView` fills its bounds opaquely by default, which shows up as
/// black rectangles outside a SwiftUI rounded clip on a clear `NSPanel`.
private final class ClearHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
        setupClearSurface()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupClearSurface()
    }

    override func layout() {
        super.layout()
        setupClearSurface()
    }

    private func setupClearSurface() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        // Walk a couple of ancestors — SwiftUI sometimes inserts opaque wrappers.
        var view: NSView? = self
        for _ in 0..<4 {
            guard let current = view else { break }
            current.wantsLayer = true
            current.layer?.backgroundColor = NSColor.clear.cgColor
            current.layer?.isOpaque = false
            view = current.superview
        }
    }
}

extension LauncherController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

extension Notification.Name {
    static let launcherDidShow = Notification.Name("EggplantFred.launcherDidShow")
    static let launcherDidHide = Notification.Name("EggplantFred.launcherDidHide")
}
