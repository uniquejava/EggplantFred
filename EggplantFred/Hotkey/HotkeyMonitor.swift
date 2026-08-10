import AppKit
import Foundation

final class HotkeyMonitor: @unchecked Sendable {
    var onTrigger: (() -> Void)?

    private var shortcut: HotkeyShortcut = .doubleOption
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastOptionUp: CFAbsoluteTime = 0
    private let doubleTapInterval: CFAbsoluteTime = 0.35
    private var optionDown = false
    private let lock = NSLock()

    func updateShortcut(_ shortcut: HotkeyShortcut) {
        lock.lock()
        self.shortcut = shortcut
        lastOptionUp = 0
        optionDown = false
        lock.unlock()
    }

    func start() {
        stop()
        guard AXIsProcessTrusted() else { return }

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
            options: .listenOnly,
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
        let current = shortcut
        lock.unlock()

        switch current {
        case .doubleOption:
            processDoubleOption(event: event, type: type)
        case .keyCombo(let keyCode, let modifiers):
            processKeyCombo(event: event, type: type, keyCode: keyCode, modifiers: modifiers)
        }

        return Unmanaged.passUnretained(event)
    }

    private func processDoubleOption(event: CGEvent, type: CGEventType) {
        guard type == .flagsChanged else { return }
        let flags = event.flags
        let isOption = flags.contains(.maskAlternate)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        guard keyCode == 58 || keyCode == 61 else { return }

        var shouldFire = false

        lock.lock()
        if isOption {
            optionDown = true
            lock.unlock()
            return
        }

        guard optionDown else {
            lock.unlock()
            return
        }
        optionDown = false

        let others: CGEventFlags = [.maskCommand, .maskControl, .maskShift]
        if !flags.intersection(others).isEmpty {
            lock.unlock()
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        if now - lastOptionUp <= doubleTapInterval {
            lastOptionUp = 0
            shouldFire = true
        } else {
            lastOptionUp = now
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
