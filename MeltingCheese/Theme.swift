import SwiftUI

/// v2 design system: light surfaces, amber/orange accent, soft rounded cards.
enum Brand {
    static let bg = Color(hex: 0xFFFFFF)
    static let surface = Color(hex: 0xF7F7F8)
    static let card = Color(hex: 0xFFFFFF)
    static let line = Color(hex: 0xEDEDF0)

    static let orange = Color(hex: 0xF5A623)
    static let orangeDeep = Color(hex: 0xF08C1A)
    static let amberSoft = Color(hex: 0xFDE7C2)

    static let ink = Color(hex: 0x1C1C1E)
    static let textPrimary = Color(hex: 0x1C1C1E)
    static let textSecondary = Color(hex: 0x8A8A8E)
    static let textMuted = Color(hex: 0xB0B0B5)

    static let green = Color(hex: 0x1DA453)
    static let danger = Color(hex: 0xE0342B)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [Brand.orange, Brand.orangeDeep],
                       startPoint: .leading, endPoint: .trailing)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - Building blocks

/// Soft white card used throughout the v2 screens.
struct CardBackground: ViewModifier {
    var radius: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .background(Brand.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Brand.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

extension View {
    func cardStyle(radius: CGFloat = 14) -> some View {
        modifier(CardBackground(radius: radius))
    }
}

/// Full-width amber action button.
struct PrimaryButtonStyle: ButtonStyle {
    /// Full-width by default; set false for a button that hugs its label.
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: expands ? 15 : 14, weight: .bold))
            .foregroundColor(.white)
            .padding(.vertical, expands ? 15 : 12)
            .padding(.horizontal, expands ? 0 : 18)
            .frame(maxWidth: expands ? .infinity : nil)
            .background(Brand.orange)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Rounded chip used for menu categories and filters.
struct ChipStyle: ButtonStyle {
    var selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: selected ? .bold : .medium))
            .foregroundColor(selected ? .white : Brand.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(selected ? Brand.orange : Brand.surface)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Quantity stepper (- 1 +) used on item detail and cart rows.
struct QuantityStepper: View {
    @Binding var quantity: Int
    var minimum: Int = 1
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Button {
                if quantity > minimum { quantity -= 1 } else { onRemove?() }
            } label: {
                Image(systemName: quantity <= minimum && onRemove != nil ? "trash" : "minus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            Text("\(quantity)")
                .font(.system(size: 14, weight: .semibold))
                .frame(minWidth: 30)
            Button {
                quantity += 1
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 32, height: 32)
            }
        }
        .foregroundColor(Brand.textPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Brand.line, lineWidth: 1)
        )
    }
}

/// Search field styled like the v2 mock-ups.
struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Brand.textMuted)
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Brand.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Brand.line, lineWidth: 1)
        )
    }
}

/// Remote image with a neutral placeholder while loading.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder
            case .empty:
                placeholder
            @unknown default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Brand.surface
            Image(systemName: "fork.knife")
                .foregroundColor(Brand.textMuted)
                .font(.system(size: 16))
        }
    }
}

/// Small star + rating row used on cards and item detail.
struct RatingLabel: View {
    var value: Double
    var count: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 11))
                .foregroundColor(Brand.green)
            Text(String(format: "%.1f", value))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Brand.textPrimary)
            if let count {
                Text("(\(count))")
                    .font(.system(size: 11))
                    .foregroundColor(Brand.textMuted)
            }
        }
    }
}

/// Row used on the Account screen.
struct SettingsRow: View {
    let icon: String
    let title: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Brand.textSecondary)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(Brand.textPrimary)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Brand.orange)
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Brand.textMuted)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
