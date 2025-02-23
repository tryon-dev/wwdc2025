import SwiftUI

extension UIScreen {
    var displayCornerRadius: CGFloat {
        let key = "_displayCornerRadius"
        guard let cornerRadius = value(forKey: key) as? CGFloat else {
            return 0
        }
        return cornerRadius
    }
}

struct WhiteboardView: View {
    @StateObject private var viewModel: WhiteboardViewModel
    @ObservedObject var contentViewModel: ContentViewModel
    @State private var isFirstAppear = true
    @State private var showContentPicker = false
    @State private var showSettings = false
    @State private var tempLocation: CGPoint?
    @State private var isGridEnabled = true
    @State private var isGridVisible = false
    @State private var previewRect: CGRect? = nil
    @State private var previewOpacity: Double = 0
    @State private var previewScale: Double = 1.0
    @State private var textProgress: Double = 0
    @State private var showWarning = false
    @State private var warningOffset: CGFloat = 50
    @State private var warningBlur: CGFloat = 20
    @State private var warningOpacity: CGFloat = 0
    @State private var isWarningAnimating = false
    @AppStorage("showPlacementWarning") private var showPlacementWarning: Bool = true
    let maxScroll: CGFloat = 300
    let gridSize: CGFloat = 25
    let previewSize = CGSize(width: 150, height: 220)
    @GestureState private var scrollState = CGSize.zero
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let errorHaptics = UINotificationFeedbackGenerator()

    init(contentViewModel: ContentViewModel) {
        self.contentViewModel = contentViewModel
        _viewModel = StateObject(wrappedValue: WhiteboardViewModel(contentViewModel: contentViewModel))
    }
    
    private func snapToGrid(_ point: CGPoint) -> CGPoint {
        if isGridEnabled {
            return CGPoint(
                x: round(point.x / gridSize) * gridSize,
                y: round(point.y / gridSize) * gridSize
            )
        }
        return point
    }

    private func resetTextAnimation() {
        textProgress = 0
        withAnimation(.smooth(duration: 1.5, extraBounce: 0)) {
            textProgress = 1
        }
    }

    private func createPreviewRect(at location: CGPoint) -> CGRect {
        let snappedLocation = snapToGrid(location)
        return CGRect(
            x: snappedLocation.x - previewSize.width/2,
            y: snappedLocation.y - previewSize.height/2,
            width: previewSize.width,
            height: previewSize.height
        )
    }

    private func isValidLocation(_ location: CGPoint, in geometry: GeometryProxy) -> Bool {
        let margin: CGFloat = 20
        let rect = CGRect(
            x: margin + previewSize.width/2,
            y: margin + previewSize.height/2,
            width: geometry.size.width - (2 * margin + previewSize.width),
            height: geometry.size.height - (2 * margin + previewSize.height)
        )
        return rect.contains(location) || !showPlacementWarning
    }

    private func showWarningMessage() {
        guard !isWarningAnimating && showPlacementWarning else { return }
        
        errorHaptics.notificationOccurred(.error)
        isWarningAnimating = true
        
        warningBlur = 20
        warningOpacity = 0
        warningOffset = 50
        showWarning = true
        
        withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
            warningBlur = 0
            warningOpacity = 1
            warningOffset = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
                warningBlur = 20
                warningOpacity = 0
                warningOffset = 50
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showWarning = false
                isWarningAnimating = false
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ZStack {
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        ZStack {
                            Color(.systemBackground)
                                .frame(width: geometry.size.width, height: geometry.size.height)

                            if viewModel.isEditMode && isGridEnabled {
                                GridOverlay(gridSize: gridSize)
                            }

                            if viewModel.items.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "film")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                    Text("Tap anywhere to add a movie/series")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                        .textRenderer(TitleTextRenderer(progress: textProgress))
                                }
                                .onAppear(perform: resetTextAnimation)
                            } else {
                                Image("icon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50)
                                    .position(
                                        x: geometry.size.width / 2,
                                        y: geometry.size.height / 2
                                    )
                                    .opacity(0.3)
                                    .id("center")
                            }

                            ForEach($viewModel.items) { $item in
                                DraggableItem(
                                    item: $item,
                                    isEditMode: viewModel.isEditMode,
                                    viewModel: viewModel,
                                    onPositionChange: { newPosition in
                                        viewModel.updateItemPosition(item, to: newPosition)
                                    },
                                    onDelete: {
                                        viewModel.deleteItem(item)
                                    },
                                    onRotationChange: { newAngle in
                                        viewModel.updateItemRotation(item, to: newAngle)
                                    },
                                    isGridEnabled: isGridEnabled,
                                    gridSize: gridSize
                                )
                                .id(item.id)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isEditMode)
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(ScrollViewOffsetReader(offset: $viewModel.scrollOffset))
                        .onAppear {
                            if isFirstAppear {
                                proxy.scrollTo("center", anchor: .center)
                                isFirstAppear = false
                            }
                        }
                        .onTapGesture { location in
                            if !viewModel.isEditMode {
                                if isValidLocation(location, in: geometry) {
                                    haptics.impactOccurred(intensity: 0.6)
                                    tempLocation = location
                                    previewRect = createPreviewRect(at: location)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        previewOpacity = 1
                                    }
                                    showContentPicker = true
                                } else {
                                    showWarningMessage()
                                }
                            }
                        }
                    }
                    .scrollDisabled(viewModel.isEditMode)
                    .coordinateSpace(name: "scrollView")
                    .gesture(DragGesture().updating($scrollState) { value, state, _ in
                        let proposed = value.translation
                        let limited = CGSize(
                            width: min(maxScroll, max(-maxScroll, proposed.width)),
                            height: min(maxScroll, max(-maxScroll, proposed.height))
                        )
                        state = limited
                    })
                    .mask {
                        EdgeGradients()
                    }

                    GeometryReader { geo in
                        let cornerRadius = UIScreen.main.displayCornerRadius
                        RoundedRectangle(cornerRadius: viewModel.isEditMode ? cornerRadius-4 : cornerRadius+4)
                            .strokeBorder(Color.accentColor, lineWidth: 4)
                            .padding(viewModel.isEditMode ? 4 : 0)
                            .ignoresSafeArea()
                            .opacity(viewModel.isEditMode ? 1 : 0)
                    }

                    VStack {
                        HStack(alignment: .top, spacing: 12) {
                            Spacer()
                            
                            if viewModel.isEditMode {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isGridEnabled.toggle()
                                    }
                                }) {
                                    HStack {
                                        ZStack {
                                            Image(systemName: "square.grid.3x3")
                                                .font(.system(size: 24))
                                                .opacity(isGridEnabled ? 0 : 1)
                                            
                                            Image(systemName: "square.grid.3x3.fill")
                                                .font(.system(size: 24))
                                                .opacity(isGridEnabled ? 1 : 0)
                                        }
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isGridEnabled)
                                        
                                        ZStack {
                                            Text("Free")
                                                .font(.body)
                                                .opacity(isGridEnabled ? 0 : 1)
                                            
                                            Text("Snap")
                                                .font(.body)
                                                .opacity(isGridEnabled ? 1 : 0)
                                        }
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isGridEnabled)
                                    }
                                    .foregroundColor(isGridEnabled ? .blue : .gray)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                    )
                                }
                            }
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    viewModel.isEditMode.toggle()
                                    if !viewModel.isEditMode {
                                        isGridVisible = false
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: viewModel.isEditMode ? "pencil.circle.fill" : "pencil.circle")
                                        .font(.system(size: 24))
                                    Text(viewModel.isEditMode ? "Done" : "Edit")
                                        .font(.body)
                                }
                                .foregroundColor(viewModel.isEditMode ? .red : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                )
                            }
                            .scaleEffect(viewModel.isEditMode ? 1.1 : 1.0)
                            
                            Button(action: {
                                showSettings = true
                            }) {
                                HStack {
                                    if #available(iOS 18.0, *) {
                                        Image(systemName: "gear")
                                            .font(.system(size: 24))
                                            .symbolEffect(.rotate, options: .repeat(1), value: viewModel.isGearRotating ? 1 : 0)
                                    } else {
                                        Image(systemName: "gear")
                                            .font(.system(size: 24))
                                            .rotationEffect(.degrees(viewModel.isGearRotating ? 360 : 0))
                                            .animation(.easeInOut(duration: 1.0), value: viewModel.isGearRotating)
                                    }
                                    if !viewModel.isEditMode {
                                        Text("Settings")
                                            .font(.body)
                                    }
                                }
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                )
                            }
                            .sheet(isPresented: $showSettings) {
                                Settings()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, UIDevice.current.userInterfaceIdiom == .pad ? 20 : 0)
                        
                        Spacer()
                    }

                    if let rect = previewRect {
                        Rectangle()
                            .strokeBorder(
                                Color.red.opacity(0.8),
                                style: StrokeStyle(
                                    lineWidth: 2,
                                    dash: [8]
                                )
                            )
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .opacity(previewOpacity)
                            .scaleEffect(previewScale)
                    }

                    if showWarning {
                        VStack {
                            Spacer()
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                Text("Place your items inside the screen")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.8))
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            )
                            .offset(y: warningOffset)
                            .blur(radius: warningBlur)
                            .opacity(warningOpacity)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showContentPicker, onDismiss: {
            if tempLocation != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    previewOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    tempLocation = nil
                    previewRect = nil
                }
            }
        }) {
            ContentPickerView(
                onContentSelected: { selectedContent in
                    if let location = tempLocation {
                        let snappedLocation = snapToGrid(location)
                        viewModel.addItem(content: selectedContent, at: snappedLocation)
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        previewOpacity = 0
                        previewScale = 1.0
                    }
                    tempLocation = nil
                    previewRect = nil
                },
                existingItems: viewModel.items
            )
        }
        .onDisappear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                previewOpacity = 0
                previewScale = 1.0
            }
            previewRect = nil
        }
    }
}

struct GridOverlay: View {
    let gridSize: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                for x in stride(from: 0, through: geometry.size.width, by: gridSize) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                
                for y in stride(from: 0, through: geometry.size.height, by: gridSize) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.gray, lineWidth: 0.3)
        }
        .opacity(0.15)
    }
}
