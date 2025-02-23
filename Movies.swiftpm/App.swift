import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @StateObject private var contentViewModel = ContentViewModel()
    
    var body: some View {
        ZStack {
            if hasSeenOnboarding {
                WhiteboardView(contentViewModel: contentViewModel)
            } else {
                Onboarding().statusBar(hidden: true)
            }
        }
        .animation(.easeInOut, value: hasSeenOnboarding)
    }
}

@main
struct MoviesApp: App {
    var body: some Scene {
        WindowGroup {
            RootView().statusBar(hidden: true)
        }
    }
}
