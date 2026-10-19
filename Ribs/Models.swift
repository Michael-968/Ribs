import Foundation
import SwiftData

@Model
final class Track {
    @Attribute(.unique) var id: UUID
    var fileName: String        // the file inside Music → Ribs
    var sourceName: String      // original file name, used to spot duplicates
    var fileSize: Int64
    var dateAdded: Date
    var duration: Double        // seconds
    var format: String          // MP3, M4A, FLAC…

    // Read from the file's tags (nil = missing)
    var tagTitle: String?
    var tagArtist: String?
    var tagAlbum: String?
    @Attribute(.externalStorage) var tagArtwork: Data?

    // Edits made in Ribs (nil = not edited). The audio file is never changed.
    var editTitle: String?
    var editArtist: String?
    var editAlbum: String?
    @Attribute(.externalStorage) var editArtwork: Data?

    // Technical details for the playback bar
    var bitrate: Int?           // kbps
    var sampleRate: Double?     // Hz
    var channels: Int?

    init(fileName: String, sourceName: String, fileSize: Int64, duration: Double, format: String) {
        self.id = UUID()
        self.fileName = fileName
        self.sourceName = sourceName
        self.fileSize = fileSize
        self.dateAdded = .now
        self.duration = duration
        self.format = format
    }
}

extension Track {
    /// What the app shows: your edit first, then the file's tag, then the file name.
    var title: String { editTitle ?? tagTitle ?? (fileName as NSString).deletingPathExtension }
    var artist: String? { editArtist ?? tagArtist }      // nil → shown as "N/A"
    var album: String? { editAlbum ?? tagAlbum }
    var artworkData: Data? { editArtwork ?? tagArtwork } // nil → black square
    var fileURL: URL { LibraryFolder.url.appendingPathComponent(fileName) }

    var durationText: String {
        let s = Int(duration.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var trackIDs: [UUID]        // keeps your custom order

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.trackIDs = []
    }
}
