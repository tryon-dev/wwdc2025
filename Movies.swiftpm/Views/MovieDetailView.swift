import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMotion

// MARK: - Constants
private enum Constants {
    static let maxRotation: Double = 20
    static let maxOffset: CGFloat = 25
    static let returnDelay: TimeInterval = 1.8
    static let movementMultiplier: Double = 0.3
    static let perspective: Double = 1.4
    static let scrollThreshold: CGFloat = 100
    
    enum Animations {
        static let standard = Animation.interpolatingSpring(stiffness: 300, damping: 30)
        static let card = Animation.spring(response: 0.8, dampingFraction: 0.8)
        static let motion = Animation.interpolatingSpring(stiffness: 100, damping: 15)
    }
    
    enum Scale {
        static let minCard: CGFloat = 0.3
        static let maxCard: CGFloat = 1.0
        static let cardDivisor: CGFloat = 500
        static let opacityDivisor: CGFloat = 300
        static let scrollMultiplier: CGFloat = 0.8
        static let minOpacity: CGFloat = 0.6
    }
    
    enum Layout {
        static let cardHeight: CGFloat = 0.75
        static let contentHeight: CGFloat = 0.7
        static let screenHeight: CGFloat = 0.6
    }
}

// MARK: - SubjectExtractor
@available(iOS 16.0, *)
class SubjectExtractor: @unchecked Sendable {
    static let shared = SubjectExtractor()
    private let context = CIContext()
    
    enum ExtractionError: Error {
        case imageNotFound, noSubjectDetected, processingError, requestFailed(Error)
    }
    
    func extractSubject(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else { throw ExtractionError.imageNotFound }
        return try await extractSubjectImage(from: cgImage)
    }
    
    private func extractSubjectImage(from cgImage: CGImage) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
                guard let mask = request.results?.first as? VNPixelBufferObservation else {
                    throw ExtractionError.noSubjectDetected
                }
                
                let result = try processImageMask(originalImage: cgImage, mask: mask)
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: ExtractionError.requestFailed(error))
            }
        }
    }
    
    private func processImageMask(originalImage: CGImage, mask: VNPixelBufferObservation) throws -> UIImage {
        let maskBuffer = mask.pixelBuffer
        var maskCIImage = CIImage(cvPixelBuffer: maskBuffer)
        
        let scale = CGAffineTransform(
            scaleX: CGFloat(originalImage.width) / CGFloat(CVPixelBufferGetWidth(maskBuffer)),
            y: CGFloat(originalImage.height) / CGFloat(CVPixelBufferGetHeight(maskBuffer))
        )
        
        maskCIImage = maskCIImage.transformed(by: scale)
        let inputCIImage = CIImage(cgImage: originalImage)
        
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            throw ExtractionError.processingError
        }
        
        blendFilter.setValue(inputCIImage, forKey: kCIInputImageKey)
        blendFilter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(maskCIImage, forKey: kCIInputMaskImageKey)
        
        guard let outputCIImage = blendFilter.outputImage?.cropped(to: inputCIImage.extent),
              let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {
            throw ExtractionError.processingError
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - MovieDetailView
struct MovieDetailView: View {
    // MARK: - Properties
    let movie: WhiteboardItem
    @Binding var isPresented: Bool
    
    // MARK: - State
    @State private var motionManager = CMMotionManager()
    @State private var pitch: Double = 0
    @State private var roll: Double = 0
    @State private var yaw: Double = 0
    @State private var subjectImage: UIImage?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isReturning: Bool = false
    @State private var calibratedPitch: Double = 0
    @State private var calibratedRoll: Double = 0
    @State private var isCalibrating: Bool = true
    @State private var currentPage: Int = 0
    @State private var currentProgress: Double = 0
    @State private var showScrollIndicator: Bool = true
    @State private var isSubjectExtractionEnabled: Bool = true
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            PageView(pages: [
                AnyView(
                    MovieCardView(
                        movie: movie,
                        subjectImage: $subjectImage,
                        isLoading: $isLoading,
                        pitch: $pitch,
                        roll: $roll,
                        currentProgress: $currentProgress
                    )
                ),
                AnyView(
                    MovieInfoView(movie: movie)
                )
            ], currentPage: $currentPage, currentProgress: $currentProgress)
            
            VStack {
                fixedHeader
                Spacer()
            }
            
                VStack {
                    Text(errorMessage ?? "")
                        .font(.footnote)
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Color.yellow.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.top, 20)
                        .offset(y: errorMessage == nil ? -100 : 0)
                        .blur(radius: errorMessage == nil ? 100 : 0)
                        .opacity(errorMessage == nil ? 0 : 1)
                        .animation(.easeInOut(duration: 0.3))
                    Spacer()
                }
                .transition(.move(edge: .top))
        
        }
        .onAppear {
            setupView()
            startMotionUpdates()
        }
        .onDisappear { 
            stopMotionUpdates() 
        }
        .onChange(of: currentPage) { newValue in
            if (newValue == 1) {
                errorMessage = nil
            }
        }
    }
    
    // MARK: - View Components
    private var fixedHeader: some View {
        VStack {
            HStack(alignment: .center) {
                imageprocessingtoggle
                    .opacity(currentPage == 0 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
                    .padding(.leading, 10)
                
                
                Spacer()
                
                Text(movie.content.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .opacity(currentPage == 1 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
                    .offset(y: currentPage == 0 ? 10 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
                    .padding(.horizontal)
                
                Spacer()
                
                closeButton
            }
            .padding(.horizontal)
            .padding(.top, 15)
            .background(headerGradient)
            
            Spacer()
        }
    }
    
    private var imageprocessingtoggle: some View {
        Button(action: toggleSubjectExtraction) {
            Image(systemName: isSubjectExtractionEnabled ? "person.crop.rectangle.fill" : "person.crop.rectangle")
                .font(.title2)
                .foregroundColor(.white)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .blur(radius: 5)
                )
        }
    }
    
    private var closeButton: some View {
        Button(action: { isPresented = false }) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.white)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .blur(radius: 5)
                )
        }
    }
    
    private var headerGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black,
                Color.black.opacity(0.8),
                Color.black.opacity(0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 100)
        .edgesIgnoringSafeArea(.top)
    }
    
    // MARK: - Helper Functions
    private func setupView() {
        if #available(iOS 16.0, *) {
            if isSubjectExtractionEnabled {
                extractSubject()
            }
            haptics.prepare()
        }
    }
    
    private func extractSubject() {
        guard let uiImage = UIImage(named: movie.content.imageAssets.poster) else {
            errorMessage = "Image not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let extractedImage = try await SubjectExtractor.shared.extractSubject(from: uiImage)
                await MainActor.run {
                    self.subjectImage = extractedImage
                    self.isLoading = false
                }
            } catch {
                await handleExtractionError(error)
            }
        }
    }
    
    private func handleExtractionError(_ error: Error) async {
        await MainActor.run {
            self.errorMessage = "Vision usage failed, but it's not critical. Person extraction is disabled."
            self.isLoading = false
        }
    }
    
    private func startMotionUpdates() {
        guard motionManager.isGyroAvailable else { return }
        
        motionManager.gyroUpdateInterval = 1.0 / 30.0
        
        stopMotionUpdates()
        
        motionManager.startGyroUpdates(to: .main) { gyroData, error in
            guard let gyroData = gyroData,
                  error == nil else { return }
            
            let dampeningFactor = 0.4
            
            withAnimation(Constants.Animations.motion) {
                let newPitch = self.pitch + (gyroData.rotationRate.x * dampeningFactor)
                let newRoll = self.roll + (gyroData.rotationRate.y * dampeningFactor)
                
                // Limit maximum values with smooth clamping
                self.pitch = max(min(newPitch, 8), -8)
                self.roll = max(min(newRoll, 8), -8)
                
                // Apply stronger dampening for return to center
                if abs(self.pitch) > 0.1 {
                    self.pitch *= 0.98
                }
                if abs(self.roll) > 0.1 {
                    self.roll *= 0.98
                }
            }
        }
    }
    
    private func resetMotionCalibration() {
        pitch = 0
        roll = 0
        yaw = 0
    }
    
    private func stopMotionUpdates() {
        motionManager.stopGyroUpdates()
        withAnimation(Constants.Animations.card) {
            pitch = 0
            roll = 0
            yaw = 0
        }
    }
    
    private func toggleSubjectExtraction() {
        isSubjectExtractionEnabled.toggle()
        haptics.impactOccurred()
        
        if isSubjectExtractionEnabled {
            if #available(iOS 16.0, *) {
                extractSubject()
            }
        } else {
            subjectImage = nil
        }
    }
}

// MARK: - MovieCardView
private struct MovieCardView: View {
    let movie: WhiteboardItem
    @Binding var subjectImage: UIImage?
    @Binding var isLoading: Bool
    @Binding var pitch: Double
    @Binding var roll: Double
    @Binding var currentProgress: Double
    
    private let cornerRadius: CGFloat = 20
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                ZStack {
                    if let originalImage = UIImage(named: movie.content.imageAssets.poster) {
                        Image(uiImage: originalImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: geometry.size.height * 0.6)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            .blur(radius: 4)
                            .opacity(0.5)
                            .blendMode(.overlay)
                    }
                    
                    if #available(iOS 16.0, *) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else if let subjectImage = subjectImage {
                            Image(uiImage: subjectImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: geometry.size.height * 0.6)
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                .shadow(color: .white.opacity(0.4), radius: 12, x: 0, y: 0)
                                .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 0)
                                .overlay(
                                    RoundedRectangle(cornerRadius: cornerRadius)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .brightness(0.05)
                        } else if let originalImage = UIImage(named: movie.content.imageAssets.poster) {
                            Image(uiImage: originalImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: geometry.size.height * 0.6)
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        }
                    } else {
                        if let originalImage = UIImage(named: movie.content.imageAssets.poster) {
                            Image(uiImage: originalImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: geometry.size.height * 0.6)
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: cornerRadius)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.4), .purple.opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .rotation3DEffect(
                    .degrees(-roll * 3),
                    axis: (x: 0, y: 1, z: 0.3),
                    perspective: 1
                )
                .rotation3DEffect(
                    .degrees(pitch * 3),
                    axis: (x: 1, y: 0, z: 0.1),
                    perspective: 1
                )
                .scaleEffect(1.0 - currentProgress)
                .blur(radius: currentProgress * 20)
                .opacity(1 - currentProgress)
                .padding(.horizontal, 20)
                
                VStack(spacing: 10) {
                    Text(movie.content.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(0.9)
                    
                    Text("Swipe up for details")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 20)
                .opacity(1 - currentProgress)
                Spacer()
            }
        }
    }
}

// MARK: - MovieInfoView
private struct MovieInfoView: View {
    let movie: WhiteboardItem
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                synopsisSection
                castAndCreatorsSection
                detailsSection
                genresSection
                platformSection
            }
            .padding(.top, 100)
            .padding(.bottom, 40)
        }
    }
    
    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Synopsis")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            Text(movie.content.summary)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 5)
        }
        .padding(.horizontal)
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Details")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "IMDB Rating", value: String(format: "%.1f/10", movie.content.rating.imdb))
                InfoRow(label: "Release Date", value: movie.content.releaseDate)
                if let age = movie.content.age {
                    InfoRow(label: "Age Rating", value: "\(age)+")
                }
                InfoRow(label: "Type", value: movie.content.type == .movie ? "Movie" : "TV Series")
            }
        }
        .padding(.horizontal)
    }
    
    private var castAndCreatorsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Cast & Creators")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(movie.content.cast, id: \.self) { actor in
                    Text(actor)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Divider()
                .background(Color.white.opacity(0.5))
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(movie.content.director, id: \.self) { director in
                    Text(director)
                        .font(.body)
                        .italic()
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var genresSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Genres")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(movie.content.genres, id: \.self) { genre in
                        Text(genre)
                            .font(.subheadline)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
            }
            .preferredColorScheme(.dark)
        }
        .padding(.horizontal)
    }
    
    private struct PlatformIcons {
        let logo: String
        let icon: String
    }
    
    private var platformSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Available on")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                let icons = getPlatformIcons(for: movie.content.platform)                
                Image(systemName: icons.logo)
                    .font(.title2)
                    .foregroundColor(getPlatformColor(for: movie.content.platform))
                
                Text(movie.content.platform)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 5)
        }
        .padding(.horizontal)
    }
    
    private func getPlatformIcons(for platform: String) -> PlatformIcons {
        switch platform {
        case "Apple TV+":
            return PlatformIcons(logo: "apple.logo", icon: "play.tv.fill")
        case "Netflix":
            return PlatformIcons(logo: "tv", icon: "play.rectangle.fill")
        default:
            return PlatformIcons(logo: "tv", icon: "play.circle.fill")
        }
    }
    
    private func getPlatformColor(for platform: String) -> Color {
        switch platform {
        case "Netflix":
            return .red
        case "Apple TV+":
            return .white
        default:
            return .white
        }
    }
}

// MARK: - InfoRow
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
        .font(.system(.body))
    }
}
