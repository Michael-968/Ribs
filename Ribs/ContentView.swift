import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Sidebar
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ribs")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.bottom, 14)
                    Text("Library")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.tertiary)
                        .padding(.horizontal, 10)
                    Text("Songs")
                        .foregroundStyle(Theme.selectedText)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                        .highlight(.selected, radius: 10)
                    Text("Albums")
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    Spacer()
                }
                .font(.system(size: 14))
                .padding(.top, 40)
                .padding(12)
                .frame(width: 232)
                .frame(maxHeight: .infinity)
                .glassPanel()

                // Main area
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Text("Songs").font(.system(size: 22, weight: .bold))
                        Text("0 songs").font(Theme.mono(12)).foregroundStyle(Theme.tertiary)
                        Spacer()
                    }
                    .frame(height: 52)
                    FadedSeparator()
                    Spacer()
                    Text("Stage 1 · theme check")
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
                .padding(.horizontal, 12)
            }

            // Playback bar
            HStack(spacing: 12) {
                ArtworkView(image: nil, size: 46)
                Text("Not Playing").foregroundStyle(Theme.secondary)
                Spacer()
                TogglePill(label: "SHF", isOn: false)
                TogglePill(label: "RPT", isOn: true)
                Spacer()
                Text("No source").font(Theme.mono(11)).foregroundStyle(Theme.tertiary)
            }
            .padding(.horizontal, 18)
            .frame(height: 76)
            .glassPanel()
        }
        .padding(12)
        .frame(minWidth: 1000, minHeight: 640)
        .foregroundStyle(Theme.text)
        .containerBackground(Theme.base, for: .window)
    }
}

#Preview {
    ContentView()
}
