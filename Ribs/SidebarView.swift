import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case songs
    case albums
    case playlist(UUID)
    case tapes
    case archive
}

struct SidebarView: View {
    @Binding var selection: SidebarItem
    @Binding var search: String

    @Environment(\.modelContext) private var context
    @Query(sort: \Playlist.createdAt) private var playlists: [Playlist]

    @AppStorage("playlistsExpanded") private var playlistsExpanded = true
    @AppStorage("foldersExpanded") private var foldersExpanded = false
    @State private var lock = TapesLock.shared

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

            // Folders: tucked between Library and Playlists
            collapsibleHeader("Folders", expanded: $foldersExpanded)
                .padding(.top, 10)
            if foldersExpanded {
                folderRow(.tapes, collection: TrackCollection.tapes, locked: !lock.isAccessible)
                folderRow(.archive, collection: TrackCollection.archive, locked: false)
            }

            collapsibleHeader("Playlists", expanded: $playlistsExpanded)
                .padding(.top, 10)
            ScrollView {
                if playlistsExpanded {
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
        .task {
            // Don't start with the cursor in the search box
            try? await Task.sleep(for: .milliseconds(100))
            searchFocused = false
            NSApp.keyWindow?.makeFirstResponder(nil)
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
                .focusEffectDisabled()                // no blue system ring
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

    // MARK: Headers & rows

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.tertiary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func collapsibleHeader(_ title: String, expanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { expanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .rotationEffect(.degrees(expanded.wrappedValue ? 90 : 0))
                Spacer()
            }
            .foregroundStyle(Theme.tertiary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private func folderRow(_ kind: FolderKind, collection: String, locked: Bool) -> some View {
        let value: SidebarItem = kind == .tapes ? .tapes : .archive
        let isOn = selection == value
        return Button { selection = value } label: {
            HStack {
                Text(kind.title)
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isOn ? Theme.selectedText : Theme.tertiary)
                }
            }
            .foregroundStyle(isOn ? Theme.selectedText : Theme.text)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .contentShape(Rectangle())
            .highlight(isOn ? .selected : nil, radius: 10)
        }
        .buttonStyle(.plain)
        // Drop songs onto a folder to move them there
        .dropDestination(for: String.self) { items, _ in
            _ = move(items, to: collection)
        }
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
                Text(playlist.name)
                    .lineLimit(1)
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
                _ = add(items, to: playlist)
            }
        }
    }

    // MARK: Actions

    private func newPlaylist() {
        playlistsExpanded = true
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

    private func move(_ items: [String], to collection: String?) -> Bool {
        let ids = Set(items.compactMap(UUID.init(uuidString:)))
        guard !ids.isEmpty else { return false }
        let all = (try? context.fetch(FetchDescriptor<Track>())) ?? []
        for track in all where ids.contains(track.id) {
            track.collection = collection
        }
        try? context.save()
        return true
    }
}
