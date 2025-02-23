import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

@MainActor
struct ScrollViewOffsetReader: View {
    @Binding var offset: CGPoint
    let maxOffset: CGFloat = 300
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geo.frame(in: .named("scrollView")).origin.x
                )
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    Task { @MainActor in
                        offset = CGPoint(
                            x: min(maxOffset, max(-maxOffset, value)),
                            y: offset.y
                        )
                    }
                }
        }
    }
}
