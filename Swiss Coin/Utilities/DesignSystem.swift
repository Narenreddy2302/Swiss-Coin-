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

/// Semantic color definitions — pitch black dark mode, pitch white light mode
enum AppColors {
    // MARK: - Status Colors

    /// Positive balance / money owed to user
    static let positive = Color.blue

    /// Negative balance / money user owes
    static let negative = Color.red

    /// Neutral / settled state
    static let neutral = Color.secondary

    /// Warning / reminder color
    static let warning = Color.orange

    /// Primary accent color — black in light mode, white in dark mode
    static let accent = Color(.label)

    /// Default avatar color (system blue) — use as the single source of truth
    static let defaultAvatarColorHex = "#007AFF"
    static let defaultAvatarColor = Color(hex: "#007AFF")

    // MARK: - Background Colors

    /// Primary background — pure white (light) / pure black (dark)
    static let background = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor.black : UIColor.white
    })

    /// Secondary background — very subtle off-white / near-black
    static let backgroundSecondary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1) // #121212
            : UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1) // #F5F5F5
    })

    /// Tertiary background
    static let backgroundTertiary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1) // #1C1C1C
            : UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1) // #EBEBEB
    })

    /// Grouped background (for grouped list/table style)
    static let groupedBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor.black
            : UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1) // #F5F5F5
    })

    /// Surface background (search bars, input fields)
    static let surface = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1) // #1C1C1C
            : UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1) // #EBEBEB
    })

    /// Card background
    static let cardBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1) // #121212
            : UIColor.white
    })

    /// Elevated card background
    static let cardBackgroundElevated = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1) // #1C1C1C
            : UIColor.white
    })

    // MARK: - Text Colors

    /// Primary text
    static let textPrimary = Color(.label)

    /// Secondary text
    static let textSecondary = Color(.secondaryLabel)

    /// Tertiary text
    static let textTertiary = Color(UIColor.tertiaryLabel)

    // MARK: - Separator / Border

    /// Separator color
    static let separator = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.12)
            : UIColor(white: 0.0, alpha: 0.12)
    })

    // MARK: - Shadow

    /// Adaptive shadow color
    static let shadow = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.05)  // Subtle white glow in dark
            : UIColor(white: 0.0, alpha: 0.10)  // Standard dark shadow in light
    })

    // MARK: - Button Colors

    /// Button background — black in light mode, white in dark mode
    static let buttonBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
    })

    /// Button foreground/text — white in light mode, black in dark mode
    static let buttonForeground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor.black : UIColor.white
    })

    // MARK: - Interactive Colors

    /// User message bubble — same gray as incoming for consistent look
    static let userBubble = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1) // #2C2C2E
            : UIColor(red: 0.91, green: 0.91, blue: 0.92, alpha: 1) // #E9E9EB
    })

    /// Other person message bubble — gray
    static let otherBubble = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1) // #2C2C2E
            : UIColor(red: 0.91, green: 0.91, blue: 0.92, alpha: 1) // #E9E9EB
    })

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

/// Standard button style with scale animation (haptics should be triggered in button action)
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
    }
}

/// Primary action button style — black in light mode, white in dark mode
struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyBold())
            .foregroundColor(isEnabled ? AppColors.buttonForeground : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(isEnabled ? AppColors.buttonBackground : AppColors.disabled)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppAnimation.buttonPress, value: configuration.isPressed)
    }
}

/// Secondary action button style — outlined with theme-contrasting text
struct SecondaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.subheadlineMedium())
            .foregroundColor(isEnabled ? AppColors.textPrimary : AppColors.disabled)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .strokeBorder(AppColors.buttonBackground.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppAnimation.buttonPress, value: configuration.isPressed)
    }
}

// MARK: - Validation Constants

/// Input validation limits for text fields and data entry
enum ValidationLimits {
    /// Maximum length for person/entity names (100 characters)
    static let maxNameLength = 100
    
    /// Maximum length for display names (50 characters)
    static let maxDisplayNameLength = 50
    
    /// Maximum length for phone numbers (20 characters)
    static let maxPhoneLength = 20
    
    /// Maximum length for email addresses (254 per RFC 5321)
    static let maxEmailLength = 254
    
    /// Maximum length for transaction titles (200 characters)
    static let maxTransactionTitleLength = 200
    
    /// Maximum length for notes/messages (1000 characters)
    static let maxNoteLength = 1000
    
    /// Maximum length for reminder messages (500 characters)
    static let maxMessageLength = 500
    
    /// Maximum transaction amount ($1 million)
    static let maxTransactionAmount: Double = 1_000_000
    
    /// Maximum subscription amount ($100k/year)
    static let maxSubscriptionAmount: Double = 100_000
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
    
    /// Limits text field input to a maximum length
    func limitTextLength(to maxLength: Int, text: Binding<String>) -> some View {
        self.onChange(of: text.wrappedValue) { _, newValue in
            if newValue.count > maxLength {
                text.wrappedValue = String(newValue.prefix(maxLength))
            }
        }
    }
}
