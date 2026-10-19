import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(PlayerEngine.self) private var player
    @Query(sort: \Track.dateAdded, order: .reverse) private var tracks: [Track]

    @State private var selectedID: Track.ID?
    @State private var showImporter = false
    @State private var isDropTarget = false
    @State private var status: String?

    private var sortedTracks: [Track] {
        tracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private var totalTime: String {
        let s = Int(tracks.reduce(0) { $0 + $1.duration })
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                sidebar
                mainArea
            }
            PlaybackBar()
        }
        .padding(12)
        .frame(minWidth: 1000, minHeight: 640)
        .foregroundStyle(Theme.text)
        .containerBackground(Theme.base, for: .window)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.audio, .folder],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task { await runImport(urls, copy: false) }
            }
        }
    }

    // MARK: Sidebar (placeholder until stage 4)

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ribs")
                .font(.system(size: 15, weight: .semibold))
                .padding(.bottom, 14)
            Text("Library")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.tertiary)
                .padding(.horizontal, 10)
            Text("Songs")
                .foregroundStyle(Theme.selectedText)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .highlight(.selected, radius: 10)
            Text("Albums")
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            Spacer()
        }
        .font(.system(size: 14))
        .padding(.top, 40)
        .padding(12)
        .frame(width: 232)
        .frame(maxHeight: .infinity)
        .glassPanel()
    }

    // MARK: Main area

    private var mainArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("Songs").font(.system(size: 22, weight: .bold))
                Text("\(tracks.count) songs · \(totalTime)")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.tertiary)
                Spacer()
                Menu {
                    Button("Add Files or Folders…") { showImporter = true }
                        .keyboardShortcut("o")
                    Divider()
                    Button("Show Ribs Folder in Finder") { LibraryFolder.showInFinder() }
                } label: {
                    Image(systemName: "plus")
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Add music")
            }
            .frame(height: 52)

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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedTracks) { track in
                            TrackRow(track: track,
                                     isCurrent: player.current?.id == track.id,
                                     isPlaying: player.isPlaying,
                                     isSelected: selectedID == track.id)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {                 // double-click = play
                                    selectedID = track.id
                                    player.play(track, from: sortedTracks)
                                }
                                .simultaneousGesture(TapGesture().onEnded { // single click = select
                                    selectedID = track.id
                                })
                                .contextMenu {
                                    Button("Play") { player.play(track, from: sortedTracks) }
                                    Button("Show in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([track.fileURL])
                                    }
                                    Divider()
                                    Button("Move to Trash", role: .destructive) { delete(track) }
                                }
                        }
                    }
                    .padding(.top, 6)
                }
            }

            if let status {
                Text(status)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.secondary)
                    .padding(.vertical, 8)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let copy = NSEvent.modifierFlags.contains(.option)   // Option-drag = copy
            Task { await runImport(urls, copy: copy) }
            return true
        } isTargeted: { isDropTarget = $0 }
    }

    // MARK: Actions

    private func runImport(_ urls: [URL], copy: Bool) async {
        let summary = await Importer(context: context).importItems(urls, forceCopy: copy)
        showStatus(summary.message)
    }

    private func delete(_ track: Track) {
        if selectedID == track.id { selectedID = nil }
        player.remove(track)
        try? FileManager.default.trashItem(at: track.fileURL, resultingItemURL: nil)
        context.delete(track)
        try? context.save()
        showStatus("Moved to Trash")
    }

    private func showStatus(_ text: String) {
        withAnimation { status = text }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if status == text { withAnimation { status = nil } }
        }
    }
}

// MARK: - One song row

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

#Preview {
    ContentView()
        .environment(PlayerEngine())
        .modelContainer(for: [Track.self, Playlist.self], inMemory: true)
}
