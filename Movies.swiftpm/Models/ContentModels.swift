import Foundation

// MARK: - ContentResponse Model
struct ContentResponse: Codable {
    let content: [ContentItem]
    let metadata: Metadata
}

struct Metadata: Codable {
    let lastUpdated: String
    let version: String
}

struct ContentItem: Codable, Identifiable {
    let id: String
    let type: ContentType
    let title: String
    let releaseDate: String
    let age: Int?
    let rating: Rating
    let genres: [String]
    let summary: String
    let imageAssets: ImageAssets
    let cast: [String]
    let director: [String]
    let platform: String
}

enum ContentType: String, Codable {
    case series
    case movie
}

struct Rating: Codable {
    let imdb: Double
}

struct ImageAssets: Codable {
    let poster: String
}

// MARK: - ContentViewModel
@MainActor
class ContentViewModel: ObservableObject {
    @Published var items: [ContentItem] = []
    @Published var errorMessage: String?

    init() {
        loadData()
    }

    func loadData() {
        items = sampleContent.content
    }

    func filterContent(by type: ContentType) -> [ContentItem] {
        items.filter { $0.type == type }
    }

    func filterContent(by genre: String) -> [ContentItem] {
        items.filter { $0.genres.contains(genre) }
    }

    func filterContent(byAge age: Int) -> [ContentItem] {
        items.filter { ($0.age ?? 0) <= age }
    }

    var allGenres: [String] {
        Set(items.flatMap { $0.genres }).sorted()
    }

    var allPlatforms: [String] {
        Set(items.map { $0.platform }).sorted()
    }
}
