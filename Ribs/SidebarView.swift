import SwiftUI

enum SidebarItem: Hashable {
    case songs
    case albums
}

struct SidebarView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                RecordLogo(size: 26)
                Text("Ribs").font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 14)

            sectionLabel("Library")
            item("Songs", .songs)
            item("Albums", .albums)

            Spacer()
        }
        .font(.system(size: 14))
        .padding(.top, 40)
        .padding(12)
        .frame(width: 232)
        .frame(maxHeight: .infinity)
        .glassPanel()
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.tertiary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func item(_ label: String, _ value: SidebarItem) -> some View {
        let isOn = selection == value
        return Button { selection = value } label: {
            Text(label)
                .foregroundStyle(isOn ? Theme.selectedText : Theme.text)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .contentShape(Rectangle())
                .highlight(isOn ? .selected : nil, radius: 10)
        }
        .buttonStyle(.plain)
    }
}
