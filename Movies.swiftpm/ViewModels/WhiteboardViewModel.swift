import SwiftUI
import Foundation

// MARK: - Storage Item
private struct StoredWhiteboardItem: Codable {
    let id: String
    let contentId: String
    let x: Double
    let y: Double
    let rotationAngle: Double

    init(from item: WhiteboardItem) {
        self.id = item.id
        self.contentId = item.content.id
        self.x = Double(item.position.x)
        self.y = Double(item.position.y)
        self.rotationAngle = item.rotationAngle
    }

    var toPosition: CGPoint {
        CGPoint(x: x, y: y)
    }
}

@MainActor
class WhiteboardViewModel: ObservableObject {
    @Published var items: [WhiteboardItem] = []
    @Published var isEditMode = false
    @Published var isGearRotating = false
    @Published var scrollOffset: CGPoint = .zero

    private let defaults = UserDefaults.standard
    private let storageKey = "stored_whiteboard_items"
    private let contentViewModel: ContentViewModel

    init(contentViewModel: ContentViewModel) {
        self.contentViewModel = contentViewModel
        loadSavedItems()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadItems),
            name: NSNotification.Name("ReloadWhiteboard"),
            object: nil
        )
    }
    
    @objc private func reloadItems() {
        items = []
        loadSavedItems()
    }

    private func loadSavedItems() {
        guard let data = defaults.data(forKey: storageKey),
              let storedItems = try? JSONDecoder().decode([StoredWhiteboardItem].self, from: data) else {
            return
        }

        items = storedItems.compactMap { stored in
            guard let content = contentViewModel.items.first(where: { $0.id == stored.contentId }) else {
                return nil
            }
            return WhiteboardItem(
                id: stored.id,
                content: content,
                position: stored.toPosition,
                rotationAngle: stored.rotationAngle
            )
        }
    }

    private func saveItems() {
        let storedItems = items.map { StoredWhiteboardItem(from: $0) }
        if let data = try? JSONEncoder().encode(storedItems) {
            defaults.set(data, forKey: storageKey)
        }
    }

    func addItem(content: ContentItem, at position: CGPoint) {
        let item = WhiteboardItem(id: UUID().uuidString, content: content, position: position, rotationAngle: 0)
        items.append(item)
        saveItems()
    }

    func deleteItem(_ item: WhiteboardItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func updateItemPosition(_ item: WhiteboardItem, to position: CGPoint) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].position = position
            saveItems()
        }
    }

    func updateItemRotation(_ item: WhiteboardItem, to angle: Double) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].rotationAngle = angle
            saveItems()
        }
    }
}
