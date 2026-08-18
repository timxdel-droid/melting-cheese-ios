import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Collection screen: the countdown until the order is ready, plus the QR code
/// and short code that staff check at the truck.
struct CollectionView: View {
    let order: OrderStore.Order

    @EnvironmentObject private var store: OrderStore

    /// The code stays hidden until staff ask for it, so it can't be shown
    /// to the wrong person or read off a screen in a queue.
    @State private var codeRevealed = false

    /// Always read the live copy — status changes after this view is created.
    private var current: OrderStore.Order { store.order(order.id) ?? order }

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    countdownCard
                    statusCard
                    qrCard
                    itemsCard
                    Text("Show this screen to staff at the truck.\nPayment is taken at the window.")
                        .font(.system(size: 12))
                        .foregroundColor(Brand.textMuted)
                        .multilineTextAlignment(.center)
                    Color.clear.frame(height: 6)
                }
                .padding(16)
            }
        }
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Status tracker

    private var statusCard: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let order = current
            let stage = order.status(at: context.date)

            VStack(alignment: .leading, spacing: 0) {
                Text("Order status")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.textSecondary)
                    .padding(.bottom, 12)

                ForEach(OrderStatus.allCases) { step in
                    let done = step.rawValue <= stage.rawValue
                    let isCurrent = step == stage

                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Image(systemName: done ? step.icon : "circle")
                                .font(.system(size: done ? 17 : 15))
                                .foregroundColor(done ? Brand.orange : Brand.textMuted)
                                .frame(width: 22, height: 22)

                            if step != OrderStatus.allCases.last {
                                Rectangle()
                                    .fill(step.rawValue < stage.rawValue ? Brand.orange : Brand.line)
                                    .frame(width: 2, height: 26)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.system(size: 13.5, weight: isCurrent ? .bold : .medium))
                                .foregroundColor(done ? Brand.textPrimary : Brand.textMuted)
                            Text(step.detail)
                                .font(.system(size: 11))
                                .foregroundColor(Brand.textMuted)
                        }

                        Spacer()

                        if let at = order.timestamp(for: step, at: context.date) {
                            Text(at, style: .time)
                                .font(.system(size: 11))
                                .foregroundColor(Brand.textMuted)
                        }
                    }
                    .padding(.bottom, step == OrderStatus.allCases.last ? 0 : 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardStyle()
        }
    }

    private var countdownCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, order.readyAt.timeIntervalSince(context.date))
            let ready = remaining <= 0

            VStack(spacing: 10) {
                Text(ready ? "Ready to collect" : "Ready in")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.textSecondary)

                if ready {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Brand.green)
                } else {
                    Text(Self.clock(remaining))
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .foregroundColor(Brand.orange)
                        .monospacedDigit()
                }

                ProgressView(value: progress(remaining))
                    .tint(ready ? Brand.green : Brand.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .cardStyle()
        }
    }

    private func progress(_ remaining: TimeInterval) -> Double {
        let span = order.readyAt.timeIntervalSince(order.placedAt)
        guard span > 0 else { return 1 }
        return min(1, max(0, 1 - remaining / span))
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var qrCard: some View {
        VStack(spacing: 14) {
            Text("Collection code")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Brand.textSecondary)

            if codeRevealed {
                if let image = Self.qrImage(from: order.reference) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 190, height: 190)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                Text(order.reference)
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundColor(Brand.textPrimary)
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if current.collectedAt == nil {
                    Button { store.markCollected(order.id) } label: {
                        Label("Staff: mark as collected", systemImage: "checkmark.seal")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(Brand.orange)
                    }
                    .padding(.top, 2)
                } else {
                    Label("Handed over", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Brand.green)
                }

                Button("Hide code") {
                    withAnimation(.easeInOut(duration: 0.2)) { codeRevealed = false }
                }
                .font(.system(size: 11.5))
                .foregroundColor(Brand.textMuted)

            } else {
                // Placeholder keeps the card the same height so it doesn't jump.
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Brand.bg)
                        .frame(width: 190, height: 190)
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 42))
                            .foregroundColor(Brand.textMuted.opacity(0.5))
                        Text("Hidden")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Brand.textMuted)
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { codeRevealed = true }
                } label: {
                    Label("Reveal collection code", systemImage: "eye.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("Only reveal this at the window, so staff can match you to the right order.")
                    .font(.system(size: 10.5))
                    .foregroundColor(Brand.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .cardStyle()
    }

    /// Generates a scannable QR containing the order reference.
    static func qrImage(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private var itemsCard: some View {
        VStack(spacing: 9) {
            ForEach(order.lines) { line in
                HStack(alignment: .top) {
                    Text("\(line.quantity)×  \(line.name)")
                        .font(.system(size: 12))
                        .foregroundColor(Brand.textSecondary)
                    Spacer()
                    Text(line.lineTotal.map { store.format($0, currency: line.currency) } ?? "At truck")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Brand.textPrimary)
                }
            }
            Divider().overlay(Brand.line)
            HStack {
                Text("Total").font(.system(size: 14, weight: .bold))
                Spacer()
                Text(store.format(order.total, currency: order.currency))
                    .font(.system(size: 15, weight: .bold))
            }

            Divider().overlay(Brand.line)

            HStack(spacing: 8) {
                Image(systemName: order.paymentMethod.icon)
                    .font(.system(size: 13))
                    .foregroundColor(Brand.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Paying by \(order.paymentMethod.badge)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Brand.textPrimary)
                    if order.isAwaitingPayment {
                        Text("Not yet charged — settle at the window")
                            .font(.system(size: 10.5))
                            .foregroundColor(Brand.textMuted)
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .cardStyle()
    }
}

/// Social follow strip shown at the bottom of the browse screen.
struct SocialFollowBar: View {
    private let links: [(String, String, String)] = [
        ("Instagram", "camera", "https://www.instagram.com/meltingcheese.streetlab"),
        ("TikTok", "music.note", "https://www.tiktok.com/@meltingcheese.streetlab"),
        ("Facebook", "person.2", "https://www.facebook.com/meltingcheese.streetlab")
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("Follow the cheese")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Brand.textPrimary)
            Text("Find out where we're parked next, and see what's coming off the griddle.")
                .font(.system(size: 12))
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ForEach(links, id: \.0) { name, icon, url in
                    Link(destination: URL(string: url)!) {
                        VStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 42, height: 42)
                                .background(Brand.orange)
                                .clipShape(Circle())
                            Text(name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Brand.textSecondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
