import SwiftUI

struct SongsView: View {
    let tracks: [Track]
    let onAdd: () -> Void
    let onDelete: (Track) -> Void

    private var sorted: [Track] {
        tracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "Songs",
                       subtitle: "\(tracks.count) songs · \(formattedTotal(tracks))") {
                AddMenu(onAdd: onAdd)
            }
            FadedSeparator()

            if tracks.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("Your library is empty").font(.system(size: 19, weight: .semibold))
                    Text("Drag audio files here, or use + to add them. Hold Option while dragging to copy instead of move.")
                        .foregroundStyle(Theme.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                TrackList(tracks: sorted, onDelete: onDelete)
            }
        }
    }
}

/// Column headers + rows. `tracks` is both the display order and the play queue.
struct TrackList: View {
    let tracks: [Track]
    let onDelete: (Track) -> Void

    @Environment(PlayerEngine.self) private var player
    @State private var selectedID: Track.ID?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Color.clear.frame(width: 28, height: 1)
                Text("Title").frame(maxWidth: .infinity, alignment: .leading)
                Text("Artist").frame(maxWidth: .infinity, alignment: .leading)
                Text("Time").frame(width: 56, alignment: .trailing)
                Text("Date Added").frame(width: 120, alignment: .leading)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.tertiary)
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(tracks) { track in
                        TrackRow(track: track,
                                 isCurrent: player.current?.id == track.id,
                                 isPlaying: player.isPlaying,
                                 isSelected: selectedID == track.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {                   // double-click = play
                                selectedID = track.id
                                player.play(track, from: tracks)
                            }
                            .simultaneousGesture(TapGesture().onEnded { // single click = select
                                selectedID = track.id
                            })
                            .contextMenu {
                                Button("Play") { player.play(track, from: tracks) }
                                Button("Show in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([track.fileURL])
                                }
                                Divider()
                                Button("Move to Trash", role: .destructive) {
                                    if selectedID == track.id { selectedID = nil }
                                    onDelete(track)
                                }
                            }
                    }
                }
                .padding(.top, 6)
            }
        }
    }
}

/// One song row.
struct TrackRow: View {
    let track: Track
    var isCurrent = false
    var isPlaying = false
    var isSelected = false
    @Environment(\.colorScheme) private var scheme

    private var titleColor: Color {
        if isSelected { return Theme.selectedText }
        return isCurrent ? Theme.accent : Theme.text
    }

    private func detailColor(_ normal: Color) -> Color {
        isSelected ? Theme.selectedText.opacity(0.85) : normal
    }

    var body: some View {
        HStack(spacing: 16) {
            ArtworkView(image: track.artworkData.flatMap { NSImage(data: $0) }, size: 28)

            HStack(spacing: 8) {
                Text(track.title)
                    .foregroundStyle(titleColor)
                    .fontWeight(isCurrent && scheme == .light ? .semibold : .regular)
                    .lineLimit(1)
                if isCurrent {
                    Image(systemName: "waveform")
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? Theme.selectedText : Theme.accent)
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(track.artist ?? "N/A")
                .foregroundStyle(detailColor(track.artist == nil ? Theme.tertiary : Theme.secondary))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(track.durationText)
                .font(Theme.mono(12))
                .foregroundStyle(detailColor(Theme.secondary))
                .frame(width: 56, alignment: .trailing)
            Text(track.dateAdded, format: .dateTime.day().month(.abbreviated).year())
                .font(.system(size: 12))
                .foregroundStyle(detailColor(Theme.tertiary))
                .frame(width: 120, alignment: .leading)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: 39)
        .highlight(isSelected ? .selected : (isCurrent ? .playing : nil))
        .overlay(alignment: .bottom) {
            if !isSelected && !isCurrent {
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
        }
    }
}
