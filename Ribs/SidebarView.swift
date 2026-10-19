import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case songs
    case albums
    case playlist(UUID)
}

struct SidebarView: View {
    @Binding var selection: SidebarItem
    @Binding var search: String

    @Environment(\.modelContext) private var context
    @Query(sort: \Playlist.createdAt) private var playlists: [Playlist]

    @State private var renamingID: UUID?
    @State private var draftName = ""
    @FocusState private var renameFocused: Bool
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            searchField
                .padding(.bottom, 10)

            sectionLabel("Library")
            item("Songs", .songs)
            item("Albums", .albums)

            sectionLabel("Playlists").padding(.top, 10)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(playlists) { playlistRow($0) }

                    Button(action: newPlaylist) {
                        HStack(spacing: 10) {
                            Image(systemName: "plus").font(.system(size: 12))
                            Text("New Playlist")
                        }
                        .foregroundStyle(Theme.tertiary)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollIndicators(.never)
        }
        .font(.system(size: 14))
        .padding(.top, 40)
        .padding(12)
        .frame(width: 232)
        .frame(maxHeight: .infinity)
        .glassPanel()
        .background {
            // Invisible button so Cmd + F jumps to search
            Button("Find") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
        }
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.tertiary)
            TextField("Search", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onExitCommand {                      // Esc clears
                    search = ""
                    searchFocused = false
                }
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background {
            RoundedRectangle(cornerRadius: 8).fill(Theme.text.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(searchFocused ? Theme.selectedStroke : Theme.hairline, lineWidth: 1)
        }
    }

    // MARK: Rows

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.tertiary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func item(_ label: String, _ value: SidebarItem) -> some View {
        let isOn = selection == value
        return Button { selection = value } label: {
            Text(label)
                .foregroundStyle(isOn ? Theme.selectedText : Theme.text)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .contentShape(Rectangle())
                .highlight(isOn ? .selected : nil, radius: 10)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func playlistRow(_ playlist: Playlist) -> some View {
        if renamingID == playlist.id {
            TextField("Playlist name", text: $draftName)
                .textFieldStyle(.plain)
                .focused($renameFocused)
                .onSubmit { commitRename(playlist) }
                .onExitCommand { renamingID = nil }          // Esc cancels
                .onChange(of: renameFocused) {
                    if !renameFocused { commitRename(playlist) }
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .highlight(.editing, radius: 10)
                .onAppear { renameFocused = true }
        } else {
            let isOn = selection == .playlist(playlist.id)
            Button { selection = .playlist(playlist.id) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "music.note.list").font(.system(size: 12))
                    Text(playlist.name).lineLimit(1)
                }
                .foregroundStyle(isOn ? Theme.selectedText : Theme.text)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .contentShape(Rectangle())
                .highlight(isOn ? .selected : nil, radius: 10)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Rename") { startRename(playlist) }
                Divider()
                Button("Delete Playlist", role: .destructive) { delete(playlist) }
            }
            // Drop songs dragged from a list onto the playlist to add them
            .dropDestination(for: String.self) { items, _ in
                add(items, to: playlist)
            }
        }
    }

    // MARK: Actions

    private func newPlaylist() {
        let playlist = Playlist(name: "Untitled Playlist")
        context.insert(playlist)
        try? context.save()
        selection = .playlist(playlist.id)
        startRename(playlist)
    }

    private func startRename(_ playlist: Playlist) {
        draftName = playlist.name
        renamingID = playlist.id
    }

    private func commitRename(_ playlist: Playlist) {
        guard renamingID == playlist.id else { return }
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { playlist.name = name }
        renamingID = nil
        try? context.save()
    }

    private func delete(_ playlist: Playlist) {
        if selection == .playlist(playlist.id) { selection = .songs }
        context.delete(playlist)        // songs stay in the library
        try? context.save()
    }

    private func add(_ items: [String], to playlist: Playlist) -> Bool {
        let ids = items.compactMap(UUID.init(uuidString:))
        guard !ids.isEmpty else { return false }
        for id in ids where !playlist.trackIDs.contains(id) {
            playlist.trackIDs.append(id)
        }
        try? context.save()
        return true
    }
}
