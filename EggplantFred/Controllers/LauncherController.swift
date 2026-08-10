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
    private let expandedHeight = SearchWindowView.expandedHeight

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
        resizePanel(hasResults: false, animate: false)
        positionPanel()
        guard let panel else { return }

        panel.alphaValue = 0
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
                guard let self, self.isVisible else { return }
                self.resizePanel(hasResults: !results.isEmpty, animate: true)
            }

        let root = SearchWindowView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: root)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: compactHeight)

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: compactHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
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

    private func resizePanel(hasResults: Bool, animate: Bool) {
        guard let panel else { return }
        let height = hasResults ? expandedHeight : compactHeight
        guard abs(panel.frame.height - height) > 0.5 else {
            if let hosting = panel.contentView {
                hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: height)
            }
            return
        }

        let frame = panel.frame
        // Keep the top edge fixed so the list grows downward (Alfred-like).
        let newFrame = NSRect(
            x: frame.origin.x,
            y: frame.maxY - height,
            width: panelWidth,
            height: height
        )

        if let hosting = panel.contentView {
            hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: height)
        }

        if animate {
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

        // Up / Down
        if event.keyCode == 126 {
            viewModel.moveSelection(by: -1)
            return nil
        }
        if event.keyCode == 125 {
            viewModel.moveSelection(by: 1)
            return nil
        }

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

extension LauncherController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

extension Notification.Name {
    static let launcherDidShow = Notification.Name("EggplantFred.launcherDidShow")
    static let launcherDidHide = Notification.Name("EggplantFred.launcherDidHide")
}
