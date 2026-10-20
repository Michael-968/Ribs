import AppKit
import UniformTypeIdentifiers

/// Makes Ribs (or the previous app) the default for common audio formats.
/// macOS always shows its own confirmation; apps can't do this silently.
@MainActor
enum DefaultPlayer {
    static let types: [UTType] = [
        .mp3,
        .mpeg4Audio,                      // M4A / AAC
        .wav,
        .aiff,
        UTType("org.xiph.flac")
    ].compactMap { $0 }

    private static let savedKey = "previousAudioApps"      // format → previous app

    private static var ribsURL: URL { Bundle.main.bundleURL.standardizedFileURL }

    static var isRibsDefault: Bool {
        NSWorkspace.shared.urlForApplication(toOpen: .mp3)?.standardizedFileURL == ribsURL
    }

    /// Switch on: remember the current apps, then make Ribs the default.
    static func makeRibsDefault() async {
        var saved = UserDefaults.standard.dictionary(forKey: savedKey) as? [String: String] ?? [:]
        for type in types {
            if let current = NSWorkspace.shared.urlForApplication(toOpen: type),
               current.standardizedFileURL != ribsURL {
                saved[type.identifier] = current.path
            }
            try? await NSWorkspace.shared.setDefaultApplication(at: ribsURL, toOpen: type)
        }
        UserDefaults.standard.set(saved, forKey: savedKey)
    }

    /// Switch off: give each format back to the app it had before (or Music).
    static func restorePrevious() async {
        let saved = UserDefaults.standard.dictionary(forKey: savedKey) as? [String: String] ?? [:]
        let music = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music")
        for type in types {
            guard let target = saved[type.identifier].map({ URL(fileURLWithPath: $0) }) ?? music
            else { continue }
            try? await NSWorkspace.shared.setDefaultApplication(at: target, toOpen: type)
        }
    }
}
