import SwiftUI
import Observation

/// Files waiting to be imported.
@MainActor
@Observable
final class OpenQueue {
    static let shared = OpenQueue()
    var pending: [URL] = []       // opened from Finder → import and play
    var autoImport: [URL] = []    // new in Downloads → import quietly
}

/// Receives "Open With → Ribs" and double-clicks from Finder,
/// and starts the Downloads watcher at launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            DownloadsWatcher.shared.startIfEnabled()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            OpenQueue.shared.pending.append(contentsOf: urls)
            NSApp.activate()
        }
    }
}
