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
    @State private var tapesLock = TapesLock.shared

    // MARK: Which tracks belong where

    private var musicTracks: [Track] { tracks.filter { $0.collection == nil } }

    private func folderTracks(_ collection: String) -> [Track] {
        tracks.filter { $0.collection == collection }
    }

    /// Applies the search box (titles, artists, albums).
    private func searched(_ list: [Track]) -> [Track] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return list }
        return list.filter { track in
            track.title.localizedStandardContains(query)
                || (track.artist?.localizedStandardContains(query) ?? false)
                || (track.album?.localizedStandardContains(query) ?? false)
        }
    }

    /// Where new imports go, based on the page you're on.
    private var currentCollection: String? {
        switch selection {
        case .tapes:   TrackCollection.tapes
        case .archive: TrackCollection.archive
        default:       nil
        }
    }

    private var showNoResults: Bool {
        guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch selection {
        case .songs, .albums: return searched(musicTracks).isEmpty
        case .archive:        return searched(folderTracks(TrackCollection.archive)).isEmpty
        case .tapes:          return tapesLock.isAccessible
                                  && searched(folderTracks(TrackCollection.tapes)).isEmpty
        case .playlist:       return false
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SidebarView(selection: $selection, search: $search)

                VStack(alignment: .leading, spacing: 0) {
                    if showNoResults {
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
                    if selection == .tapes && !tapesLock.isAccessible { return false }
                    let copy = NSEvent.modifierFlags.contains(.option)   // Option-drag = copy
                    let collection = currentCollection
                    Task { await runImport(urls, copy: copy, collection: collection) }
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
            // Bring back the last song, paused where you left off (never a locked tape)
            let restorable = tracks.filter {
                !(tapesLock.isEnabled && $0.collection == TrackCollection.tapes)
            }
            player.restore(from: restorable.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            })
            handleOpenedFiles()
            handleAutoImport()
            removeMissingFiles()
        }
        .onDisappear {
            // Window closed with the red button: lock Tapes (music keeps playing)
            tapesLock.lock()
        }
        .onChange(of: appearsActive) {
            // Back in Ribs: drop songs whose files were deleted in Finder
            if appearsActive { removeMissingFiles() }
        }
        .onChange(of: openQueue.pending) { handleOpenedFiles() }
        .onChange(of: openQueue.autoImport) { handleAutoImport() }
        .onChange(of: tapesLock.isUnlocked) {
            // Lock button / Mac screen lock stops a tape that's playing
            if !tapesLock.isAccessible && tapesLock.lockStopsPlayback
                && player.current?.collection == TrackCollection.tapes {
                player.stop()
            }
        }
        .onChange(of: selection) { oldValue, newValue in
            openAlbum = nil
            // Leaving Tapes locks it again (a playing tape keeps playing)
            if oldValue == .tapes && newValue != .tapes { tapesLock.lock() }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.audio, .folder],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                let collection = currentCollection
                Task { await runImport(urls, copy: false, collection: collection) }
            }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch selection {
        case .songs:
            SongsView(tracks: searched(musicTracks), onAdd: { showImporter = true }, onDelete: delete)
        case .albums:
            AlbumsView(tracks: searched(musicTracks), openAlbum: $openAlbum,
                       onAdd: { showImporter = true }, onDelete: delete)
        case .playlist(let id):
            if let playlist = playlists.first(where: { $0.id == id }) {
                PlaylistView(playlist: playlist, allTracks: searched(musicTracks), onDelete: delete)
            } else {
                SongsView(tracks: searched(musicTracks), onAdd: { showImporter = true }, onDelete: delete)
            }
        case .tapes:
            FolderView(kind: .tapes,
                       tracks: searched(folderTracks(TrackCollection.tapes)),
                       onAdd: { showImporter = true }, onDelete: delete)
        case .archive:
            FolderView(kind: .archive,
                       tracks: searched(folderTracks(TrackCollection.archive)),
                       onAdd: { showImporter = true }, onDelete: delete)
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

    private func runImport(_ urls: [URL], copy: Bool, collection: String? = nil) async {
        let summary = await Importer(context: context)
            .importItems(urls, forceCopy: copy, collection: collection)
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
                let sameSection = all.filter { $0.collection == track.collection }
                let sorted = sameSection.sorted {
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

    /// Removes library entries whose audio file no longer exists (all sections).
    private func removeMissingFiles() {
        let fm = FileManager.default
        var removed = 0
        for track in Array(tracks) where !fm.fileExists(atPath: track.fileURL.path) {
            player.remove(track)
            for playlist in playlists {
                playlist.trackIDs.removeAll { $0 == track.id }
            }
            context.delete(track)
            removed += 1
        }
        if removed > 0 {
            try? context.save()
            showStatus(removed == 1 ? "1 missing file removed from library"
                                    : "\(removed) missing files removed from library")
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
