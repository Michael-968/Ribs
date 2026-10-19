import SwiftUI

struct PlaylistView: View {
    let playlist: Playlist
    let allTracks: [Track]
    let onDelete: (Track) -> Void

    @Environment(PlayerEngine.self) private var player

    /// Songs in the playlist's own order (deleted songs are skipped).
    private var tracks: [Track] {
        let byID = Dictionary(uniqueKeysWithValues: allTracks.map { ($0.id, $0) })
        return playlist.trackIDs.compactMap { byID[$0] }
    }

    var body: some View {
        let songs = tracks
        let minutes = Int((songs.reduce(0) { $0 + $1.duration } / 60).rounded())

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 24) {
                PlaylistCover(tracks: songs).frame(width: 160)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Playlist")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.tertiary)
                    Text(playlist.name)
                        .font(.system(size: 36, weight: .bold))
                        .lineLimit(2)
                    Text("\(songs.count) songs · \(minutes) min")
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.tertiary)
                    HStack(spacing: 10) {
                        PillButton(title: "Play", icon: "play.fill", primary: true) {
                            player.playAll(songs, shuffled: false)
                        }
                        PillButton(title: "Shuffle", icon: "shuffle") {
                            player.playAll(songs, shuffled: true)
                        }
                    }
                    .padding(.top, 10)
                    .disabled(songs.isEmpty)
                    .opacity(songs.isEmpty ? 0.45 : 1)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 22)

            FadedSeparator()

            if songs.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("This playlist is empty").font(.system(size: 19, weight: .semibold))
                    Text("Right-click a song → Add to Playlist, or drag songs onto this playlist in the sidebar.")
                        .foregroundStyle(Theme.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                TrackList(tracks: songs, playlist: playlist, onDelete: onDelete)
            }
        }
    }
}

/// 2×2 grid of the first four artworks, or a single cover if there are fewer.
struct PlaylistCover: View {
    let tracks: [Track]

    var body: some View {
        let arts = Array(tracks.compactMap(\.artworkData).prefix(4))

        Group {
            if arts.count == 4 {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        CoverImage(data: arts[0], radius: 0)
                        CoverImage(data: arts[1], radius: 0)
                    }
                    GridRow {
                        CoverImage(data: arts[2], radius: 0)
                        CoverImage(data: arts[3], radius: 0)
                    }
                }
            } else {
                CoverImage(data: arts.first, radius: 0)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}
