import SwiftUI
import Observation

/// Files that Finder asked Ribs to open, waiting to be imported.
@MainActor
@Observable
final class OpenQueue {
    static let shared = OpenQueue()
    var pending: [URL] = []
}

/// Receives "Open With → Ribs" and double-clicks from Finder.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            OpenQueue.shared.pending.append(contentsOf: urls)
            NSApp.activate()
        }
    }
}
