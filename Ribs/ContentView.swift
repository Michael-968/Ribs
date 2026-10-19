import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(PlayerEngine.self) private var player
    @Query(sort: \Track.dateAdded, order: .reverse) private var tracks: [Track]

    @State private var selection: SidebarItem = .songs
    @State private var openAlbum: String?
    @State private var showImporter = false
    @State private var isDropTarget = false
    @State private var status: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SidebarView(selection: $selection)

                VStack(alignment: .leading, spacing: 0) {
                    switch selection {
                    case .songs:
                        SongsView(tracks: tracks,
                                  onAdd: { showImporter = true },
                                  onDelete: delete)
                    case .albums:
                        AlbumsView(tracks: tracks,
                                   openAlbum: $openAlbum,
                                   onAdd: { showImporter = true },
                                   onDelete: delete)
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
        .onChange(of: selection) { openAlbum = nil }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.audio, .folder],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task { await runImport(urls, copy: false) }
            }
        }
    }

    // MARK: Actions

    private func runImport(_ urls: [URL], copy: Bool) async {
        let summary = await Importer(context: context).importItems(urls, forceCopy: copy)
        showStatus(summary.message)
    }

    private func delete(_ track: Track) {
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

#Preview {
    ContentView()
        .environment(PlayerEngine())
        .modelContainer(for: [Track.self, Playlist.self], inMemory: true)
}
