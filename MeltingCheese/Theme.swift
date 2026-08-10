import SwiftUI

/// Brand palette + type styles, matching the Melting Cheese Street Lab site.
enum Brand {
    static let ink = Color(hex: 0x0E0C0A)          // near-black background
    static let panel = Color(hex: 0x171310)        // raised card
    static let panelAlt = Color(hex: 0x1F1A16)
    static let line = Color(hex: 0x2A2622)
    static let orange = Color(hex: 0xF28C28)
    static let gold = Color(hex: 0xF5A623)
    static let cream = Color(hex: 0xF3EFE9)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0xCFC9C0)
    static let textMuted = Color(hex: 0x8B847B)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x1A120B), Brand.ink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [Brand.orange, Brand.gold],
                       startPoint: .leading, endPoint: .trailing)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Font {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.display(20))
                .foregroundColor(Brand.textPrimary)
            Rectangle()
                .fill(Brand.accentGradient)
                .frame(width: 44, height: 4)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PillButtonStyle: ButtonStyle {
    var filled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Group {
                    if filled {
                        Brand.accentGradient
                    } else {
                        Color.white.opacity(0.06)
                    }
                }
            )
            .foregroundColor(filled ? .white : Brand.textSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(filled ? Color.clear : Brand.line, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder(systemName: "fork.knife")
            case .empty:
                placeholder(systemName: "hourglass")
            @unknown default:
                placeholder(systemName: "fork.knife")
            }
        }
    }

    private func placeholder(systemName: String) -> some View {
        ZStack {
            Brand.panelAlt
            Image(systemName: systemName)
                .foregroundColor(Brand.textMuted)
                .font(.system(size: 20))
        }
    }
}

