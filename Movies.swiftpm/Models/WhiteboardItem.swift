import SwiftUI

struct WhiteboardItem: Identifiable {
    let id: String
    let content: ContentItem
    var position: CGPoint
    var rotationAngle: Double
    var isRotationDialogVisible: Bool = false
}
