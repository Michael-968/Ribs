import Foundation
import AVFoundation
import MediaPlayer
import Observation

enum RepeatMode {
    case off      // play through the list
    case song     // repeat the current song continuously
    case once     // repeat the current song one more time, then continue

    var label: String {
        switch self {
        case .off:  "Off"
        case .song: "This Song"
        case .once: "Once"
        }
    }
}

@MainActor
@Observable
final class PlayerEngine {
    // What the screen shows
    private(set) var current: Track?
    private(set) var isPlaying = false
    private(set) var elapsed: Double = 0
    private(set) var duration: Double = 0
    private(set) var shuffle = false
    private(set) var repeatMode: RepeatMode = .off

    // Internal
    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var queue: [Track] = []        // play order
    @ObservationIgnored private var sourceList: [Track] = []   // list the song was started from
    @ObservationIgnored private var index = 0
    @ObservationIgnored private var hasRepeatedOnce = false
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    init() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                self?.elapsed = time.seconds.isFinite ? time.seconds : 0
            }
        }
        setUpRemoteCommands()
    }

    // MARK: - Playing

    /// Plays a song, with the list it came from as the queue.
    func play(_ track: Track, from list: [Track]) {
        sourceList = list
        buildQueue(startingWith: track)
        load(queue[index], autoplay: true)
    }
    /// Play / Shuffle buttons on album and playlist pages.
    func playAll(_ list: [Track], shuffled: Bool) {
        guard let first = shuffled ? list.randomElement() : list.first else { return }
        shuffle = shuffled
        play(first, from: list)
    }
    func togglePlayPause() {
        guard current != nil else { return }
        isPlaying ? pause() : resume()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        guard current != nil else { return }
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func next() {
        guard !queue.isEmpty else { return }
        if index + 1 < queue.count {
            index += 1
            load(queue[index], autoplay: true)
        } else {
            index = 0                                  // end of list: back to the start, paused
            load(queue[index], autoplay: false)
        }
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if elapsed > 3 {                               // restart the song first
            seek(to: 0)
            return
        }
        if index > 0 { index -= 1 }
        load(queue[index], autoplay: isPlaying)
    }

    func seek(to seconds: Double) {
        let target = max(0, min(seconds, duration))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        elapsed = target
        updateNowPlaying()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        current = nil
        isPlaying = false
        elapsed = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    /// Call when a song is deleted from the library.
    func remove(_ track: Track) {
        if current?.id == track.id { stop() }
        queue.removeAll { $0.id == track.id }
        sourceList.removeAll { $0.id == track.id }
        index = min(index, max(queue.count - 1, 0))
    }

    // MARK: - Shuffle & repeat

    func toggleShuffle() {
        shuffle.toggle()
        if let current { buildQueue(startingWith: current) }
    }

    /// Off → repeat this song continuously → repeat once → off
    func cycleRepeat() {
        switch repeatMode {
        case .off:  repeatMode = .song
        case .song: repeatMode = .once
        case .once: repeatMode = .off
        }
        hasRepeatedOnce = false
    }

    // MARK: - Internals

    private func buildQueue(startingWith track: Track) {
        if shuffle {
            queue = [track] + sourceList.filter { $0.id != track.id }.shuffled()
            index = 0
        } else {
            queue = sourceList
            index = queue.firstIndex { $0.id == track.id } ?? 0
        }
        if queue.isEmpty { queue = [track]; index = 0 }
    }

    private func load(_ track: Track, autoplay: Bool) {
        current = track
        duration = track.duration
        elapsed = 0
        hasRepeatedOnce = false

        let item = AVPlayerItem(url: track.fileURL)
        player.replaceCurrentItem(with: item)

        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.songEnded() }
        }

        if autoplay {
            player.play()
            isPlaying = true
        } else {
            isPlaying = false
        }
        updateNowPlaying()
    }

    private func songEnded() {
        switch repeatMode {
        case .song:                                    // loop forever
            seek(to: 0)
            player.play()
            return
        case .once:
            if !hasRepeatedOnce {                      // play it one more time
                hasRepeatedOnce = true
                seek(to: 0)
                player.play()
                return
            }
            repeatMode = .off                          // used up → switch off, carry on
        case .off:
            break
        }

        if index + 1 < queue.count {
            next()
        } else {
            isPlaying = false                          // end of the list
            seek(to: 0)
        }
    }

    // MARK: - Media keys & Now Playing (Control Centre)

    private func setUpRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            let position = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime ?? 0
            Task { @MainActor in self?.seek(to: position) }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let current else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: current.artist ?? "N/A",
            MPMediaItemPropertyAlbumTitle: current.album ?? "",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    // MARK: - Formatting

    /// 125 → "02:05"
    static func clock(_ seconds: Double) -> String {
        let s = Int(max(0, seconds).rounded(.down))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
