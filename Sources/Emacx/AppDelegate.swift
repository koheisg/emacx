import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var keyInterceptor: KeyInterceptor?
    private var trustTimer: Timer?
    private let menu = NSMenu()

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
        statusItem.button?.image = StatusIcon.make()
        menu.delegate = self
        statusItem.menu = menu
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if !AXIsProcessTrusted() {
            menu.addItem(withTitle: "Accessibility Permission Is Missing", action: nil, keyEquivalent: "")
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Quit Emacx", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }
}
