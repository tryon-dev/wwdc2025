import SwiftUI

struct GridView: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var scrollOffset: CGPoint
    let spacing: CGFloat = 25
    let viewportSize: CGSize
    let extendedSpace: CGFloat = 800
    
    var gridSize: CGSize {
        CGSize(
            width: UIScreen.main.bounds.width + extendedSpace,
            height: UIScreen.main.bounds.height + extendedSpace
        )
    }
    
    var dotColor: CGColor {
        colorScheme == .dark ? CGColor(gray: 1.0, alpha: 0.3) : CGColor(gray: 0.0, alpha: 0.3)
    }
    
    func visibleRect(size: CGSize) -> CGRect {
        CGRect(
            x: -scrollOffset.x - extendedSpace/2,
            y: -scrollOffset.y - extendedSpace/2,
            width: viewportSize.width + extendedSpace,
            height: viewportSize.height + extendedSpace
        )
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let visible = visibleRect(size: size)
                let startX = Int(floor(visible.minX / spacing)) - 1
                let endX = Int(ceil(visible.maxX / spacing)) + 1
                let startY = Int(floor(visible.minY / spacing)) - 1
                let endY = Int(ceil(visible.maxY / spacing)) + 1
                
                context.withCGContext { ctx in
                    ctx.setFillColor(dotColor)
                    for x in startX...endX {
                        for y in startY...endY {
                            let pointX = CGFloat(x) * spacing
                            let pointY = CGFloat(y) * spacing
                            if pointX >= 0 && pointX <= size.width && pointY >= 0 && pointY <= size.height {
                                ctx.fillEllipse(in: CGRect(x: pointX - 1, y: pointY - 1, width: 2, height: 2))
                            }
                        }
                    }
                }
            }
            .drawingGroup()
            .frame(width: gridSize.width, height: gridSize.height)
        }
    }
}
