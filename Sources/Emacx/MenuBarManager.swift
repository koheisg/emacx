import AppKit

struct MenuBarItem: Identifiable {
    let id = UUID()
    let title: String
    let owner: String
}

final class MenuBarManager {
    func visibleMenuBarItems() -> [MenuBarItem] {
        var results: [MenuBarItem] = []
        var seen = Set<String>()

        for app in menuBarHostingApplications() {
            let ownerName = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
            let element = AXUIElementCreateApplication(app.processIdentifier)
            for extra in extrasMenuBarItems(of: element) {
                let title = extra.isEmpty ? ownerName : extra
                let key = "\(ownerName)::\(title)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                results.append(MenuBarItem(title: title, owner: ownerName))
            }
        }

        return results.sorted { $0.owner.localizedCaseInsensitiveCompare($1.owner) == .orderedAscending }
    }

    private func menuBarHostingApplications() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
    }

    private func extrasMenuBarItems(of app: AXUIElement) -> [String] {
        var extras: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, "AXExtrasMenuBar" as CFString, &extras) == .success,
              let extras,
              CFGetTypeID(extras) == AXUIElementGetTypeID() else {
            return []
        }

        let extrasElement = extras as! AXUIElement
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(extrasElement, kAXChildrenAttribute as CFString, &children) == .success,
              let items = children as? [AXUIElement] else {
            return []
        }

        return items.map { item in
            for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, "AXHelp"] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(item, attribute as CFString, &value) == .success,
                   let text = value as? String, !text.isEmpty {
                    return text
                }
            }
            return ""
        }
    }
}
