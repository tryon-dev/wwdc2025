import SwiftUI

struct DraggableItem: View {
    @Binding var item: WhiteboardItem
    let isEditMode: Bool
    let viewModel: WhiteboardViewModel
    let onPositionChange: (CGPoint) -> Void
    let onDelete: () -> Void
    let onRotationChange: (Double) -> Void
    let isGridEnabled: Bool
    let gridSize: CGFloat

    @State private var currentPosition: CGPoint
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var rotationAngle: Double
    @State private var showMovieDetail = false
    @State private var isSnapping = false

    init(
        item: Binding<WhiteboardItem>,
        isEditMode: Bool,
        viewModel: WhiteboardViewModel,
        onPositionChange: @escaping (CGPoint) -> Void,
        onDelete: @escaping () -> Void,
        onRotationChange: @escaping (Double) -> Void,
        isGridEnabled: Bool = false,
        gridSize: CGFloat = 100
    ) {
        self._item = item
        self.isEditMode = isEditMode
        self.viewModel = viewModel
        self.onPositionChange = onPositionChange
        self.onDelete = onDelete
        self.onRotationChange = onRotationChange
        self.isGridEnabled = isGridEnabled
        self.gridSize = gridSize
        self._currentPosition = State(initialValue: item.wrappedValue.position)
        self._rotationAngle = State(initialValue: item.wrappedValue.rotationAngle)
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

    var contextMenuContent: some View {
        Group {
            Button(action: {
                showMovieDetail = true
            }) {
                Label("Information", systemImage: "info.circle")
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    var contextMenuPreview: some View {
        VStack(spacing: 8) {
            if let image = UIImage(named: item.content.imageAssets.poster) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
                    .cornerRadius(10)
            }

            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.content.title)
                        .font(.body)
                    Text(item.content.genres[0])
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(5)
                Spacer()
                Text("-\(item.content.age ?? 0)")
                    .font(.title)
                    .foregroundColor(Color(UIColor.systemBackground))
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.systemGray3))
                    )
                    .padding(.trailing, 5)
            }
        }
        .padding(5)
        .background(Color(UIColor.systemBackground))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let image = UIImage(named: item.content.imageAssets.poster) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150)
                    .cornerRadius(5)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: isDragging ? 20 : 10, x: 0, y: isDragging ? 10 : 5)
        )
        .rotationEffect(Angle(degrees: rotationAngle))
        .contextMenu(menuItems: { isEditMode ? nil : contextMenuContent }, preview: { contextMenuPreview })
        .position(currentPosition)
        .gesture(isEditMode ? dragGesture : nil)
        .onChange(of: item.position) { newPosition in
            if !isDragging {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    currentPosition = newPosition
                }
            }
        }
        .onTapGesture {
            if isEditMode {
                print("Item tapped in edit mode")
            } else {
                showMovieDetail = true
            }
            
            for index in viewModel.items.indices {
                if viewModel.items[index].id != item.id && viewModel.items[index].isRotationDialogVisible {
                    withAnimation {
                        viewModel.items[index].isRotationDialogVisible = false
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showMovieDetail) {
            MovieDetailView(movie: item, isPresented: $showMovieDetail).statusBar(hidden: true)
        }
    }

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                isDragging = true
                let translation = gesture.translation
                var newPosition = CGPoint(
                    x: currentPosition.x + translation.width - dragOffset.width,
                    y: currentPosition.y + translation.height - dragOffset.height
                )
                
                if isGridEnabled {
                    let snappedPosition = snapToGrid(newPosition)
                    if !isSnapping && snappedPosition != newPosition {
                        isSnapping = true
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            newPosition = snappedPosition
                        }
                    } else if isSnapping && snappedPosition == newPosition {
                        isSnapping = false
                    }
                }
                
                dragOffset = translation
                withAnimation(isGridEnabled ? .spring(response: 0.2, dampingFraction: 0.7) : .spring(response: 0.2, dampingFraction: 0.7)) {
                    currentPosition = newPosition
                }
            }
            .onEnded { _ in
                isDragging = false
                dragOffset = .zero
                if isGridEnabled {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentPosition = snapToGrid(currentPosition)
                    }
                }
                onPositionChange(currentPosition)
            }
    }
}
