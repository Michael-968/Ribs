import SwiftUI

struct PlaybackBar: View {
    @Environment(PlayerEngine.self) private var player

    var body: some View {
        let track = player.current

        HStack(spacing: 24) {
            // Left: artwork + title
            HStack(spacing: 12) {
                ArtworkView(image: track?.artworkData.flatMap { NSImage(data: $0) }, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    if let track {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(track.artist ?? "N/A")
                            .font(.system(size: 12))
                            .foregroundStyle(track.artist == nil ? Theme.tertiary : Theme.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Not Playing")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Centre: controls + seek line
            VStack(spacing: 6) {
                HStack(spacing: 22) {
                    Button { player.toggleShuffle() } label: {
                        TogglePill(label: "SHF", isOn: player.shuffle)
                    }
                    .help("Shuffle")

                    Button { player.previous() } label: {
                        Image(systemName: "backward.end.fill").font(.system(size: 13))
                    }
                    .help("Previous")

                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .frame(width: 24)
                    }
                    .help(player.isPlaying ? "Pause" : "Play")

                    Button { player.next() } label: {
                        Image(systemName: "forward.end.fill").font(.system(size: 13))
                    }
                    .help("Next")

                    Button { player.cycleRepeat() } label: {
                        TogglePill(label: player.repeatMode == .once ? "RPT·1" : "RPT",
                                   isOn: player.repeatMode != .off)
                    }
                    .help("Repeat: \(player.repeatMode.label)")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.text)

                HStack(spacing: 10) {
                    Text(track == nil ? "--:--" : PlayerEngine.clock(player.elapsed))
                        .foregroundStyle(track == nil ? Theme.tertiary : Theme.accent)
                        .frame(width: 48, alignment: .trailing)
                    SeekLine()
                    Text(track == nil ? "--:--" : PlayerEngine.clock(player.duration))
                        .foregroundStyle(Theme.tertiary)
                        .frame(width: 48, alignment: .leading)
                }
                .font(Theme.mono(11))
            }
            .frame(width: 460)
            .disabled(track == nil)
            .opacity(track == nil ? 0.45 : 1)

            // Right: file details
            VStack(alignment: .trailing, spacing: 3) {
                if let track {
                    Text(formatLine(track))
                    Text(qualityLine(track))
                } else {
                    Text("No source")
                }
            }
            .font(Theme.mono(11))
            .foregroundStyle(Theme.tertiary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .frame(height: 76)
        .glassPanel()
    }

    private func formatLine(_ t: Track) -> String {
        if let kbps = t.bitrate { return "\(t.format) · \(kbps) kbps" }
        return t.format
    }

    private func qualityLine(_ t: Track) -> String {
        var parts: [String] = []
        if let rate = t.sampleRate {
            parts.append(String(format: "%g kHz", (rate / 100).rounded() / 10))
        }
        switch t.channels {
        case 1: parts.append("Mono")
        case 2: parts.append("Stereo")
        case let n?: parts.append("\(n) ch")
        default: break
        }
        return parts.joined(separator: " · ")
    }
}

/// Thin line with tick marks every 10% and a position marker. Drag or click to seek.
struct SeekLine: View {
    @Environment(PlayerEngine.self) private var player
    @State private var dragProgress: Double?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let live = player.duration > 0 ? player.elapsed / player.duration : 0
            let progress = min(max(dragProgress ?? live, 0), 1)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.tertiary.opacity(0.4))
                    .frame(height: 1)

                ForEach(0...10, id: \.self) { i in
                    Rectangle()
                        .fill(Theme.tertiary.opacity(0.5))
                        .frame(width: 1, height: 7)
                        .offset(x: width * Double(i) / 10)
                }

                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: width * progress, height: 1)

                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.accent)
                    .frame(width: 2, height: 11)
                    .offset(x: width * progress - 1)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragProgress = min(max($0.location.x / width, 0), 1) }
                    .onEnded { value in
                        let p = min(max(value.location.x / width, 0), 1)
                        player.seek(to: p * player.duration)
                        dragProgress = nil
                    }
            )
        }
        .frame(height: 13)
    }
}
