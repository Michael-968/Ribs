import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct EditInfoSheet: View {
    let track: Track

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var artist = ""
    @State private var album = ""
    @State private var artwork: Data?
    @State private var artworkChanged = false
    @State private var showImagePicker = false

    /// File name without extension, used when the file has no title tag.
    private var fileStem: String { (track.fileName as NSString).deletingPathExtension }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit Info")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 20) {
                // Artwork + pencil
                ZStack(alignment: .bottomTrailing) {
                    ArtworkView(image: artwork.flatMap { NSImage(data: $0) }, size: 146)

                    Menu {
                        Button("Choose Image…") { showImagePicker = true }
                        if artwork != track.tagArtwork {
                            Button("Use Original Artwork") {
                                artwork = track.tagArtwork
                                artworkChanged = true
                            }
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.regularMaterial))
                            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                            .contentShape(Circle())
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .padding(10)
                    .help("Change artwork")
                }

                // Text fields
                VStack(alignment: .leading, spacing: 10) {
                    field("Title", $title, hint: track.tagTitle ?? fileStem)
                    field("Artist", $artist, hint: track.tagArtist ?? "N/A")
                    field("Album", $album, hint: track.tagAlbum ?? "N/A")
                }
            }

            Text("Changes apply in Ribs only — the original file is not modified.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.tertiary)

            HStack {
                Button("Reset to Original", action: reset)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 472)
        .onAppear(perform: load)
        .fileImporter(isPresented: $showImagePicker, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result { pickImage(url) }
        }
    }

    private func field(_ label: String, _ text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.secondary)
            TextField(hint, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: Actions

    private func load() {
        title = track.title
        artist = track.artist ?? ""
        album = track.album ?? ""
        artwork = track.artworkData
    }

    private func reset() {
        title = track.tagTitle ?? fileStem
        artist = track.tagArtist ?? ""
        album = track.tagAlbum ?? ""
        artwork = track.tagArtwork
        artworkChanged = true
    }

    private func pickImage(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), NSImage(data: data) != nil else { return }
        artwork = data
        artworkChanged = true
    }

    /// Empty or unchanged → no edit stored (the file's own info is used).
    private func cleaned(_ value: String, original: String?) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == original { return nil }
        return trimmed
    }

    private func save() {
        track.editTitle = cleaned(title, original: track.tagTitle ?? fileStem)
        track.editArtist = cleaned(artist, original: track.tagArtist)
        track.editAlbum = cleaned(album, original: track.tagAlbum)
        if artworkChanged {
            track.editArtwork = (artwork == track.tagArtwork) ? nil : artwork
        }
        try? context.save()
        dismiss()
    }
}
