import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlayerEngine.self) private var player
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let track = player.current

        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(track != nil && player.isPlaying ? Theme.accent : Theme.tertiary)
                    .frame(width: 7, height: 7)
                Text(track == nil ? "Not Playing" : "Now Playing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                if let track {
                    Text(formatLine(track))
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.tertiary)
                }
            }

            // Artwork + title
            HStack(spacing: 16) {
                ArtworkView(image: track?.artworkData.flatMap { NSImage(data: $0) }, size: 92)
                VStack(alignment: .leading, spacing: 4) {
                    Text(track?.title ?? "Nothing playing")
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)
                    Text(track.map { $0.artist ?? "N/A" } ?? "Double-click a song in Ribs")
                        .font(.system(size: 14))
                        .foregroundStyle(track?.artist == nil ? Theme.tertiary : Theme.secondary)
                        .lineLimit(1)
                }
            }

            // Seek line + times
            VStack(spacing: 8) {
                SeekLine()
                HStack {
                    Text(track == nil ? "--:--" : PlayerEngine.clock(player.elapsed))
                        .foregroundStyle(track == nil ? Theme.tertiary : Theme.accent)
                    Spacer()
                    Text(track == nil ? "--:--" : PlayerEngine.clock(player.duration))
                        .foregroundStyle(Theme.tertiary)
                }
                .font(Theme.mono(13))
            }
            .disabled(track == nil)
            .opacity(track == nil ? 0.45 : 1)

            // Controls
            HStack {
                Button { player.toggleShuffle() } label: {
                    TogglePill(label: "SHF", isOn: player.shuffle)
                }
                .help("Shuffle")

                Spacer()

                HStack(spacing: 30) {
                    Button { player.previous() } label: {
                        Image(systemName: "backward.end.fill").font(.system(size: 15))
                    }
                    .help("Previous")

                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .frame(width: 28)
                    }
                    .help(player.isPlaying ? "Pause" : "Play")

                    Button { player.next() } label: {
                        Image(systemName: "forward.end.fill").font(.system(size: 15))
                    }
                    .help("Next")
                }

                Spacer()

                Button { player.cycleRepeat() } label: {
                    TogglePill(label: player.repeatMode == .once ? "RPT·1" : "RPT",
                               isOn: player.repeatMode != .off)
                }
                .help("Repeat: \(player.repeatMode.label)")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.text)
            .disabled(track == nil)
            .opacity(track == nil ? 0.45 : 1)

            Divider()

            Button("Show Ribs", action: showMainWindow)
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
        }
        .padding(18)
        .frame(width: 340)
        .foregroundStyle(Theme.text)
    }

    private func formatLine(_ t: Track) -> String {
        if let kbps = t.bitrate { return "\(t.format) · \(kbps) kbps" }
        return t.format
    }

    /// Bring the main window to the front, or reopen it if it was closed.
    private func showMainWindow() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}
