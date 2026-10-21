import SwiftUI

// MARK: - Design tokens (dark = black + red, light = white + black)

enum Theme {
    // Surfaces & text
    static let base      = Color(light: .white,               dark: .black)
    static let text      = Color(light: Color(hex: 0x000000), dark: Color(hex: 0xF5F5F7))
    static let secondary = Color(light: Color(hex: 0x3A3A3C), dark: Color(hex: 0xAEAEB2))
    static let tertiary  = Color(light: Color(hex: 0x6E6E73), dark: Color(hex: 0x8E8E93)) // also "N/A"
    static let hairline  = Color(light: .black.opacity(0.08), dark: .white.opacity(0.07))

    // Accent: red in dark mode, black in light mode
    static let accent    = Color(light: .black, dark: Color(hex: 0xFF453A))

    // Selected state (sidebar item, active toggle, primary button)
    // Light mode inverts: solid black pill, white text.
    static let selectedFill   = Color(light: .black.opacity(0.88), dark: Color(hex: 0xFF453A).opacity(0.12))
    static let selectedStroke = Color(light: .black,               dark: Color(hex: 0xFF453A).opacity(0.45))
    static let selectedText   = Color(light: .white,               dark: Color(hex: 0xFF453A))

    // Playing row: tint + outline
    static let playingFill    = Color(light: .black.opacity(0.06), dark: Color(hex: 0xFF453A).opacity(0.09))
    static let playingStroke  = Color(light: .black.opacity(0.80), dark: Color(hex: 0xFF453A).opacity(0.50))

    // Rare second highlight: yellow in dark, dark amber in light (yellow is unreadable on white)
    static let highlight       = Color(light: Color(hex: 0x9A5B00), dark: Color(hex: 0xFFD60A))
    static let highlightFill   = Color(light: Color(hex: 0xFFB800).opacity(0.14), dark: Color(hex: 0xFFD60A).opacity(0.07))
    static let highlightStroke = Color(light: Color(hex: 0x9A5B00).opacity(0.70), dark: Color(hex: 0xFFD60A).opacity(0.42))

    // Glass panels: black glass with a red edge and soft red glow in dark mode.
    // Light-mode values are the same as before, so light mode is unchanged.
    static let panelFill       = Color(light: .clear,               dark: .black.opacity(0.55))
    static let glassTint       = Color(light: .black.opacity(0.06), dark: Color(hex: 0xFF453A).opacity(0.10))
    static let glassEdgeTop    = Color(light: .black.opacity(0.14), dark: Color(hex: 0xFF453A).opacity(0.32))
    static let glassEdgeBottom = Color(light: .black.opacity(0.05), dark: Color(hex: 0xFF453A).opacity(0.06))
    static let glassGlow       = Color(light: .clear,               dark: Color(hex: 0xFF453A).opacity(0.14))

    // Separator
    static let separator = Color(light: .black.opacity(0.35), dark: Color(hex: 0xFF453A).opacity(0.45))

    // Toggles when off
    static let toggleOffStroke = Color(light: .black.opacity(0.25), dark: .white.opacity(0.14))

    // Sizes
    static let panelRadius: CGFloat = 16
    static let rowRadius: CGFloat = 8

    // Monospace font for times, counts, formats, SHF/RPT
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255,
                  opacity: 1)
    }

    /// A colour that switches automatically with Light / Dark mode.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
    }
}

// MARK: - Glass panel (sidebar, playback bar, sheets, mini player)

struct GlassPanel: ViewModifier {
    var radius: CGFloat = Theme.panelRadius

    func body(content: Content) -> some View {
        content
            .background {
                // near-black layer inside the glass (dark mode), so it reads black, not pink
                RoundedRectangle(cornerRadius: radius).fill(Theme.panelFill)
            }
            .glassEffect(.regular.tint(Theme.glassTint),
                         in: .rect(cornerRadius: radius))
            .overlay {
                // thin edge, brighter at the top (red in dark mode)
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(
                        LinearGradient(colors: [Theme.glassEdgeTop, Theme.glassEdgeBottom],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1)
            }
            .shadow(color: Theme.glassGlow, radius: 16)   // soft red glow (dark mode only)
    }
}

extension View {
    func glassPanel(radius: CGFloat = Theme.panelRadius) -> some View {
        modifier(GlassPanel(radius: radius))
    }
}

// MARK: - Highlights

enum Highlight {
    case selected   // sidebar item, active button
    case playing    // the song that is playing
    case editing    // second highlight

    var fill: Color {
        switch self {
        case .selected: Theme.selectedFill
        case .playing:  Theme.playingFill
        case .editing:  Theme.highlightFill
        }
    }

    var stroke: Color {
        switch self {
        case .selected: Theme.selectedStroke
        case .playing:  Theme.playingStroke
        case .editing:  Theme.highlightStroke
        }
    }
}

extension View {
    func highlight(_ kind: Highlight?, radius: CGFloat = Theme.rowRadius) -> some View {
        background {
            if let kind {
                RoundedRectangle(cornerRadius: radius)
                    .fill(kind.fill)
                    .overlay(RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(kind.stroke, lineWidth: 1))
            }
        }
    }
}

// MARK: - Small shared pieces

/// Line that fades in and out along its length.
struct FadedSeparator: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(stops: [
                .init(color: Theme.separator.opacity(0), location: 0),
                .init(color: Theme.separator,            location: 0.18),
                .init(color: Theme.separator,            location: 0.82),
                .init(color: Theme.separator.opacity(0), location: 1)
            ], startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
    }
}

/// SHF / RPT toggle.
struct TogglePill: View {
    let label: String
    let isOn: Bool

    var body: some View {
        Text(label)
            .font(Theme.mono(10))
            .tracking(0.5)
            .foregroundStyle(isOn ? Theme.selectedText : Theme.tertiary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOn ? Theme.selectedFill : .clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isOn ? Theme.selectedStroke : Theme.toggleOffStroke,
                                  lineWidth: 1)
            }
    }
}

/// Artwork square; a plain black square when the file has none (both modes).
struct ArtworkView: View {
    var image: NSImage?
    var size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
                    .allowsHitTesting(false)
            } else {
                Color.black
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.15))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.15)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}
