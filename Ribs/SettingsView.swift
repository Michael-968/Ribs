import SwiftUI

struct SettingsView: View {
    @State private var isDefault = DefaultPlayer.isRibsDefault
    @State private var working = false
    @State private var autoImport = DownloadsWatcher.shared.isEnabled

    var body: some View {
        Form {
            Section("Files") {
                Toggle("Open audio files with Ribs",
                       isOn: Binding(get: { isDefault }, set: { change($0) }))
                    .disabled(working)

                Text(isDefault
                     ? "Double-clicking MP3, M4A, WAV, AIFF and FLAC files opens them in Ribs."
                     : "Audio files open in your previous app (usually Music). You can still use Open With → Ribs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Import") {
                Toggle("Auto-import from Downloads",
                       isOn: Binding(get: { autoImport }, set: { on in
                           autoImport = on
                           DownloadsWatcher.shared.setEnabled(on)
                       }))

                Text("New audio files that arrive in Downloads are moved into Ribs automatically. Files already there are left alone. One quiet notification per batch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            isDefault = DefaultPlayer.isRibsDefault
            autoImport = DownloadsWatcher.shared.isEnabled
        }
    }

    private func change(_ on: Bool) {
        working = true
        Task {
            if on {
                await DefaultPlayer.makeRibsDefault()
            } else {
                await DefaultPlayer.restorePrevious()
            }
            isDefault = DefaultPlayer.isRibsDefault      // reflects what you confirmed
            working = false
        }
    }
}
