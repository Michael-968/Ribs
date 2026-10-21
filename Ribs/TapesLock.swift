import AppKit
import LocalAuthentication
import Observation

/// Optional lock for Tapes: Touch ID or the Mac's password, entirely on this Mac.
@MainActor
@Observable
final class TapesLock {
    static let shared = TapesLock()
    private static let enabledKey = "tapesLockEnabled"

    private(set) var isEnabled = UserDefaults.standard.bool(forKey: TapesLock.enabledKey)
    private(set) var isUnlocked = false

    /// Whether the last lock should also stop a tape that's playing.
    private(set) var lockStopsPlayback = false

    /// Set by the lock button so the Touch ID prompt doesn't pop straight back up.
    @ObservationIgnored var skipNextAutoUnlock = false

    /// Tapes can be shown: either no lock, or unlocked this session.
    var isAccessible: Bool { !isEnabled || isUnlocked }

    @ObservationIgnored private var screenLockObserver: NSObjectProtocol?

    private init() {
        // Re-lock when the Mac's screen locks
        screenLockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.lock(stopPlayback: true) }
        }
    }

    /// Leaving the page or closing the window: lock, keep playing.
    /// Lock button or Mac screen lock: lock and stop a playing tape.
    func lock(stopPlayback: Bool = false) {
        lockStopsPlayback = stopPlayback
        isUnlocked = false
    }

    func unlock() async {
        if await authenticate(reason: "unlock Tapes") {
            isUnlocked = true
        }
    }

    /// Turning the lock on or off always asks for Touch ID / password first.
    func setEnabled(_ on: Bool) async {
        guard on != isEnabled else { return }
        let reason = on ? "turn on the Tapes lock" : "turn off the Tapes lock"
        guard await authenticate(reason: reason) else { return }
        isEnabled = on
        isUnlocked = on            // you just proved it's you
        UserDefaults.standard.set(on, forKey: Self.enabledKey)
    }

    /// macOS's own prompt: Touch ID if available, otherwise the Mac password.
    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
                continuation.resume(returning: ok)
            }
        }
    }
}
