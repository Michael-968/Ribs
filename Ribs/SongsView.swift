//
//  SongsView.swift
//  Ribs
//
//  Created by Michael  Preobrazhensky on 19.10.2026.
//


import SwiftUI
import SwiftData

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
/// Pass a `playlist` to enable reordering and "Remove from Playlist".
struct TrackList: View {
    let tracks: [Track]
    var playlist: Playlist? = nil
    let onDelete: (Track) -> Void

    @Environment(PlayerEngine.self) private var player
    @Environment(\.modelContext) private var context
    @Query(sort: \Playlist.createdAt) private var playlists: [Playlist]
    @State private var selectedID: UUID?
    @State private var editingTrack: Track?

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
                        row(for: track)
                    }
                }
                .padding(.top, 6)
            }
        }
        .sheet(item: $editingTrack) { track in
            EditInfoSheet(track: track)
        }
    }

    private func row(for track: Track) -> some View {
        TrackRow(track: track,
                 isCurrent: player.current?.id == track.id,
                 isPlaying: player.isPlaying,
                 isSelected: selectedID == track.id,
                 isEditing: editingTrack?.id == track.id)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {                       // double-click = play
                selectedID = track.id
                player.play(track, from: tracks)
            }
            .simultaneousGesture(TapGesture().onEnded {     // single click = select
                selectedID = track.id
            })
            .draggable(track.id.uuidString)                 // drag onto a sidebar playlist
            .modifier(ReorderDrop(enabled: playlist != nil) { items in
                reorder(items, onto: track)
            })
            .contextMenu {
                Button("Play") { player.play(track, from: tracks) }
                Button("Edit Info…") {
                    selectedID = track.id
                    editingTrack = track
                }

                Menu("Add to Playlist") {
                    ForEach(playlists) { list in
                        Button(list.name) { add(track, to: list) }
                    }
                    if !playlists.isEmpty { Divider() }
                    Button("New Playlist") {
                        let list = Playlist(name: "Untitled Playlist")
                        list.trackIDs = [track.id]
                        context.insert(list)
                        try? context.save()
                    }
                }

                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([track.fileURL])
                }

                Divider()

                if let playlist {
                    Button("Remove from Playlist") {
                        playlist.trackIDs.removeAll { $0 == track.id }
                        try? context.save()
                    }
                }
                Button("Move to Trash", role: .destructive) {
                    if selectedID == track.id { selectedID = nil }
                    onDelete(track)
                }
            }
    }

    private func add(_ track: Track, to list: Playlist) {
        guard !list.trackIDs.contains(track.id) else { return }
        list.trackIDs.append(track.id)
        try? context.save()
    }

    /// Drop a dragged song onto another song in the playlist to move it there.
    private func reorder(_ items: [String], onto target: Track) -> Bool {
        guard let playlist,
              let raw = items.first,
              let moving = UUID(uuidString: raw),
              moving != target.id,
              let from = playlist.trackIDs.firstIndex(of: moving),
              let targetIndex = playlist.trackIDs.firstIndex(of: target.id)
        else { return false }

        var ids = playlist.trackIDs
        ids.remove(at: from)
        let newTarget = ids.firstIndex(of: target.id) ?? ids.endIndex
        ids.insert(moving, at: from < targetIndex ? newTarget + 1 : newTarget)
        playlist.trackIDs = ids
        try? context.save()
        return true
    }
}

/// Only playlists accept reordering drops (so file drops elsewhere still import).
struct ReorderDrop: ViewModifier {
    let enabled: Bool
    let perform: ([String]) -> Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.dropDestination(for: String.self) { items, _ in perform(items) }
        } else {
            content
        }
    }
}

/// How one song row looks.
struct TrackRow: View {
    let track: Track
    var isCurrent = false
    var isPlaying = false
    var isSelected = false
    var isEditing = false
    @Environment(\.colorScheme) private var scheme

    private var titleColor: Color {
        if isEditing { return Theme.highlight }
        if isSelected { return Theme.selectedText }
        return isCurrent ? Theme.accent : Theme.text
    }

    private func detailColor(_ normal: Color) -> Color {
        (isSelected && !isEditing) ? Theme.selectedText.opacity(0.85) : normal
    }

    private var rowHighlight: Highlight? {
        if isEditing { return .editing }
        if isSelected { return .selected }
        return isCurrent ? .playing : nil
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
                        .foregroundStyle(isSelected && !isEditing ? Theme.selectedText : Theme.accent)
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
        .highlight(rowHighlight)
        .overlay(alignment: .bottom) {
            if rowHighlight == nil {
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
        }
    }
}
