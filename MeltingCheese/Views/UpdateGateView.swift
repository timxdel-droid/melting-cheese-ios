import SwiftUI

/// Build gating, published from ROS.
///
/// Two behaviours, deliberately kept separate:
///
/// - Below `minBuild` the app refuses to run. That is the only thing here
///   that genuinely forces an update.
/// - Below `latestBuild` it shows a dismissible strip and carries on.
///
/// What this cannot do, unlike the Android build: install anything. iOS has
/// no sideload path, so the button opens TestFlight and the rest is up to the
/// customer. "Forcing" an update on iOS means refusing to run without one --
/// nothing more is possible on this platform.
///
/// Everything degrades to "no gate". A missing, stale or half-written config
/// leaves the app running normally. That bias is deliberate: the failure mode
/// of a bug in this file is locking every customer out of the app.
struct UpdateGate<Content: View>: View {

    let release: AppRelease?
    @ViewBuilder var content: () -> Content

    @State private var dismissed = false

    /// Read from the bundle rather than hardcoded, so it always matches
    /// whatever Codemagic stamped on this particular binary.
    private var currentBuild: Int {
        let raw = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return Int(raw ?? "") ?? 0
    }

    var body: some View {
        if let release, release.mustUpdate(current: currentBuild) {
            UpdateWall(release: release, current: currentBuild)
        } else if let release, release.canUpdate(current: currentBuild), !dismissed {
            VStack(spacing: 0) {
                UpdateStrip(release: release) { dismissed = true }
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - Blocking

private struct UpdateWall: View {
    let release: AppRelease
    let current: Int

    var body: some View {
        VStack(spacing: 0) {
            Text("Time for an update")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Brand.textPrimary)

            Spacer().frame(height: 10)

            Text(release.notes?.isEmpty == false
                 ? release.notes!
                 : "This version of the app is no longer supported. Update to keep ordering.")
                .font(.system(size: 14))
                .foregroundStyle(Brand.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 6)

            Text("You have build \(current); build \(release.minBuild ?? 0) or newer is required.")
                .font(.system(size: 12))
                .foregroundStyle(Brand.textMuted)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 22)

            UpdateButton(release: release, label: "Update now")
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.bg)
    }
}

// MARK: - Dismissible

private struct UpdateStrip: View {
    let release: AppRelease
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update available" + (release.versionName?.isEmpty == false
                                               ? " - \(release.versionName!)" : ""))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Brand.textPrimary)

                    if let notes = release.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundStyle(Brand.textSecondary)
                    }
                }

                Spacer()

                Button("Later", action: onDismiss)
                    .font(.system(size: 12))
                    .foregroundStyle(Brand.textSecondary)
            }

            UpdateButton(release: release, label: "Update")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.amberSoft)
    }
}

// MARK: - Shared button

private struct UpdateButton: View {
    let release: AppRelease
    let label: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(destination)
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(Brand.orange))
        }
        .buttonStyle(.plain)
    }

    /// Where "update" sends the customer.
    ///
    /// The server field is called apk_url because Android needs a file there.
    /// On iOS it holds a link instead, normally the public TestFlight invite.
    /// With nothing published we open TestFlight itself, which is where every
    /// tester currently gets this app.
    private var destination: URL {
        if let raw = release.updateURL, !raw.isEmpty, let url = URL(string: raw) {
            return url
        }
        return URL(string: "itms-beta://") ?? URL(string: "https://testflight.apple.com")!
    }
}
