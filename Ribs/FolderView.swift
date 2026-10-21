import SwiftUI

enum FolderKind: Hashable {
    case tapes, archive

    var title: String {
        switch self {
        case .tapes:   "Tapes"
        case .archive: "Archive"
        }
    }

    var collection: String {
        switch self {
        case .tapes:   TrackCollection.tapes
        case .archive: TrackCollection.archive
        }
    }

    var description: String {
        switch self {
        case .tapes:
            "Some recordings aren't for everyone. Tapes keeps them out of your music, search and shuffle — and, if you switch it on in Settings, behind Touch ID or your Mac's password."
        case .archive:
            "Not everything worth keeping is a song. Archive holds voice memos, lectures, calls and notes — kept apart from your music, so a recording never shuffles in between two tracks."
        }
    }

    var emptyHint: String {
        "Drag recordings here, drag songs onto \(title) in the sidebar, or right-click any song → Move to → \(title)."
    }
}

struct FolderView: View {
    let kind: FolderKind
    let tracks: [Track]
    let onAdd: () -> Void
    let onDelete: (Track) -> Void

    @State private var lock = TapesLock.shared

    var body: some View {
        if kind == .tapes && !lock.isAccessible {
            lockedView
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: kind.title,
                       subtitle: "\(tracks.count) recordings · \(formattedTotal(tracks))") {
                HStack(spacing: 12) {
                    if kind == .tapes && lock.isEnabled {
                        Button {
                            lock.skipNextAutoUnlock = true
                            lock.lock(stopPlayback: true)
                        } label: {
                            Image(systemName: "lock.open")
                        }
                        .buttonStyle(.borderless)
                        .help("Lock Tapes")
                    }
                    AddMenu(onAdd: onAdd)
                }
            }

            Text(kind.description)
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.bottom, 16)

            FadedSeparator()

            if tracks.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("\(kind.title) is empty").font(.system(size: 19, weight: .semibold))
                    Text(kind.emptyHint)
                        .foregroundStyle(Theme.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                TrackList(tracks: tracks.sorted {
                    $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }, onDelete: onDelete)
            }
        }
    }

    private var lockedView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 30))
                .foregroundStyle(Theme.tertiary)
            Text("Tapes is locked")
                .font(.system(size: 19, weight: .semibold))
            Text(kind.description)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            PillButton(title: "Unlock", icon: "touchid", primary: true) {
                Task { await lock.unlock() }
            }
            .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .task {
            // Opening Tapes asks for Touch ID straight away
            if lock.skipNextAutoUnlock {
                lock.skipNextAutoUnlock = false
                return
            }
            await lock.unlock()
        }
    }
}
