import Cocoa

@MainActor
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var history: [String] = []

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = 0
    private var timer: Timer?
    private let maxHistory = 100
    private let historyKey = "emacx_clipboard_history"

    private init() {}

    func start() {
        load()
        lastChangeCount = pasteboard.changeCount
        if let s = pasteboard.string(forType: .string), !s.isEmpty {
            history.insert(s, at: 0)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let c = pasteboard.changeCount
        guard c != lastChangeCount else { return }
        lastChangeCount = c
        guard let s = pasteboard.string(forType: .string), !s.isEmpty else { return }
        guard s != history.first else { return }
        history.removeAll { $0 == s }
        history.insert(s, at: 0)
        if history.count > maxHistory { history = Array(history.prefix(maxHistory)) }
        save()
    }

    func select(_ string: String) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        lastChangeCount = pasteboard.changeCount
        if let i = history.firstIndex(of: string) {
            history.remove(at: i)
            history.insert(string, at: 0)
        }
        save()
        hidePanelAndPaste()
    }

    func clear() {
        history.removeAll()
        save()
    }

    private func hidePanelAndPaste() {
        ClipboardPanel.shared.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.postPaste()
        }
    }

    private func postPaste() {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) else { return }
        guard let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let items = try? JSONDecoder().decode([String].self, from: data) else { return }
        history = items
    }
}
