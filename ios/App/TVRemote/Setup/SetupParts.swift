import SwiftUI
import TVRemoteKit

/// The symbol, title and subtitle at the top of every setup screen.
struct SetupHeader: View {
    let symbol: String
    let title: String
    var subtitle: String?
    /// For titles that are whole sentences.
    var isSentence = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Theme.text)
                .frame(width: 56, height: 56)
                .background(Theme.surface2, in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                .padding(.bottom, 24)
            Text(title)
                .font(.system(size: isSentence ? 26 : 31, weight: .semibold))
                .tracking(-0.5)
                .lineSpacing(2)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 16))
                    .lineSpacing(3)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// A dark rounded surface with a hairline edge.
    func surface(_ fill: Color = Theme.surface2, radius: CGFloat = 16) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

/// The one orange button on a screen. Greys out when disabled.
struct PrimaryButtonStyle: ButtonStyle {
    /// Sized to its label instead of the full width.
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 16 : 17, weight: .semibold))
            .foregroundStyle(isEnabled ? Theme.onAccent : Theme.secondary)
            .padding(.horizontal, compact ? 18 : 0)
            .frame(maxWidth: compact ? nil : .infinity)
            .frame(height: compact ? 46 : 56)
            .background(
                isEnabled ? Theme.accent : Theme.surface3,
                in: RoundedRectangle(cornerRadius: compact ? 13 : 16, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A quiet text button for the way out of a screen.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Theme.secondary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

// MARK: - Finding TVs

private struct TVFinderFactoryKey: EnvironmentKey {
    static let defaultValue: () -> TVFinding = { TVDiscovery() }
}

extension EnvironmentValues {
    /// Makes the finder a screen uses to look for TVs; demo mode replaces it with a fake.
    var makeTVFinder: () -> TVFinding {
        get { self[TVFinderFactoryKey.self] }
        set { self[TVFinderFactoryKey.self] = newValue }
    }
}
