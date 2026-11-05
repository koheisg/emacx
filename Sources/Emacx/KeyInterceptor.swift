import Cocoa
import os

@MainActor
final class KeyInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isEnabled = true

    private let lock = OSAllocatedUnfairLock()
    private var selfPostCount = 0

    var isRunning: Bool { eventTap != nil }

    @discardableResult
    func start() -> Bool {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Event Tap Callback

    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon else {
            return Unmanaged.passUnretained(event)
        }
        let self_ = Unmanaged<KeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
        return self_.handleEvent(proxy: proxy, type: type, event: event)
    }

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard isEnabled, type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        lock.lock()
        let isSelfPost = selfPostCount > 0
        lock.unlock()

        if isSelfPost {
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        let hasCtrl = flags.contains(.maskControl)
        let hasCmd = flags.contains(.maskCommand)
        let hasAlt = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)

        if hasCmd && hasShift && !hasCtrl && !hasAlt && keyCode == 0x09 {
            ClipboardPanel.shared.toggle()
            return nil
        }

        if isTerminalFrontmost() {
            return Unmanaged.passRetained(event)
        }

        guard hasCtrl && !hasCmd && !hasAlt && !hasShift else {
            return Unmanaged.passRetained(event)
        }

        switch keyCode {
        case 0x0D: // W
            postDeletePreviousWord()
            return nil
        case 0x20: // U
            postSelectToBeginningOfLineAndDelete()
            return nil
        default:
            return Unmanaged.passRetained(event)
        }
    }

    // MARK: - Key Posting

    private func isTerminalFrontmost() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        let terminalBundleIDs: Set<String> = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "com.github.wez.wezterm",
            "net.kovidgoyal.kitty",
            "org.alacritty",
            "com.mitchellh.ghostty",
            "dev.warp.Warp",
            "co.zeit.hyper"
        ]
        return terminalBundleIDs.contains(bundleID)
    }

    private func post(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags = []) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else {
            return
        }
        event.flags = flags

        lock.lock()
        selfPostCount += 1
        lock.unlock()

        event.post(tap: .cghidEventTap)

        lock.lock()
        selfPostCount -= 1
        lock.unlock()
    }

    private func postKeyDownUp(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        post(keyCode: keyCode, keyDown: true, flags: flags)
        post(keyCode: keyCode, keyDown: false, flags: flags)
    }

    private func postDeletePreviousWord() {
        postKeyDownUp(0x33, flags: [.maskAlternate])
    }

    private func postSelectToBeginningOfLineAndDelete() {
        postKeyDownUp(0x7B, flags: [.maskCommand, .maskShift])
        postKeyDownUp(0x33)
    }
}
