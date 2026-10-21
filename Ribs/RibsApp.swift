import SwiftUI
import SwiftData
import AppKit

@main
struct RibsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var player = PlayerEngine()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(player)
        }
        .modelContainer(for: [Track.self, Playlist.self])
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1360, height: 896)
        .commands {
            PlayerCommands(player: player)
        }

        // Ribs → Settings… (Cmd + ,)
        Settings {
            SettingsView()
        }

        // Menu bar mini player: icon turns red while playing
        MenuBarExtra {
            MiniPlayerView()
                .environment(player)
        } label: {
            Image(nsImage: MenuBarIcon.image(playing: player.isPlaying))
        }
        .menuBarExtraStyle(.window)
    }
}

enum MenuBarIcon {
    static func image(playing: Bool) -> NSImage {
        let name = playing ? "record.circle.fill" : "record.circle"
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: "Ribs") else {
            return NSImage()
        }
        if playing {
            let red = NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1)   // #FF453A
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [red]))
            let image = base.withSymbolConfiguration(config) ?? base
            image.isTemplate = false          // keep the colour
            return image
        } else {
            let image = base.withSymbolConfiguration(.init(pointSize: 14, weight: .regular)) ?? base
            image.isTemplate = true           // normal black/white menu bar icon
            return image
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
