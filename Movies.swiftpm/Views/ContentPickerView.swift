import SwiftUI

struct ContentPickerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var contentViewModel = ContentViewModel()
    @State private var searchText = ""
    @State private var selectedType: ContentType?
    let onContentSelected: (ContentItem) -> Void
    let existingItems: [WhiteboardItem]
    
    private func isItemInWhiteboard(_ item: ContentItem) -> Bool {
        existingItems.contains { $0.content.id == item.id }
    }
    
    var filteredContent: [(category: String, items: [ContentItem])] {
        let initialContent = contentViewModel.allGenres.flatMap { genre in
            contentViewModel.filterContent(by: genre)
        }
        
        let uniqueContent = Dictionary(grouping: initialContent, by: { $0.id })
            .values
            .compactMap { $0.first }
        
        let typeFiltered = selectedType == nil ? uniqueContent : uniqueContent.filter { $0.type == selectedType }
        
        let searchFiltered = searchText.isEmpty ? typeFiltered : typeFiltered.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText) ||
            item.genres.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        var categories = [(category: String, items: [ContentItem])]()
        
        let movies = searchFiltered.filter { $0.type == .movie }
        let series = searchFiltered.filter { $0.type == .series }
        
        if !movies.isEmpty {
            categories.append(("Movies", movies.sorted(by: { $0.releaseDate > $1.releaseDate })))
        }
        if !series.isEmpty {
            categories.append(("TV Series", series.sorted(by: { $0.releaseDate > $1.releaseDate })))
        }
        
        return searchText.isEmpty ? categories : [("Search Results", searchFiltered)]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Content Type", selection: $selectedType) {
                    Text("All").tag(Optional<ContentType>.none)
                    Text("Movies").tag(Optional<ContentType>.some(.movie))
                    Text("TV Series").tag(Optional<ContentType>.some(.series))
                }
                .pickerStyle(.segmented)
                .padding()
                
                List {
                    ForEach(filteredContent, id: \.category) { section in
                        if !section.items.isEmpty {
                            Section(header: Text(section.category)) {
                                ForEach(section.items) { item in
                                    Button(action: {
                                        if !isItemInWhiteboard(item) {
                                            onContentSelected(item)
                                            dismiss()
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            if let image = UIImage(named: item.imageAssets.poster) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 60, height: 90)
                                                    .cornerRadius(8)
                                                    .opacity(isItemInWhiteboard(item) ? 0.5 : 1)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.title)
                                                    .font(.body)
                                                    .foregroundColor(isItemInWhiteboard(item) ? .secondary : .primary)
                                                
                                                Text(item.genres.joined(separator: ", "))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            if let age = item.age {
                                                Text("\(age)+")
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color(.systemGray5))
                                                    .cornerRadius(4)
                                                    .opacity(isItemInWhiteboard(item) ? 0.5 : 1)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .disabled(isItemInWhiteboard(item))
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search movies & TV shows...")
            .navigationTitle("Select Content")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

extension Array {
    func partition(by predicate: (Element) -> Bool) -> ([Element], [Element]) {
        var matching = [Element]()
        var nonMatching = [Element]()
        
        forEach { element in
            if predicate(element) {
                matching.append(element)
            } else {
                nonMatching.append(element)
            }
        }
        
        return (matching, nonMatching)
    }
}
