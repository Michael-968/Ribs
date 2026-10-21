import Foundation
import AVFoundation
import SwiftData

struct ImportSummary {
    var moved = 0, copied = 0, keptOriginal = 0, duplicates = 0, unsupported = 0, failed = 0

    var message: String {
        var parts: [String] = []
        if moved > 0 { parts.append("\(moved) moved") }
        if copied > 0 { parts.append("\(copied) copied") }
        if keptOriginal > 0 { parts.append("\(keptOriginal) copied (original kept)") }
        if duplicates > 0 { parts.append("\(duplicates) already in library") }
        if unsupported > 0 { parts.append("\(unsupported) not supported") }
        if failed > 0 { parts.append("\(failed) failed") }
        return parts.isEmpty ? "Nothing to import" : parts.joined(separator: " · ")
    }
}

@MainActor
final class Importer {
    private enum Outcome { case moved, copied, keptOriginal, duplicate, unsupported, failed }

    private let context: ModelContext
    private let fm = FileManager.default

    init(context: ModelContext) { self.context = context }

    /// Imports files and folders. Plain drag = move; forceCopy (Option-drag) = copy.
    /// `collection`: nil = Music, or TrackCollection.tapes / .archive.
    func importItems(_ urls: [URL], forceCopy: Bool, collection: String? = nil) async -> ImportSummary {
        var summary = ImportSummary()
        try? LibraryFolder.ensureExists()

        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            for file in files(in: url) {
                switch await importFile(file, forceCopy: forceCopy, collection: collection) {
                case .moved: summary.moved += 1
                case .copied: summary.copied += 1
                case .keptOriginal: summary.keptOriginal += 1
                case .duplicate: summary.duplicates += 1
                case .unsupported: summary.unsupported += 1
                case .failed: summary.failed += 1
                }
            }
        }
        try? context.save()
        return summary
    }

    /// A single file, or every file inside a dropped folder.
    private func files(in url: URL) -> [URL] {
        let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        guard isFolder else { return [url] }
        let walker = fm.enumerator(at: url,
                                   includingPropertiesForKeys: [.isRegularFileKey],
                                   options: [.skipsHiddenFiles, .skipsPackageDescendants])
        return (walker?.allObjects as? [URL] ?? []).filter {
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
        }
    }

    private func importFile(_ source: URL, forceCopy: Bool, collection: String?) async -> Outcome {
        // 1. Can macOS play it?
        let asset = AVURLAsset(url: source)
        guard (try? await asset.load(.isPlayable)) == true else { return .unsupported }

        // 2. Already in the library?
        let name = source.lastPathComponent
        let size = Int64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let existing = FetchDescriptor<Track>(predicate: #Predicate {
            $0.sourceName == name && $0.fileSize == size
        })
        if ((try? context.fetchCount(existing)) ?? 0) > 0 { return .duplicate }

        // 3. Read the tags before touching the file
        let info = await TagReader.read(asset)

        // 4. Move or copy into Music → Ribs
        var destination: URL
        var outcome: Outcome
        if source.deletingLastPathComponent().resolvingSymlinksInPath() == LibraryFolder.url {
            destination = source                        // already in the Ribs folder
            outcome = .moved
        } else {
            destination = LibraryFolder.uniqueDestination(for: name)
            do {
                if forceCopy || mustCopy(source) {
                    try fm.copyItem(at: source, to: destination)
                    outcome = .copied
                } else {
                    do {
                        try fm.moveItem(at: source, to: destination)
                        outcome = .moved
                    } catch {
                        // macOS refused the move → copy instead, original stays where it was
                        try fm.copyItem(at: source, to: destination)
                        outcome = .keptOriginal
                    }
                }
            } catch {
                return .failed
            }
        }

        // 5. Save it in the library
        let track = Track(fileName: destination.lastPathComponent,
                          sourceName: name,
                          fileSize: size,
                          duration: info.duration,
                          format: source.pathExtension.uppercased())
        track.collection = collection
        track.tagTitle = info.title
        track.tagArtist = info.artist
        track.tagAlbum = info.album
        track.tagArtwork = info.artwork
        track.bitrate = info.bitrate
        track.sampleRate = info.sampleRate
        track.channels = info.channels
        context.insert(track)
        return outcome
    }

    /// Files that must never be moved: iCloud files and other apps' libraries.
    private func mustCopy(_ url: URL) -> Bool {
        if (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true {
            return true
        }
        let path = url.path
        return path.contains("/Music/Music/")          // Apple Music library
            || path.contains("/Music/iTunes/")
            || path.contains("/Library/")              // app data, Voice Memos, etc.
    }
}

// MARK: - Reading tags

struct TagInfo {
    var title: String?
    var artist: String?
    var album: String?
    var artwork: Data?
    var duration: Double = 0
    var bitrate: Int?
    var sampleRate: Double?
    var channels: Int?
}

@MainActor
enum TagReader {
    static func read(_ asset: AVURLAsset) async -> TagInfo {
        var info = TagInfo()

        if let d = try? await asset.load(.duration), d.seconds.isFinite {
            info.duration = d.seconds
        }

        if let meta = try? await asset.load(.commonMetadata) {
            info.title = await text(meta, .commonIdentifierTitle)
            info.artist = await text(meta, .commonIdentifierArtist)
            info.album = await text(meta, .commonIdentifierAlbumName)
            if let art = AVMetadataItem.metadataItems(from: meta, filteredByIdentifier: .commonIdentifierArtwork).first {
                info.artwork = (try? await art.load(.dataValue)) ?? nil
            }
        }

        if let track = (try? await asset.loadTracks(withMediaType: .audio))?.first {
            if let rate = try? await track.load(.estimatedDataRate), rate > 0 {
                info.bitrate = Int((rate / 1000).rounded())
            }
            if let first = (try? await track.load(.formatDescriptions))?.first,
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(first)?.pointee {
                info.sampleRate = asbd.mSampleRate
                info.channels = Int(asbd.mChannelsPerFrame)
            }
        }
        return info
    }

    private static func text(_ meta: [AVMetadataItem], _ id: AVMetadataIdentifier) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: meta, filteredByIdentifier: id).first else { return nil }
        let value = ((try? await item.load(.stringValue)) ?? nil)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }
}
