import Foundation
import UserNotifications
import UniformTypeIdentifiers

/// Watches the Downloads folder and queues new audio files for import.
/// Off by default; switched on in Ribs → Settings.
@MainActor
final class DownloadsWatcher {
    static let shared = DownloadsWatcher()
    static let enabledKey = "autoImportDownloads"

    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String> = []
    private var scanTask: Task<Void, Never>?

    private let folder = FileManager.default
        .urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        .resolvingSymlinksInPath()

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    func startIfEnabled() {
        if isEnabled { start() }
    }

    func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: Self.enabledKey)
        if on {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound]) { _, _ in }
            start()
        } else {
            stop()
        }
    }

    // MARK: Watching

    private func start() {
        guard source == nil else { return }
        known = Set(audioFiles().map(\.path))          // ignore files already there

        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
                                                            eventMask: [.write, .rename],
                                                            queue: .main)
        src.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleScan() }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    private func stop() {
        source?.cancel()
        source = nil
        scanTask?.cancel()
    }

    /// Wait a few seconds after the last change so downloads can finish.
    private func scheduleScan() {
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.scan()
        }
    }

    private func scan() {
        let current = audioFiles()
        let new = current.filter { !known.contains($0.path) }
        known = Set(current.map(\.path))
        guard !new.isEmpty else { return }
        OpenQueue.shared.autoImport.append(contentsOf: new)
    }

    /// Finished audio files in Downloads (unfinished downloads aren't audio files yet).
    private func audioFiles() -> [URL] {
        let keys: [URLResourceKey] = [.contentTypeKey, .isRegularFileKey]
        let items = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        return items.filter { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return values?.isRegularFile == true
                && (values?.contentType?.conforms(to: .audio) ?? false)
        }
    }

    // MARK: Notification

    /// One quiet banner per batch.
    static func notify(added count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Added to Ribs"
        content.body = count == 1 ? "1 song from Downloads" : "\(count) songs from Downloads"
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
