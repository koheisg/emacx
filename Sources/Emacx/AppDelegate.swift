import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var keyInterceptor: KeyInterceptor?
    private var trustTimer: Timer?
    private let menuBarManager = MenuBarManager()
    private var menuBarWindow: MenuBarPopupWindow?
    private var trackingArea: NSTrackingArea?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        ClipboardManager.shared.start()
        startKeyInterceptorIfTrusted()
    }

    func applicationWillTerminate(_ notification: Notification) {
        trustTimer?.invalidate()
        keyInterceptor?.stop()
        ClipboardManager.shared.stop()
    }

    private func startKeyInterceptorIfTrusted() {
        if AXIsProcessTrusted() {
            startKeyInterceptor()
            return
        }
        requestAccessibilityPermission()
        monitorTrustUntilGranted()
    }

    private func startKeyInterceptor() {
        let interceptor = KeyInterceptor()
        keyInterceptor = interceptor
        if !interceptor.start() {
            requestAccessibilityPermission()
        }
    }

    private func monitorTrustUntilGranted() {
        trustTimer?.invalidate()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollTrust()
            }
        }
    }

    private func pollTrust() {
        guard keyInterceptor?.isRunning != true else {
            trustTimer?.invalidate()
            trustTimer = nil
            return
        }
        guard AXIsProcessTrusted() else { return }
        trustTimer?.invalidate()
        trustTimer = nil
        startKeyInterceptor()
    }

    private func requestAccessibilityPermission() {
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(prompt)

        let alert = NSAlert()
        alert.messageText = "アクセシビリティ権限が必要です"
        alert.informativeText = "Emacxはグローバルキーボードショートカットを監視するため、"
            + "アクセシビリティへのアクセスが必要です。\n\n"
            + "システム設定 > プライバシーとセキュリティ > アクセシビリティ\n"
            + "でEmacx.appを追加してください。\n"
            + "許可されると自動的に監視を開始します。"
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "後で")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.image = StatusIcon.make()
        button.target = self
        button.action = #selector(toggleMenuBarPopup)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea!)
    }

    @objc func mouseEntered(with event: NSEvent) {
        showMenuBarPopup()
    }

    @objc func mouseExited(with event: NSEvent) {
        menuBarWindow?.scheduleClose()
    }

    @objc private func toggleMenuBarPopup() {
        if menuBarWindow?.isVisible == true {
            menuBarWindow?.close()
            menuBarWindow = nil
        } else {
            showMenuBarPopup()
        }
    }

    private func showMenuBarPopup() {
        guard let button = statusItem.button, let screen = button.window?.screen else { return }

        let items = menuBarManager.visibleMenuBarItems()
        let window = menuBarWindow ?? MenuBarPopupWindow()
        window.update(items: items)
        window.onClose = { [weak self] in self?.menuBarWindow = nil }

        let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
        let size = window.frame.size
        let x = min(max(buttonFrame.midX - size.width / 2, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - size.width - 8)
        let y = max(buttonFrame.minY - size.height - 8, screen.visibleFrame.minY + 8)
        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        window.makeKeyAndOrderFront(nil)
        menuBarWindow = window
    }
}
