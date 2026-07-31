import SwiftUI
import AppKit

/// Visual tokens matched to Kadr control panel (dark HIG suite chrome).
enum SuiteTheme {
    static let background = Color(nsColor: NSColor(calibratedRed: 0.043, green: 0.051, blue: 0.063, alpha: 1))
    static let surface = Color(hex: 0x141820)
    static let surfaceElevated = Color.white.opacity(0.06)
    static let border = Color.white.opacity(0.08)
    static let accent = Color(hex: 0xC026D3)
    static let snapAccent = Color(hex: 0x38BDF8)
    static let record = Color(hex: 0xEF4444)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)

    static let radiusControl: CGFloat = 10
    static let radiusCard: CGFloat = 14
    static let radiusPanel: CGFloat = 16

    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24

    static let springSoft = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let pressDuration: Double = 0.12
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

struct SuiteAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : (reduceMotion ? 0 : 8))
            .onAppear {
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(SuiteTheme.springSoft.delay(delay)) {
                        shown = true
                    }
                }
            }
    }
}

extension View {
    func suiteAppear(delay: Double = 0) -> some View {
        modifier(SuiteAppearModifier(delay: delay))
    }
}

struct SuiteSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(SuiteTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SuiteCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(SuiteTheme.spaceM)
            .background(
                RoundedRectangle(cornerRadius: SuiteTheme.radiusCard, style: .continuous)
                    .fill(SuiteTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: SuiteTheme.radiusCard, style: .continuous)
                            .strokeBorder(SuiteTheme.border, lineWidth: 1)
                    )
            )
    }
}

struct SuiteIconButton: View {
    let systemName: String
    var size: CGFloat = 30
    var tint: Color = SuiteTheme.textPrimary
    var filled: Bool = false
    var fillColor: Color = SuiteTheme.surfaceElevated
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(filled ? fillColor : Color.clear)
                        .overlay(Circle().strokeBorder(SuiteTheme.border, lineWidth: filled ? 0 : 1))
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed && !reduceMotion ? 0.92 : 1)
        .animation(.easeOut(duration: SuiteTheme.pressDuration), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

struct SuiteTileButton: View {
    let title: String
    let icon: String
    var accent: Color = SuiteTheme.accent
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(height: 24)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SuiteTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: SuiteTheme.radiusControl, style: .continuous)
                    .fill(SuiteTheme.surfaceElevated)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed && !reduceMotion ? 0.96 : 1)
        .animation(.easeOut(duration: SuiteTheme.pressDuration), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

struct SuiteRowButton: View {
    let title: String
    var icon: String? = nil
    var subtitle: String? = nil
    var accent: Color = SuiteTheme.record
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 22)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SuiteTheme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(SuiteTheme.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SuiteTheme.textTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: SuiteTheme.radiusCard, style: .continuous)
                    .fill(SuiteTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: SuiteTheme.radiusCard, style: .continuous)
                            .strokeBorder(SuiteTheme.border, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
