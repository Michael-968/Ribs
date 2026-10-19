import SwiftUI
import SwiftData

@main
struct RibsApp: App {
    @State private var player = PlayerEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(player)
        }
        .modelContainer(for: [Track.self, Playlist.self])
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1360, height: 896)
        .commands {
            PlayerCommands(player: player)
        }
    }
}

struct PlayerCommands: Commands {
    let player: PlayerEngine

    var body: some Commands {
        CommandMenu("Controls") {
            Button(player.isPlaying ? "Pause" : "Play") { player.togglePlayPause() }
                .keyboardShortcut(.space, modifiers: [])
            Button("Next") { player.next() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            Button("Previous") { player.previous() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            Divider()
            Button(player.shuffle ? "Turn Shuffle Off" : "Turn Shuffle On") { player.toggleShuffle() }
            Button("Repeat: \(player.repeatMode.label)") { player.cycleRepeat() }
                .keyboardShortcut("r", modifiers: .command)
        }
    }
}
