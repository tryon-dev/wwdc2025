import SwiftUI

struct Settings: View {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @AppStorage("showPlacementWarning") var showPlacementWarning: Bool = true
    @Environment(\.dismiss) private var dismiss
    @State private var showTechnicalDetails = false
    @State private var showResetAlert = false
    @AppStorage("stored_whiteboard_items") var storedItems: Data?
    @Environment(\.refresh) private var refresh
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $showPlacementWarning) {
                        Label {
                            Text("Placement Warning")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                    }
                } header: {
                    Text("Warnings")
                } footer: {
                    Text("When disabled, you can place items anywhere on the screen without warning.")
                }

                Section {
                    Button(action: {
                        dismiss()
                        hasSeenOnboarding = false
                    }) {
                        HStack {
                            Text("Review onboarding")
                            Spacer()
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        showResetAlert = true
                    }) {
                        HStack {
                            Text("Reset all cards")
                            Spacer()
                            Image(systemName: "trash")
                        }
                    }
                } header: {
                    Text("General")
                }
                
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Movies", systemImage: "info.circle")
                    }
                } header: {
                    Text("Information")
                }
            }
            .navigationTitle("Settings")
            .alert("Reset all cards", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    storedItems = nil
                    dismiss()
                    NotificationCenter.default.post(name: NSNotification.Name("ReloadWhiteboard"), object: nil)
                }
            } message: {
                Text("This will remove all cards from your whiteboard. This action cannot be undone.")
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Project Story")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Text("Movies is a creative project that allows you to organize and visualize your favorite films in a unique and interactive way. The app combines the simplicity of a whiteboard with the power of modern iOS technologies.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Technical Features")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    TechFeatureRow(
                        title: "Image Processing",
                        description: "Using Vision framework to automatically detect and extract subjects from movie posters.",
                        icon: "wand.and.stars"
                    )
                    
                    TechFeatureRow(
                        title: "Interactive 3D Effects",
                        description: "Gyroscope integration for dynamic poster movement and parallax effects.",
                        icon: "rotate.3d"
                    )
                    
                    TechFeatureRow(
                        title: "Drag & Drop Interface",
                        description: "Intuitive gesture-based interaction for organizing your movie collection.",
                        icon: "hand.draw"
                    )
                }
                .padding(.vertical, 8)
            }
            
            Section {
                    
                    Text("Created by Lucas Lavajo")
                        .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("About")
    }
}

struct TechFeatureRow: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.subheadline)
                    .bold()
            }
            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    Settings()
} 
