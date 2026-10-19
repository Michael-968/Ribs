import Foundation
import AppKit

enum LibraryFolder {
    /// ~/Music/Ribs
    static let url: URL = {
        let music = FileManager.default
            .urls(for: .musicDirectory, in: .userDomainMask)[0]
            .resolvingSymlinksInPath()
        return music.appendingPathComponent("Ribs", isDirectory: true)
    }()

    static func ensureExists() throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    static func showInFinder() {
        try? ensureExists()
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// A free file name inside the folder: "Song.mp3", then "Song 2.mp3", …
    static func uniqueDestination(for name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = url.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            candidate = url.appendingPathComponent(newName)
            n += 1
        }
        return candidate
    }
}
