import SwiftUI
import SwiftData

@main
struct RibsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Track.self, Playlist.self])
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1360, height: 896)
    }
}
