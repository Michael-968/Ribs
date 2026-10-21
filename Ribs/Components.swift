import SwiftUI

/// Title + mono subtitle + optional controls on the right.
struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 22, weight: .bold))
            Text(subtitle)
                .font(Theme.mono(12))
                .foregroundStyle(Theme.tertiary)
            Spacer()
            trailing
        }
        .frame(height: 52)
    }
}

/// The + menu that's always available.
struct AddMenu: View {
    let onAdd: () -> Void

    var body: some View {
        Menu {
            Button("Add Files or Folders…", action: onAdd)
                .keyboardShortcut("o")
            Divider()
            Button("Show Ribs Folder in Finder") { LibraryFolder.showInFinder() }
        } label: {
            Image(systemName: "plus")
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Add music")
    }
}

/// Rounded Play / Shuffle style buttons.
struct PillButton: View {
    let title: String
    let icon: String
    var primary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .frame(height: 32)
                .foregroundStyle(primary ? Theme.selectedText : Theme.text)
                .background {
                    Capsule().fill(primary ? Theme.selectedFill : Theme.text.opacity(0.06))
                }
                .overlay {
                    Capsule().strokeBorder(primary ? Theme.selectedStroke : Theme.toggleOffStroke, lineWidth: 1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Square artwork that fills its width; black when missing.
struct CoverImage: View {
    let data: Data?
    var radius: CGFloat = 10

    var body: some View {
        Color.black
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let data, let image = NSImage(data: data) {
                    Image(nsImage: image).resizable().scaledToFill()
                        .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }
    }
}

/// Stand-in for the X-ray record logo until the real image is added.
struct RecordLogo: View {
    var size: CGFloat = 26

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0xE0D6BD), Color(hex: 0x8C836C), Color(hex: 0x2E2A22)],
                                 center: UnitPoint(x: 0.4, y: 0.4),
                                 startRadius: 0, endRadius: size * 0.6))
            .overlay(Circle().fill(.black.opacity(0.5)).frame(width: size * 0.56))
            .overlay(Circle().fill(.black).frame(width: size * 0.12))
            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
            .frame(width: size, height: size)
    }
}

/// "45:57" or "1:12:03"
func formattedTotal(_ tracks: [Track]) -> String {
    let s = Int(tracks.reduce(0) { $0 + $1.duration })
    return s >= 3600
        ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        : String(format: "%d:%02d", s / 60, s % 60)
}
