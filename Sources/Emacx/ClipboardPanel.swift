import SwiftUI
import AppKit

// MARK: - Search field with keyboard interception

struct ClipboardSearchField: NSViewRepresentable {
    @Binding var text: String
    var onArrowUp: () -> Void
    var onArrowDown: () -> Void
    var onEnter: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let f = NSSearchField()
        f.bezelStyle = .roundedBezel
        f.font = .systemFont(ofSize: 16)
        f.placeholderString = "Search clipboard history..."
        f.delegate = context.coordinator
        f.translatesAutoresizingMaskIntoConstraints = false
        DispatchQueue.main.async {
            f.becomeFirstResponder()
        }
        return f
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text,
                     onArrowUp: onArrowUp,
                     onArrowDown: onArrowDown,
                     onEnter: onEnter,
                     onEscape: onEscape)
    }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        let onArrowUp: () -> Void
        let onArrowDown: () -> Void
        let onEnter: () -> Void
        let onEscape: () -> Void

        init(text: Binding<String>,
             onArrowUp: @escaping () -> Void,
             onArrowDown: @escaping () -> Void,
             onEnter: @escaping () -> Void,
             onEscape: @escaping () -> Void)
        {
            _text = text
            self.onArrowUp = onArrowUp
            self.onArrowDown = onArrowDown
            self.onEnter = onEnter
            self.onEscape = onEscape
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let f = obj.object as? NSSearchField else { return }
            text = f.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                onArrowUp(); return true
            case #selector(NSResponder.moveDown(_:)):
                onArrowDown(); return true
            case #selector(NSResponder.insertNewline(_:)):
                onEnter(); return true
            case #selector(NSResponder.cancelOperation(_:)):
                onEscape(); return true
            default:
                return false
            }
        }
    }
}

// MARK: - Row

struct ClipboardRow: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(text)
                .lineLimit(2)
                .truncationMode(.tail)
                .font(.system(size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Spacer()
        }
        .background(isSelected ? Color(.selectedContentBackgroundColor) : Color.clear)
        .foregroundColor(isSelected ? Color(.selectedMenuItemTextColor) : .primary)
        .contentShape(Rectangle())
    }
}

// MARK: - Panel content

struct ClipboardPanelContent: View {
    @StateObject private var manager = ClipboardManager.shared
    @State private var searchText = ""
    @State private var selectedIndex = 0

    private var filteredItems: [String] {
        if searchText.isEmpty { return manager.history }
        return manager.history.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ClipboardSearchField(
                text: $searchText,
                onArrowUp: {
                    guard !filteredItems.isEmpty else { return }
                    selectedIndex = max(0, selectedIndex - 1)
                },
                onArrowDown: {
                    guard !filteredItems.isEmpty else { return }
                    selectedIndex = min(filteredItems.count - 1, selectedIndex + 1)
                },
                onEnter: selectItem,
                onEscape: { ClipboardPanel.shared.hide() }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if filteredItems.isEmpty {
                VStack {
                    Image(systemName: "clipboard")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No clipboard history")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                itemList
            }
        }
        .frame(width: 600, height: 420)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separatorColor), lineWidth: 0.5))
        .shadow(radius: 20)
        .onChange(of: filteredItems.count) { _ in
            if !filteredItems.isEmpty, selectedIndex >= filteredItems.count {
                selectedIndex = 0
            }
        }
    }

    @ViewBuilder
    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredItems.indices, id: \.self) { index in
                        ClipboardRow(text: filteredItems[index],
                                     isSelected: index == selectedIndex)
                            .id(index)
                            .onTapGesture {
                                selectedIndex = index
                                selectItem()
                            }
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .onChange(of: selectedIndex) { _ in
                withAnimation(.snappy) {
                    proxy.scrollTo(selectedIndex, anchor: .center)
                }
            }
        }
    }

    private func selectItem() {
        guard !filteredItems.isEmpty, filteredItems.indices.contains(selectedIndex) else { return }
        manager.select(filteredItems[selectedIndex])
    }
}

// MARK: - Panel window

final class ClipboardWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Panel manager

@MainActor
final class ClipboardPanel {
    static let shared = ClipboardPanel()
    private var window: ClipboardWindow?
    private init() {}

    var isVisible: Bool { window?.isVisible ?? false }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        let panel = ClipboardWindow(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let content = ClipboardPanelContent()
        let hosting = NSHostingView(rootView: content)
        panel.contentView = hosting

        panel.setContentSize(NSSize(width: 600, height: 420))
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        window = panel
    }

    func hide() {
        window?.close()
        window = nil
    }
}
