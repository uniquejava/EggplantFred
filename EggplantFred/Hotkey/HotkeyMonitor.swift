import AppKit
import Foundation

final class HotkeyMonitor: @unchecked Sendable {
    var onTrigger: (() -> Void)?

    private var shortcut: HotkeyShortcut = .doubleOption
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    /// Timestamp of the previous matching modifier *down* for double-tap detection.
    private var lastModifierDown: CFAbsoluteTime = 0
    private let doubleTapInterval: CFAbsoluteTime = 0.4
    private var wasModifierDown = false
    private var isPaused = false
    private let lock = NSLock()

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return eventTap != nil
    }

    /// Pause firing (e.g. while Preferences is recording a shortcut).
    func setPaused(_ paused: Bool) {
        lock.lock()
        isPaused = paused
        lastModifierDown = 0
        wasModifierDown = false
        lock.unlock()
    }

    func updateShortcut(_ shortcut: HotkeyShortcut) {
        lock.lock()
        self.shortcut = shortcut
        lastModifierDown = 0
        wasModifierDown = false
        lock.unlock()
    }

    func start() {
        stop()
        guard AXIsProcessTrusted() else {
            NSLog("EggplantFred: event tap skipped — Accessibility not trusted")
            return
        }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: refcon
        ) else {
            NSLog("EggplantFred: failed to create event tap — grant Accessibility permission")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func restart() {
        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        lock.lock()
        let paused = isPaused
        let current = shortcut
        lock.unlock()

        guard !paused else {
            return Unmanaged.passUnretained(event)
        }

        switch current {
        case .doubleTap(let modifier):
            processDoubleTap(event: event, type: type, modifier: modifier)
        case .keyCombo(let keyCode, let modifiers):
            processKeyCombo(event: event, type: type, keyCode: keyCode, modifiers: modifiers)
        }

        return Unmanaged.passUnretained(event)
    }

    /// Successive presses of the same modifier within `doubleTapInterval` (Alfred-style).
    private func processDoubleTap(event: CGEvent, type: CGEventType, modifier: ModifierKind) {
        guard type == .flagsChanged else { return }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let isDownNow = flags.contains(modifier.cgFlag)
        let isTargetKey = modifier.keyCodes.contains(keyCode)

        lock.lock()
        let wasDown = wasModifierDown
        let transitioned = isDownNow != wasDown
        wasModifierDown = isDownNow

        if !isTargetKey && !transitioned {
            lock.unlock()
            return
        }

        if !flags.intersection(modifier.otherCGFlags).isEmpty {
            lastModifierDown = 0
            lock.unlock()
            return
        }

        var shouldFire = false
        if isDownNow && !wasDown {
            let now = CFAbsoluteTimeGetCurrent()
            if lastModifierDown > 0, now - lastModifierDown <= doubleTapInterval {
                lastModifierDown = 0
                shouldFire = true
            } else {
                lastModifierDown = now
            }
        }
        lock.unlock()

        if shouldFire {
            fire()
        }
    }

    private func processKeyCombo(
        event: CGEvent,
        type: CGEventType,
        keyCode: UInt16,
        modifiers: UInt
    ) {
        guard type == .keyDown else { return }
        let pressedCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard pressedCode == keyCode else { return }

        let wanted = NSEvent.ModifierFlags(rawValue: modifiers)
            .intersection([.command, .option, .control, .shift])
        let current = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
            .intersection([.command, .option, .control, .shift])

        if current == wanted {
            fire()
        }
    }

    private func fire() {
        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?()
        }
    }
}
