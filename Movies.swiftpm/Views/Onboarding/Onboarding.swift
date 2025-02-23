import SwiftUI

struct Onboarding: View {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @State private var activeCard: Card? = cards.first
    @State private var scrollPosition: ScrollPosition = .init()
    @State private var currentScrollOffset: CGFloat = 0
    @State private var timer = Timer.publish(every: 0.01, on: .current, in: .default).autoconnect()
    @State private var initialAnimation: Bool = false
    @State private var titleProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            ambientBackground
                .animation(.easeInOut(duration: 1), value: activeCard)
            
            VStack (spacing: 20) {
                InfiniteScrollView {
                    ForEach(cards) { card in
                        carouselCardView(card)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollPosition($scrollPosition)
                .frame(maxWidth: .infinity)
                .frame(height: UIDevice.current.userInterfaceIdiom == .phone ? 400 : 600)
                .onScrollGeometryChange(for: CGFloat.self) {
                    $0.contentOffset.x + $0.contentInsets.leading
                } action: { oldValue, newValue in
                    currentScrollOffset = newValue
                    
                    let index = Int((currentScrollOffset / 220).rounded())
                    let safeIndex = ((index % cards.count) + cards.count) % cards.count
                    activeCard = cards[safeIndex]
                }
                .visualEffect { [initialAnimation] content, proxy in content
                        .offset(y: !initialAnimation ? -(proxy.size.height + 80) : 0)
                    
                }
                VStack(spacing: 4) {
                    Text("Welcome to")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.secondary)
                        .blurOpacityEffect(initialAnimation)
                    Text("Movies")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .textRenderer(TitleTextRenderer(progress: titleProgress))
                        .padding(.bottom, 12)
                    Text("Create your own chart of the best films, modify it, get information on your favourite films, but above all have fun!")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.secondary)
                        .blurOpacityEffect(initialAnimation)
                        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .phone ? 24 : 40)
                

                }
                Button {
                    timer.upstream.connect().cancel()
                    hasSeenOnboarding = true
                } label: {
                    Text("Get Started")
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 25)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                }
                .blurOpacityEffect(initialAnimation)

            }
            .safeAreaPadding(15)
        }
        .onReceive(timer) { _ in
            currentScrollOffset += 0.20
            scrollPosition.scrollTo(x: currentScrollOffset)
        }
        
        .task {
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.smooth(duration: 0.75, extraBounce: 0.5)) {
                initialAnimation = true
            }
            withAnimation(.smooth(duration: 1.5, extraBounce: 0).delay(0.3)) {
                titleProgress = 1
            }
        }
    }
   
        
    
    private var ambientBackground: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ForEach(cards) { card in
                    Image(card.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .frame(width: size.width, height: size.height)
                        .opacity(activeCard?.id == card.id ? 1 : 0)
                }
                
                Rectangle()
                    .fill(.black.opacity(0.45))
                    .ignoresSafeArea()
            }
            .compositingGroup()
            .blur(radius: 90, opaque: true)
            .ignoresSafeArea()
        }
    }
    
    private func carouselCardView(_ card: Card) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            Image(card.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: UIDevice.current.userInterfaceIdiom == .phone ? 280 : 350,
                    height: UIDevice.current.userInterfaceIdiom == .phone ? 400 : 500
                )
                .clipShape(.rect(cornerRadius: 20))
                .shadow(color: .black.opacity(0.4), radius: 10, x: 1, y: 0)
        }
        .frame(
            width: UIDevice.current.userInterfaceIdiom == .phone ? 280 : 350,
            height: UIDevice.current.userInterfaceIdiom == .phone ? 400 : 500
        )
        .padding(.horizontal, 15)
        .scrollTransition(.interactive.threshold(.centered), axis: .horizontal) { content, phase in
            content
                .offset(y: phase == .identity ? 0 : 90)
                .scaleEffect(phase.isIdentity ? 0.9 : 0.7)
                .opacity(phase.isIdentity ? 1 : 0)
                .blur(radius: phase.isIdentity ? 0 : 10)
                .rotationEffect(.degrees(phase.value * 10), anchor: .bottom)
        }
    }
}

struct Onboarding_Previews: PreviewProvider {
    static var previews: some View {
        Onboarding()
    }
}

extension View {
    func blurOpacityEffect(_ show: Bool) -> some View {
        self
            .blur(radius: show ? 0 : 2)
            .opacity(show ? 1 : 0)
            .scaleEffect(show ? 1 : 0.9)
    }
}


