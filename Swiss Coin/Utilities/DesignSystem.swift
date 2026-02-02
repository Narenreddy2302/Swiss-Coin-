//
//  DesignSystem.swift
//  Swiss Coin
//
//  Centralized design system constants for consistent styling across the app.
//

import SwiftUI

// MARK: - Spacing

/// Standardized spacing values following an 4pt base grid
enum Spacing {
    /// 4pt - Minimum spacing for tight layouts
    static let xxs: CGFloat = 4

    /// 6pt - Small internal spacing
    static let xs: CGFloat = 6

    /// 8pt - Standard small spacing
    static let sm: CGFloat = 8

    /// 12pt - Medium spacing
    static let md: CGFloat = 12

    /// 16pt - Standard spacing (most common)
    static let lg: CGFloat = 16

    /// 20pt - Large spacing
    static let xl: CGFloat = 20

    /// 24pt - Extra large spacing
    static let xxl: CGFloat = 24

    /// 32pt - Section spacing
    static let section: CGFloat = 32
}

// MARK: - Corner Radius

/// Standardized corner radius values
enum CornerRadius {
    /// 4pt - Tags, badges, small elements
    static let xs: CGFloat = 4

    /// 8pt - Small buttons, compact cards
    static let sm: CGFloat = 8

    /// 12pt - Standard cards, buttons (most common)
    static let md: CGFloat = 12

    /// 16pt - Large cards, modal sheets
    static let lg: CGFloat = 16

    /// 20pt - Extra large containers
    static let xl: CGFloat = 20

    /// Full circle
    static let full: CGFloat = .infinity
}

// MARK: - Icon Sizes

/// Standardized icon sizes
enum IconSize {
    /// 12pt - Tiny icons in dense UI
    static let xs: CGFloat = 12

    /// 16pt - Small icons
    static let sm: CGFloat = 16

    /// 20pt - Medium icons
    static let md: CGFloat = 20

    /// 24pt - Standard icons
    static let lg: CGFloat = 24

    /// 32pt - Large icons
    static let xl: CGFloat = 32

    /// 48pt - Hero icons
    static let xxl: CGFloat = 48
}

// MARK: - Avatar Sizes

/// Standardized avatar sizes
enum AvatarSize {
    /// 32pt - Compact list items
    static let xs: CGFloat = 32

    /// 36pt - Dense conversation headers
    static let sm: CGFloat = 36

    /// 44pt - Standard list rows (touch target)
    static let md: CGFloat = 44

    /// 48pt - Emphasized list items
    static let lg: CGFloat = 48

    /// 80pt - Profile headers
    static let xl: CGFloat = 80

    /// 100pt - Detail views
    static let xxl: CGFloat = 100
}

// MARK: - Button Heights

/// Standardized button heights (touch targets)
enum ButtonHeight {
    /// 36pt - Compact buttons
    static let sm: CGFloat = 36

    /// 44pt - Standard buttons (minimum touch target)
    static let md: CGFloat = 44

    /// 50pt - Primary action buttons
    static let lg: CGFloat = 50

    /// 56pt - Hero buttons
    static let xl: CGFloat = 56
}

// MARK: - Animation

/// Standardized animation durations and curves
enum AppAnimation {
    /// Quick animation for micro-interactions (0.15s)
    static let quick: Animation = .easeOut(duration: 0.15)

    /// Standard animation (0.25s)
    static let standard: Animation = .easeInOut(duration: 0.25)

    /// Slow animation for emphasis (0.35s)
    static let slow: Animation = .easeInOut(duration: 0.35)

    /// Spring animation for bouncy effects
    static let spring: Animation = .spring(response: 0.35, dampingFraction: 0.7)

    /// Button press scale animation
    static let buttonPress: Animation = .easeOut(duration: 0.15)
}

// MARK: - Colors

/// Semantic color definitions
enum AppColors {
    // MARK: - Status Colors

    /// Positive balance / money owed to user
    static let positive = Color.green

    /// Negative balance / money user owes
    static let negative = Color.red

    /// Neutral / settled state
    static let neutral = Color.secondary

    /// Warning / reminder color
    static let warning = Color.orange

    /// Primary accent color
    static let accent = Color.green

    /// Default avatar color (system blue) — use as the single source of truth
    static let defaultAvatarColorHex = "#007AFF"
    static let defaultAvatarColor = Color(hex: "#007AFF")

    // MARK: - Background Colors

    /// Primary background (adapts to light/dark mode)
    static let background = Color(.systemBackground)

    /// Secondary background
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)

    /// Tertiary background
    static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)

    /// Grouped background (for grouped list/table style)
    static let groupedBackground = Color(.systemGroupedBackground)

    /// Surface background (search bars, input fields)
    static let surface = Color(UIColor.systemGray5)

    /// Card background
    static let cardBackground = Color(UIColor.secondarySystemBackground)

    /// Elevated card background
    static let cardBackgroundElevated = Color(UIColor.tertiarySystemBackground)

    // MARK: - Text Colors

    /// Primary text
    static let textPrimary = Color(.label)

    /// Secondary text
    static let textSecondary = Color(.secondaryLabel)

    /// Tertiary text
    static let textTertiary = Color(UIColor.tertiaryLabel)

    // MARK: - Separator / Border

    /// Separator color
    static let separator = Color(.separator)

    // MARK: - Shadow

    /// Adaptive shadow color (works in both light and dark mode)
    static let shadow = Color(.label).opacity(0.08)

    // MARK: - Interactive Colors

    /// User message bubble
    static let userBubble = Color.green

    /// Other person message bubble
    static let otherBubble = Color(UIColor.secondarySystemBackground)

    /// Disabled state
    static let disabled = Color(.secondaryLabel).opacity(0.4)
}

// MARK: - Typography

/// Standardized typography styles
enum AppTypography {

    // MARK: - Headers

    /// Large title (34pt bold)
    static func largeTitle() -> Font {
        .largeTitle.weight(.bold)
    }

    /// Title 1 (28pt bold)
    static func title1() -> Font {
        .title.weight(.bold)
    }

    /// Title 2 (22pt bold)
    static func title2() -> Font {
        .title2.weight(.bold)
    }

    /// Title 3 (20pt semibold)
    static func title3() -> Font {
        .title3.weight(.semibold)
    }

    // MARK: - Body

    /// Headline (17pt semibold)
    static func headline() -> Font {
        .headline
    }

    /// Body (17pt regular)
    static func body() -> Font {
        .body
    }

    /// Body emphasized (17pt semibold)
    static func bodyBold() -> Font {
        .body.weight(.semibold)
    }

    // MARK: - Secondary

    /// Subheadline (15pt regular)
    static func subheadline() -> Font {
        .subheadline
    }

    /// Subheadline emphasized (15pt medium)
    static func subheadlineMedium() -> Font {
        .subheadline.weight(.medium)
    }

    // MARK: - Small

    /// Footnote (13pt regular)
    static func footnote() -> Font {
        .footnote
    }

    /// Caption 1 (12pt regular)
    static func caption() -> Font {
        .caption
    }

    /// Caption 2 (11pt regular)
    static func caption2() -> Font {
        .caption2
    }

    // MARK: - Monospace (for amounts)

    /// Amount display (17pt bold, monospaced digits)
    static func amount() -> Font {
        .system(size: 17, weight: .bold, design: .rounded)
    }

    /// Large amount display (22pt bold)
    static func amountLarge() -> Font {
        .system(size: 22, weight: .bold, design: .rounded)
    }

    /// Small amount display (15pt semibold)
    static func amountSmall() -> Font {
        .system(size: 15, weight: .semibold, design: .rounded)
    }
}

// MARK: - Button Styles

/// Standard button style with haptic feedback and scale animation
struct AppButtonStyle: ButtonStyle {
    let hapticStyle: HapticStyle

    enum HapticStyle {
        case light
        case medium
        case heavy
        case selection
        case none
    }

    init(haptic: HapticStyle = .medium) {
        self.hapticStyle = haptic
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppAnimation.buttonPress, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    triggerHaptic()
                }
            }
    }

    private func triggerHaptic() {
        switch hapticStyle {
        case .light:
            HapticManager.lightTap()
        case .medium:
            HapticManager.tap()
        case .heavy:
            HapticManager.heavyTap()
        case .selection:
            HapticManager.selectionChanged()
        case .none:
            break
        }
    }
}

/// Primary action button style (green accent)
struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyBold())
            .foregroundColor(isEnabled ? .white : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(isEnabled ? AppColors.accent : AppColors.disabled)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppAnimation.buttonPress, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && isEnabled {
                    HapticManager.tap()
                }
            }
    }
}

/// Secondary action button style
struct SecondaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.subheadlineMedium())
            .foregroundColor(isEnabled ? AppColors.textSecondary : AppColors.disabled)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackground)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppAnimation.buttonPress, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && isEnabled {
                    HapticManager.lightTap()
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies standard card styling
    func cardStyle() -> some View {
        self
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackground)
            )
    }

    /// Applies elevated card styling
    func elevatedCardStyle() -> some View {
        self
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackgroundElevated)
            )
    }

    /// Adds haptic feedback on tap
    func withHaptic(_ style: AppButtonStyle.HapticStyle = .medium) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded {
                switch style {
                case .light:
                    HapticManager.lightTap()
                case .medium:
                    HapticManager.tap()
                case .heavy:
                    HapticManager.heavyTap()
                case .selection:
                    HapticManager.selectionChanged()
                case .none:
                    break
                }
            }
        )
    }
}
