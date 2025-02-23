import SwiftUI

struct InfiniteScrollView<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content
    @State private var contentSize: CGSize = .zero
    @State private var offset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var visibleIndices: [Int] = Array(-50...50) // Buffer initial
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    if #available(iOS 18.0, *) {
                        Group(subviews: content) { collection in
                            let views = Array(collection)
                            let totalViews = views.count
                            
                            HStack(spacing: spacing) {
                                ForEach(visibleIndices, id: \.self) { virtualIndex in
                                    let realIndex = ((virtualIndex % totalViews) + totalViews) % totalViews
                                    views[realIndex]
                                }
                            }
                        }
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(key: ViewSizeKey.self, value: geometry.size)
                            }
                        )
                        .onPreferenceChange(ViewSizeKey.self) { newSize in
                            Task { @MainActor in
                                contentSize = newSize
                                if scrollOffset == 0 {
                                    let centerIndex = visibleIndices.count / 2
                                    scrollOffset = CGFloat(centerIndex) * (newSize.width / CGFloat(visibleIndices.count))
                                }
                            }
                        }
                    } else {
                        content
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .overlay {
                GeometryReader { proxy in
                    let minX = proxy.frame(in: .named("scroll")).minX
                    Color.clear
                        .onChange(of: minX) { newValue in
                            handleScroll(minX: newValue)
                        }
                }
            }
            .background {
                InfiniteScrollHelper(contentSize: $contentSize, offset: $scrollOffset)
            }
        }
    }
    
    private func handleScroll(minX: CGFloat) {
        guard contentSize.width > 0 else { return }
        
        let itemWidth = contentSize.width / CGFloat(visibleIndices.count)
        let currentPosition = -minX / itemWidth
        
        if currentPosition > CGFloat(visibleIndices.count - 20) {
            let lastIndex = visibleIndices.last ?? 0
            visibleIndices.append(contentsOf: (lastIndex + 1...lastIndex + 20))
        } else if currentPosition < 20 {
            let firstIndex = visibleIndices.first ?? 0
            visibleIndices.insert(contentsOf: (firstIndex - 20...firstIndex - 1).reversed(), at: 0)
        }
        
        scrollOffset = -minX
    }
}

private struct ViewSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}



