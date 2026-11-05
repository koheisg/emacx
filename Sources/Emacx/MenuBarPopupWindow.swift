import AppKit

final class MenuBarPopupWindow: NSPanel {
    var onClose: (() -> Void)?
    private let stackView = NSStackView()
    private var closeWorkItem: DispatchWorkItem?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    func update(items: [MenuBarItem]) {
        closeWorkItem?.cancel()
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let title = NSTextField(labelWithString: "Menu Bar Items")
        title.font = .boldSystemFont(ofSize: 13)
        stackView.addArrangedSubview(title)

        if items.isEmpty {
            stackView.addArrangedSubview(NSTextField(labelWithString: "No visible items or Accessibility permission is missing."))
        } else {
            items.forEach { item in
                let label = NSTextField(labelWithString: "\(item.title)  ·  \(item.owner)")
                label.lineBreakMode = .byTruncatingMiddle
                stackView.addArrangedSubview(label)
            }
        }

        let height = min(CGFloat(items.count + 1) * 28 + 24, 520)
        setContentSize(NSSize(width: 420, height: max(120, height)))
    }

    func scheduleClose() {
        closeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.close()
        }
        closeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    override func close() {
        super.close()
        onClose?()
    }

    override func mouseEntered(with event: NSEvent) {
        closeWorkItem?.cancel()
    }

    override func mouseExited(with event: NSEvent) {
        scheduleClose()
    }

    private func configure() {
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96)
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = stackView
        contentView = scrollView

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView?.addTrackingArea(trackingArea)

        NSLayoutConstraint.activate([
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor)
        ])
    }
}
