import SwiftUI

struct EdgeGradients: View {
    @Environment(\.colorScheme) var colorScheme
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemBackground) : .white
    }
    
    var body: some View {
        GeometryReader { geo in
            VStack (spacing: 0) {
                LinearGradient(gradient: Gradient(colors: [backgroundColor.opacity(0), backgroundColor]), startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                
                Rectangle()
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
