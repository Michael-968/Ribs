import SwiftUI

struct Album: Identifiable {
    let id: String              // album name, lower-cased
    let title: String
    let artist: String?         // nil → "N/A"; mixed artists → "Various Artists"
    let tracks: [Track]

    var artwork: Data? { tracks.first { $0.artworkData != nil }?.artworkData }
    var summary: String {
        let minutes = Int((tracks.reduce(0) { $0 + $1.duration } / 60).rounded())
        return "\(tracks.count) songs · \(minutes) min"
    }

    static func group(_ tracks: [Track]) -> [Album] {
        let withAlbum = tracks.filter { $0.album != nil }
        let grouped = Dictionary(grouping: withAlbum) { $0.album!.lowercased() }
        return grouped.map { key, items in
            let sorted = items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            let artists = Set(items.compactMap(\.artist))
            let artist: String? = artists.count == 1 ? artists.first : (artists.isEmpty ? nil : "Various Artists")
            return Album(id: key, title: sorted.first?.album ?? key, artist: artist, tracks: sorted)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}

struct AlbumsView: View {
    let tracks: [Track]
    @Binding var openAlbum: String?
    let onAdd: () -> Void
    let onDelete: (Track) -> Void

    @Environment(PlayerEngine.self) private var player

    var body: some View {
        let albums = Album.group(tracks)

        if let id = openAlbum, let album = albums.first(where: { $0.id == id }) {
            AlbumDetailView(album: album, onBack: { openAlbum = nil }, onDelete: onDelete)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(title: "Albums", subtitle: "\(albums.count) albums") {
                    AddMenu(onAdd: onAdd)
                }
                FadedSeparator()

                if albums.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("No albums yet").font(.system(size: 19, weight: .semibold))
                        Text("Songs appear here when their files include an album name.")
                            .foregroundStyle(Theme.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 22)], spacing: 22) {
                            ForEach(albums) { album in
                                Button { openAlbum = album.id } label: {
                                    AlbumCard(album: album,
                                              isCurrent: album.tracks.contains { $0.id == player.current?.id },
                                              isPlaying: player.isPlaying)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
    }
}

struct AlbumCard: View {
    let album: Album
    var isCurrent = false
    var isPlaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverImage(data: album.artwork)
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Theme.playingStroke, lineWidth: 1.5)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(album.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isCurrent ? Theme.accent : Theme.text)
                        .lineLimit(1)
                    if isCurrent {
                        Image(systemName: "waveform")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.accent)
                            .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                    }
                }
                Text(album.artist ?? "N/A")
                    .font(.system(size: 12))
                    .foregroundStyle(album.artist == nil ? Theme.tertiary : Theme.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}

struct AlbumDetailView: View {
    let album: Album
    let onBack: () -> Void
    let onDelete: (Track) -> Void

    @Environment(PlayerEngine.self) private var player

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                Label("Albums", systemImage: "chevron.left")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: 40)

            HStack(spacing: 24) {
                CoverImage(data: album.artwork).frame(width: 160)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Album")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.tertiary)
                    Text(album.title)
                        .font(.system(size: 36, weight: .bold))
                        .lineLimit(2)
                    Text(album.artist ?? "N/A")
                        .font(.system(size: 15))
                        .foregroundStyle(album.artist == nil ? Theme.tertiary : Theme.secondary)
                    Text(album.summary)
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.tertiary)
                    HStack(spacing: 10) {
                        PillButton(title: "Play", icon: "play.fill", primary: true) {
                            player.playAll(album.tracks, shuffled: false)
                        }
                        PillButton(title: "Shuffle", icon: "shuffle") {
                            player.playAll(album.tracks, shuffled: true)
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .padding(.bottom, 22)

            FadedSeparator()
            TrackList(tracks: album.tracks, onDelete: onDelete)
        }
    }
}
