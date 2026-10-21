import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(PlayerEngine.self) private var player
    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Track.dateAdded, order: .reverse) private var tracks: [Track]
    @Query(sort: \Playlist.createdAt) private var playlists: [Playlist]

    @State private var selection: SidebarItem = .songs
    @State private var openAlbum: String?
    @State private var search = ""
    @State private var showImporter = false
    @State private var isDropTarget = false
    @State private var status: String?
    @State private var openQueue = OpenQueue.shared

    /// Songs matching the search (all songs when the search is empty).
    private var visibleTracks: [Track] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tracks }
        return tracks.filter { track in
            track.title.localizedStandardContains(query)
                || (track.artist?.localizedStandardContains(query) ?? false)
                || (track.album?.localizedStandardContains(query) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SidebarView(selection: $selection, search: $search)

                VStack(alignment: .leading, spacing: 0) {
                    if !search.isEmpty && visibleTracks.isEmpty {
                        noResults
                    } else {
                        page
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
            PlaybackBar()
        }
        .padding(12)
        .frame(minWidth: 1000, minHeight: 640)
        .foregroundStyle(Theme.text)
        .containerBackground(Theme.base, for: .window)
        .overlay {
            // Another window in front: fade into the shadows (dark mode only)
            if !appearsActive && colorScheme == .dark {
                Color.black.opacity(0.28)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appearsActive)
        .onAppear {
            // Bring back the last song, paused where you left off
            player.restore(from: tracks.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            })
            handleOpenedFiles()
            handleAutoImport()
        }
        .onChange(of: openQueue.pending) { handleOpenedFiles() }
        .onChange(of: openQueue.autoImport) { handleAutoImport() }
        .onChange(of: selection) { openAlbum = nil }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.audio, .folder],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task { await runImport(urls, copy: false) }
            }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch selection {
        case .songs:
            SongsView(tracks: visibleTracks, onAdd: { showImporter = true }, onDelete: delete)
        case .albums:
            AlbumsView(tracks: visibleTracks, openAlbum: $openAlbum,
                       onAdd: { showImporter = true }, onDelete: delete)
        case .playlist(let id):
            if let playlist = playlists.first(where: { $0.id == id }) {
                PlaylistView(playlist: playlist, allTracks: visibleTracks, onDelete: delete)
            } else {
                SongsView(tracks: visibleTracks, onAdd: { showImporter = true }, onDelete: delete)
            }
        }
    }

    private var noResults: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(Theme.tertiary)
            Text("No results for “\(search)”")
                .font(.system(size: 19, weight: .semibold))
            Text("Searches titles, artists and albums.")
                .foregroundStyle(Theme.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private func runImport(_ urls: [URL], copy: Bool) async {
        let summary = await Importer(context: context).importItems(urls, forceCopy: copy)
        showStatus(summary.message)
    }

    /// Files opened from Finder (double-click / Open With): import, then play.
    private func handleOpenedFiles() {
        let urls = openQueue.pending
        guard !urls.isEmpty else { return }
        openQueue.pending = []

        Task {
            await runImport(urls, copy: false)
            selection = .songs
            search = ""

            guard let name = urls.first?.lastPathComponent else { return }
            let all = (try? context.fetch(FetchDescriptor<Track>())) ?? []
            if let track = all.first(where: { $0.sourceName == name }) {
                let sorted = all.sorted {
                    $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                player.play(track, from: sorted)
            }
        }
    }

    /// New files from Downloads: import quietly, one notification per batch.
    private func handleAutoImport() {
        let urls = openQueue.autoImport
        guard !urls.isEmpty else { return }
        openQueue.autoImport = []

        Task {
            let summary = await Importer(context: context).importItems(urls, forceCopy: false)
            showStatus(summary.message)
            let added = summary.moved + summary.copied + summary.keptOriginal
            if added > 0 { DownloadsWatcher.notify(added: added) }
        }
    }

    private func delete(_ track: Track) {
        player.remove(track)
        for playlist in playlists {
            playlist.trackIDs.removeAll { $0 == track.id }
        }
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

#Preview {
    ContentView()
        .environment(PlayerEngine())
        .modelContainer(for: [Track.self, Playlist.self], inMemory: true)
}
