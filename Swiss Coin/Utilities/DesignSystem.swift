//
//  DesignSystem.swift
//  Swiss Coin
//
//  Centralized design system constants for consistent styling across the app.
//  Premium finance-app design theme — warm, data-focused, information-dense.
//

import SwiftUI
import UIKit

// MARK: - Spacing

/// Standardized spacing values following an 8pt grid (with 4pt half-steps)
enum Spacing {
    /// 2pt - Micro gaps
    static let xxs: CGFloat = 2

    /// 4pt - Tight internal gaps
    static let xs: CGFloat = 4

    /// 8pt - Default internal spacing
    static let sm: CGFloat = 8

    /// 12pt - Between elements in a card
    static let md: CGFloat = 12

    /// 16pt - Card padding, screen margins
    static let lg: CGFloat = 16

    /// 20pt - Between card groups
    static let xl: CGFloat = 20

    /// 24pt - Major section gaps
    static let xxl: CGFloat = 24

    /// 32pt - Hero area breathing room
    static let xxxl: CGFloat = 32

    // MARK: - Named Measurements

    /// 16pt - Left/right margin on all screens
    static let screenHorizontal: CGFloat = 16

    /// 8pt - Below nav bar to first content
    static let screenTopPad: CGFloat = 8

    /// 16pt - Internal card padding (all sides)
    static let cardPadding: CGFloat = 16

    /// 12pt - Between stacked cards
    static let cardGap: CGFloat = 12

    /// 60pt - List/transaction row height
    static let rowHeight: CGFloat = 60

    /// 52pt - Divider left inset (past icon)
    static let rowDividerInset: CGFloat = 52

    /// 24pt - Between major sections
    static let sectionGap: CGFloat = 24

    /// 12pt - Sheet/modal top spacing
    static let modalTopMargin: CGFloat = 12

    /// 6pt - Compact row vertical padding
    static let compactVertical: CGFloat = 6

    /// 70pt - Settings row divider inset (icon rows with category-size icons)
    static let settingsRowDividerInset: CGFloat = 70

    // Legacy compatibility
    static let section: CGFloat = 32
}

// MARK: - Corner Radius

/// Standardized corner radius values
enum CornerRadius {
    /// 6pt - Tags, badges, small elements
    static let small: CGFloat = 6

    /// 10pt - Input fields, small containers
    static let medium: CGFloat = 10

    /// 12pt - All button variants
    static let button: CGFloat = 12

    /// 14pt - Cards, sheets, modals
    static let card: CGFloat = 14

    /// 16pt - Hero containers
    static let large: CGFloat = 16

    /// 20pt - Special feature cards
    static let extraLarge: CGFloat = 20

    /// Full circle - Pill shapes, circular elements
    static let full: CGFloat = 9999

    // Legacy compatibility
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
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

    /// 24pt - Standard icons (tab bar)
    static let lg: CGFloat = 24

    /// 28pt - Category emoji size
    static let category: CGFloat = 28

    /// 32pt - Large icons
    static let xl: CGFloat = 32

    /// 36pt - Category background circle
    static let categoryBackground: CGFloat = 36

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

    /// 60pt - Profile settings avatar
    static let profile: CGFloat = 60

    /// 64pt - Category/hero icon background
    static let categoryHero: CGFloat = 64
}

// MARK: - Button Heights

/// Standardized button heights (touch targets)
enum ButtonHeight {
    /// 36pt - Compact buttons
    static let sm: CGFloat = 36

    /// 44pt - Standard buttons (minimum touch target)
    static let md: CGFloat = 44

    /// 48pt - Input field height
    static let input: CGFloat = 48

    /// 50pt - Primary action buttons
    static let lg: CGFloat = 50

    /// 56pt - Hero buttons
    static let xl: CGFloat = 56
}

// MARK: - Progress Bar

/// Standardized progress bar dimensions
enum ProgressBarSize {
    /// 8pt - Standard track height
    static let trackHeight: CGFloat = 8

    /// 4pt - Track corner radius
    static let trackRadius: CGFloat = 4
}

// MARK: - Tab Bar

/// Tab bar sizing constants
enum TabBarSize {
    /// 49pt - Standard tab bar height (plus safe area)
    static let height: CGFloat = 49

    /// 24pt - Tab bar icon size
    static let iconSize: CGFloat = 24
}

// MARK: - Shadows

/// Standardized shadow definitions
enum AppShadow {
    /// Card shadow - subtle elevation
    static func card(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        let opacity = colorScheme == .dark ? 0.24 : 0.08
        return (Color.black.opacity(opacity), 8, 0, 2)
    }

    /// Elevated shadow - modals/sheets
    static func elevated(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        let opacity = colorScheme == .dark ? 0.32 : 0.12
        return (Color.black.opacity(opacity), 16, 0, 4)
    }

    /// Bubble shadow - chat message bubbles and comment bubbles
    static func bubble(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        let opacity = colorScheme == .dark ? 0.2 : 0.05
        return (Color.black.opacity(opacity), 2, 0, 1)
    }
}

// MARK: - Animation

/// Standardized animation durations and curves
enum AppAnimation {
    // MARK: - Duration Constants (for reference)

    /// Fast duration value - 0.15s
    static let fastDuration: Double = 0.15

    /// Default duration value - 0.25s
    static let defaultDuration: Double = 0.25

    /// Slow duration value - 0.4s
    static let slowDuration: Double = 0.4

    // MARK: - Animation Presets

    /// Fast animation (0.15s) - button press, toggle
    static let fast: Animation = .easeOut(duration: fastDuration)

    /// Default animation (0.25s) - page transitions, reveals
    static let standard: Animation = .easeInOut(duration: defaultDuration)

    /// Slow animation (0.4s) - chart animations, complex transitions
    static let slow: Animation = .easeInOut(duration: slowDuration)

    /// Spring animation - default interactive spring (response: 0.3, damping: 0.7)
    static let spring: Animation = .spring(response: 0.3, dampingFraction: 0.7)

    /// Button press scale animation
    static let buttonPress: Animation = .easeOut(duration: fastDuration)

    // Legacy compatibility
    static let quick: Animation = .easeOut(duration: fastDuration)

    // MARK: - Transaction Detail Animations

    /// Card morphing spring — used for hero card-to-detail transitions
    static let cardMorph: Animation = .spring(response: 0.5, dampingFraction: 0.86)

    /// Content reveal spring — used for staggered section entrance
    static let contentReveal: Animation = .spring(response: 0.45, dampingFraction: 0.82)

    /// Interactive spring — snappy snap-back for drag gesture cancellation
    static let interactiveSpring: Animation = .spring(response: 0.4, dampingFraction: 0.75)

    /// Dismiss collapse spring — fast, critically-damped for clean exit
    static let dismiss: Animation = .spring(response: 0.25, dampingFraction: 0.9)

    // MARK: - Theme Transition

    /// Theme cross-fade duration
    static let themeTransitionDuration: Double = 0.35

    /// Reduced-motion theme cross-fade duration
    static let themeTransitionReducedDuration: Double = 0.12

    // MARK: - Stagger Timing

    /// Standard stagger interval between cascading section reveals
    static let staggerInterval: Double = 0.07

    /// Base delay before the first staggered section appears
    static let staggerBaseDelay: Double = 0.22
}

// MARK: - Colors

/// Semantic color definitions — premium finance app theme
enum AppColors {

    // MARK: - Brand / Accent Colors

    /// Primary accent color - warm orange for CTAs, active states, links
    static let accent = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F36D30")
            : UIColor(hex: "#F35B16")
    })

    /// Primary pressed state
    static let accentPressed = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#E05A1A")
            : UIColor(hex: "#D94E12")
    })

    /// Subtle accent background
    static let accentMuted = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3D2215")
            : UIColor(hex: "#FEF0EA")
    })

    /// Text on accent color
    static let onAccent = Color.white

    // MARK: - Text Colors

    /// Primary text - warm near-black (NOT pure black)
    static let textPrimary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F5F5F3")
            : UIColor(hex: "#22201D")
    })

    /// Secondary text - supporting/descriptive
    static let textSecondary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#A8A29E")
            : UIColor(hex: "#6B6560")
    })

    /// Tertiary text - captions, timestamps, muted labels
    static let textTertiary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#6B6560")
            : UIColor(hex: "#A8A29E")
    })

    /// Disabled text
    static let textDisabled = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3D3A37")
            : UIColor(hex: "#D4D0CC")
    })

    /// Inverse text - text on opposite-mode surfaces
    static let textInverse = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#22201D")
            : UIColor.white
    })

    /// Link text - matches accent
    static let textLink = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F36D30")
            : UIColor(hex: "#F35B16")
    })

    // MARK: - Background Colors

    /// Primary background - main screen background
    static let background = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#1C1C1E")
            : UIColor.white
    })

    /// Secondary background - grouped/inset backgrounds
    static let backgroundSecondary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#2C2C2E")
            : UIColor(hex: "#F7F5F3")
    })

    /// Tertiary background - nested surfaces
    static let backgroundTertiary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A3A3C")
            : UIColor(hex: "#EFEDEB")
    })

    /// Elevated surface - cards, sheets (use with shadow)
    static let elevatedSurface = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A3A3C")
            : UIColor.white
    })

    /// Card background - elevated surface for cards
    static let cardBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A3A3C")
            : UIColor.white
    })

    /// Card background elevated - higher elevation cards
    static let cardBackgroundElevated = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#48484A")
            : UIColor.white
    })

    /// Grouped background
    static let groupedBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#1C1C1E")
            : UIColor(hex: "#F7F5F3")
    })

    /// Surface background (search bars, input fields)
    static let surface = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#2C2C2E")
            : UIColor(hex: "#F7F5F3")
    })

    // MARK: - Borders & Dividers

    /// Default border
    static let border = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A3A3C")
            : UIColor(hex: "#E8E5E1")
    })

    /// Strong border
    static let borderStrong = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#545456")
            : UIColor(hex: "#D4D0CC")
    })

    /// Subtle border
    static let borderSubtle = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#2C2C2E")
            : UIColor(hex: "#F0EDEA")
    })

    /// Focus border - input focus ring
    static let borderFocus = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F36D30")
            : UIColor(hex: "#F35B16")
    })

    /// Divider - hairline list separators
    static let divider = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#38383A")
            : UIColor(hex: "#F0EDEA")
    })

    /// Separator (legacy compatibility)
    static let separator = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#38383A")
            : UIColor(hex: "#F0EDEA")
    })

    // MARK: - Semantic: Financial

    /// Positive - income/gain (green)
    static let positive = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#34C77B")
            : UIColor(hex: "#1B8A5A")
    })

    /// Positive muted background
    static let positiveMuted = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#1A3328")
            : UIColor(hex: "#E8F5EE")
    })

    /// Negative - expense/loss (red)
    static let negative = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F87171")
            : UIColor(hex: "#D93025")
    })

    /// Negative muted background
    static let negativeMuted = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3D1F1F")
            : UIColor(hex: "#FDF0EF")
    })

    /// Neutral - balanced (gray)
    static let neutral = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#A8A29E")
            : UIColor(hex: "#6B6560")
    })

    /// Neutral muted background
    static let neutralMuted = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#2C2C2E")
            : UIColor(hex: "#F7F5F3")
    })

    /// Warning - caution (amber)
    static let warning = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#FBBF24")
            : UIColor(hex: "#D97706")
    })

    /// Warning muted background
    static let warningMuted = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3D3015")
            : UIColor(hex: "#FEF9EC")
    })

    /// Info - upcoming (blue)
    static let info = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#60A5FA")
            : UIColor(hex: "#2563EB")
    })

    /// Info muted background
    static let infoMuted = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#1E2A3D")
            : UIColor(hex: "#EFF6FF")
    })

    // MARK: - Asset Class Colors (cool tones)

    /// Cash/Banking - green
    static let assetCash = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#34C77B")
            : UIColor(hex: "#1B8A5A")
    })

    /// Investments - blue
    static let assetInvestments = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#60A5FA")
            : UIColor(hex: "#2563EB")
    })

    /// Real Estate - purple
    static let assetRealEstate = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#A78BFA")
            : UIColor(hex: "#7C3AED")
    })

    /// Crypto - violet
    static let assetCrypto = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#C4B5FD")
            : UIColor(hex: "#8B5CF6")
    })

    /// Vehicles - cyan
    static let assetVehicles = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#22D3EE")
            : UIColor(hex: "#0891B2")
    })

    /// Other Assets - gray
    static let assetOther = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#A8A29E")
            : UIColor(hex: "#6B6560")
    })

    // MARK: - Liability Colors (warm tones)

    /// Credit Cards - red
    static let liabilityCreditCards = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F87171")
            : UIColor(hex: "#D93025")
    })

    /// Loans - yellow
    static let liabilityLoans = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#FBBF24")
            : UIColor(hex: "#D97706")
    })

    /// Mortgages - amber
    static let liabilityMortgages = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F59E0B")
            : UIColor(hex: "#B45309")
    })

    /// Other Liabilities - orange
    static let liabilityOther = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#FB923C")
            : UIColor(hex: "#9A3412")
    })

    // MARK: - Budget Status (3-state system)

    /// Under budget - green (money remaining)
    static let budgetUnder = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#34C77B")
            : UIColor(hex: "#1B8A5A")
    })

    /// On budget - gray (perfectly balanced)
    static let budgetOn = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#A8A29E")
            : UIColor(hex: "#6B6560")
    })

    /// Over budget - red (overspent)
    static let budgetOver = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F87171")
            : UIColor(hex: "#D93025")
    })

    // MARK: - Chart Series Colors

    static let chartSeries1 = accent
    static let chartSeries2 = assetInvestments
    static let chartSeries3 = positive
    static let chartSeries4 = assetRealEstate
    static let chartSeries5 = warning
    static let chartSeries6 = assetVehicles
    static let chartSeries7 = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F472B6")
            : UIColor(hex: "#BE185D")
    })
    static let chartSeries8 = neutral

    /// Chart grid lines
    static let chartGrid = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A3A3C")
            : UIColor(hex: "#E8E5E1")
    })

    /// Chart axis labels
    static let chartAxisLabels = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#6B6560")
            : UIColor(hex: "#A8A29E")
    })

    // MARK: - Interactive States

    /// Hover background
    static let hoverBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A3A3C")
            : UIColor(hex: "#F7F5F3")
    })

    /// Pressed background
    static let pressedBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#545456")
            : UIColor(hex: "#EFEDEB")
    })

    /// Selected background
    static let selectedBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3D2215")
            : UIColor(hex: "#FEF0EA")
    })

    /// Disabled state - any color at 38% opacity
    static let disabled = Color(.secondaryLabel).opacity(0.38)

    // MARK: - Button Colors

    /// Button background - primary accent
    static let buttonBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F36D30")
            : UIColor(hex: "#F35B16")
    })

    /// Button foreground - white on accent
    static let buttonForeground = Color.white

    // MARK: - Interactive Colors

    /// User message bubble — white for visibility against off-white background
    static let userBubble = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A3A3C")
            : UIColor.white
    })

    /// User message bubble text color
    static let userBubbleText = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F5F5F3")
            : UIColor(hex: "#22201D")
    })

    /// Other person message bubble — slightly warmer tone to differentiate from user bubble
    static let otherBubble = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#2C2C2E")
            : UIColor(hex: "#F0EDE8")
    })

    /// Other message bubble text color
    static let otherBubbleText = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F5F5F3")
            : UIColor(hex: "#22201D")
    })

    /// Shadow color
    static let shadow = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.0, alpha: 0.24)
            : UIColor(white: 0.0, alpha: 0.08)
    })

    /// Subtle shadow — lighter card shadows that remain visible in dark mode
    static let shadowSubtle = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.0, alpha: 0.16)
            : UIColor(white: 0.0, alpha: 0.04)
    })

    /// Micro shadow — barely-there secondary shadow for layered depth
    static let shadowMicro = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.0, alpha: 0.12)
            : UIColor(white: 0.0, alpha: 0.02)
    })

    // MARK: - Overlay Colors

    /// Scrim/overlay background - dimmed background for modals and sheets
    static let scrim = Color.black

    /// Standard scrim opacity for modal overlays
    static let scrimOpacity: Double = 0.5

    /// Light scrim opacity for subtle overlays
    static let scrimOpacityLight: Double = 0.3

    /// Heavy scrim opacity for loading states
    static let scrimOpacityHeavy: Double = 0.4

    // MARK: - Receipt / Conversation Theme Colors

    /// Receipt-style card background — white for clear visibility
    static let receiptBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A3A3C")
            : UIColor.white
    })

    /// Dot grid color for receipt pattern
    static let receiptDot = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3D3A37").withAlphaComponent(0.5)
            : UIColor(hex: "#D4CFC8").withAlphaComponent(0.4)
    })

    /// Receipt dashed separator line
    static let receiptSeparator = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F36D30").withAlphaComponent(0.35)
            : UIColor(hex: "#F35B16").withAlphaComponent(0.25)
    })

    /// Dotted leader line color (between label and value on receipts)
    static let receiptLeader = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#6B6560").withAlphaComponent(0.3)
            : UIColor(hex: "#C8C3BC").withAlphaComponent(0.5)
    })

    /// Timeline connector line color
    static let timelineConnector = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#545456").withAlphaComponent(0.5)
            : UIColor(hex: "#C8C3BC").withAlphaComponent(0.6)
    })

    /// Timeline circle stroke color
    static let timelineCircle = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#6B6560")
            : UIColor(hex: "#B8B3AC")
    })

    // MARK: - Conversation View Colors

    /// Conversation scroll area background — matches backgroundSecondary for consistency
    static let conversationBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#2C2C2E")
            : UIColor(hex: "#F7F5F3")
    })

    /// Transaction card background in conversation — white for clear visibility
    static let transactionCardBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A3A3C")
            : UIColor.white
    })

    /// Transaction card header accent strip — subtle accent at top of transaction cards
    static let transactionCardAccent = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#F36D30").withAlphaComponent(0.6)
            : UIColor(hex: "#F35B16").withAlphaComponent(0.4)
    })

    /// Transaction card divider color — warmer than generic dividers
    static let transactionCardDivider = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#4A4540").withAlphaComponent(0.6)
            : UIColor(hex: "#E8E2DA")
    })

    /// Date header badge background in conversations
    static let dateHeaderBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#2C2C2E").withAlphaComponent(0.85)
            : UIColor(hex: "#E8E5E1").withAlphaComponent(0.85)
    })

    /// Date header text color
    static let dateHeaderText = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#B8B3AC")
            : UIColor(hex: "#6B6560")
    })

    /// Message input area background — matches app background for consistency
    static let messageInputBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#2C2C2E")
            : UIColor(hex: "#F7F5F3")
    })

    /// Message input field background
    static let messageInputFieldBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#38383A")
            : UIColor(hex: "#EFEDEB")
    })

    /// Action bar background — matches app background for consistency
    static let actionBarBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#2C2C2E")
            : UIColor(hex: "#F7F5F3")
    })

    /// Settlement message background — muted positive for dark, subtle green tint for light
    static let settlementBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#1D3028")
            : UIColor(hex: "#E6F4EC")
    })

    /// Reminder message background — muted warning for dark, subtle amber tint for light
    static let reminderBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A2E15")
            : UIColor(hex: "#FDF5E6")
    })

    /// Reminder notification strip — red for attention
    static let reminderStripBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#8B2D2D")
            : UIColor(hex: "#E74C3C")
    })

    /// Settlement notification strip — green for positive resolution
    static let settlementStripBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(hex: "#1E6B45")
            : UIColor(hex: "#27AE60")
    })

    /// Text color used on colored notification strips
    static let stripText = Color.white

    // MARK: - Legacy Colors (for backward compatibility)

    /// Default avatar color
    static let defaultAvatarColorHex = "#F35B16"
    static let defaultAvatarColor = accent
}

// MARK: - Typography

/// Standardized typography styles
/// Font: SF Pro (system default) used consistently throughout the app
///
/// TYPE SCALE REFERENCE:
/// ───────────────────────────────────────────────────────────────────
///   TOKEN                SIZE   WEIGHT      LINE-H   TRACKING   FONT
/// ───────────────────────────────────────────────────────────────────
///   display.hero         34pt   Bold        40pt     -0.4pt     SF Pro
///   display.large        28pt   Bold        34pt     -0.3pt     SF Pro
///   display.medium       22pt   Bold        28pt     -0.2pt     SF Pro
/// ───────────────────────────────────────────────────────────────────
///   heading.large        20pt   Semibold    25pt      0         SF Pro
///   heading.medium       17pt   Semibold    22pt      0         SF Pro
///   heading.small        15pt   Semibold    20pt      0         SF Pro
/// ───────────────────────────────────────────────────────────────────
///   body.large           17pt   Regular     22pt      0         SF Pro
///   body.default         15pt   Regular     20pt      0         SF Pro
///   body.small           13pt   Regular     18pt      0         SF Pro
/// ───────────────────────────────────────────────────────────────────
///   label.large          15pt   Medium      20pt      0         SF Pro
///   label.default        13pt   Medium      18pt      0         SF Pro
///   label.small          11pt   Medium      14pt      0.1pt     SF Pro
/// ───────────────────────────────────────────────────────────────────
///   caption              11pt   Regular     14pt      0.1pt     SF Pro
/// ───────────────────────────────────────────────────────────────────
///   financial.hero       34pt   Bold        40pt     -0.4pt     SF Pro
///   financial.large      24pt   Bold        30pt     -0.2pt     SF Pro
///   financial.default    17pt   Bold        22pt      0         SF Pro
///   financial.small      13pt   Bold        18pt      0         SF Pro
/// ───────────────────────────────────────────────────────────────────
///   button.large         17pt   Semibold    22pt      0         SF Pro
///   button.default       15pt   Semibold    20pt      0         SF Pro
///   button.small         13pt   Semibold    18pt      0         SF Pro
/// ───────────────────────────────────────────────────────────────────
enum AppTypography {

    // MARK: - Type Metrics

    /// Line height values for typography scale (in points)
    enum LineHeight {
        static let displayHero: CGFloat = 40
        static let displayLarge: CGFloat = 34
        static let displayMedium: CGFloat = 28
        static let headingLarge: CGFloat = 25
        static let headingMedium: CGFloat = 22
        static let headingSmall: CGFloat = 20
        static let bodyLarge: CGFloat = 22
        static let bodyDefault: CGFloat = 20
        static let bodySmall: CGFloat = 18
        static let labelLarge: CGFloat = 20
        static let labelDefault: CGFloat = 18
        static let labelSmall: CGFloat = 14
        static let caption: CGFloat = 14
        static let financialHero: CGFloat = 40
        static let financialLarge: CGFloat = 30
        static let financialDefault: CGFloat = 22
        static let financialSmall: CGFloat = 18
        static let buttonLarge: CGFloat = 22
        static let buttonDefault: CGFloat = 20
        static let buttonSmall: CGFloat = 18
    }

    /// Tracking (letter spacing) values for typography scale (in points)
    enum Tracking {
        static let displayHero: CGFloat = -0.4
        static let displayLarge: CGFloat = -0.3
        static let displayMedium: CGFloat = -0.2
        static let headingLarge: CGFloat = 0
        static let headingMedium: CGFloat = 0
        static let headingSmall: CGFloat = 0
        static let bodyLarge: CGFloat = 0
        static let bodyDefault: CGFloat = 0
        static let bodySmall: CGFloat = 0
        static let labelLarge: CGFloat = 0
        static let labelDefault: CGFloat = 0
        static let labelSmall: CGFloat = 0.1
        static let caption: CGFloat = 0.1
        static let financialHero: CGFloat = -0.4
        static let financialLarge: CGFloat = -0.2
        static let financialDefault: CGFloat = 0
        static let financialSmall: CGFloat = 0
        static let buttonLarge: CGFloat = 0
        static let buttonDefault: CGFloat = 0
        static let buttonSmall: CGFloat = 0
    }

    // MARK: - Display (SF Pro)

    /// Display hero - 34pt bold (line: 40pt, tracking: -0.4pt)
    static func displayHero() -> Font {
        .system(size: 34, weight: .bold, design: .default)
    }

    /// Display large - 28pt bold (line: 34pt, tracking: -0.3pt)
    static func displayLarge() -> Font {
        .system(size: 28, weight: .bold, design: .default)
    }

    /// Display medium - 22pt bold (line: 28pt, tracking: -0.2pt)
    static func displayMedium() -> Font {
        .system(size: 22, weight: .bold, design: .default)
    }

    // MARK: - Headings (SF Pro)

    /// Heading large - 20pt semibold (line: 25pt)
    static func headingLarge() -> Font {
        .system(size: 20, weight: .semibold)
    }

    /// Heading medium - 17pt semibold (line: 22pt)
    static func headingMedium() -> Font {
        .system(size: 17, weight: .semibold)
    }

    /// Heading small - 15pt semibold (line: 20pt)
    static func headingSmall() -> Font {
        .system(size: 15, weight: .semibold)
    }

    // MARK: - Body (SF Pro)

    /// Body large - 17pt regular (line: 22pt)
    static func bodyLarge() -> Font {
        .system(size: 17, weight: .regular)
    }

    /// Body default - 15pt regular (line: 20pt)
    static func bodyDefault() -> Font {
        .system(size: 15, weight: .regular)
    }

    /// Body small - 13pt regular (line: 18pt)
    static func bodySmall() -> Font {
        .system(size: 13, weight: .regular)
    }

    // MARK: - Labels (SF Pro)

    /// Label large - 15pt medium (line: 20pt)
    static func labelLarge() -> Font {
        .system(size: 15, weight: .medium)
    }

    /// Label default - 13pt medium (line: 18pt)
    static func labelDefault() -> Font {
        .system(size: 13, weight: .medium)
    }

    /// Label small - 11pt medium (line: 14pt, tracking: 0.1pt)
    static func labelSmall() -> Font {
        .system(size: 11, weight: .medium)
    }

    // MARK: - Caption

    /// Caption - 11pt regular (line: 14pt, tracking: 0.1pt)
    static func caption() -> Font {
        .system(size: 11, weight: .regular)
    }

    // MARK: - Financial Numbers (with tabular/monospaced digits)

    /// Financial hero - 34pt bold, monospaced digits (line: 40pt, tracking: -0.4pt)
    static func financialHero() -> Font {
        .system(size: 34, weight: .bold, design: .default).monospacedDigit()
    }

    /// Financial large - 24pt bold, monospaced digits (line: 30pt, tracking: -0.2pt)
    static func financialLarge() -> Font {
        .system(size: 24, weight: .bold).monospacedDigit()
    }

    /// Financial default - 17pt bold, monospaced digits (line: 22pt)
    static func financialDefault() -> Font {
        .system(size: 17, weight: .bold).monospacedDigit()
    }

    /// Financial small - 13pt bold, monospaced digits (line: 18pt)
    static func financialSmall() -> Font {
        .system(size: 13, weight: .bold).monospacedDigit()
    }

    // MARK: - Button Text

    /// Button large - 17pt semibold (line: 22pt)
    static func buttonLarge() -> Font {
        .system(size: 17, weight: .semibold)
    }

    /// Button default - 15pt semibold (line: 20pt)
    static func buttonDefault() -> Font {
        .system(size: 15, weight: .semibold)
    }

    /// Button small - 13pt semibold (line: 18pt)
    static func buttonSmall() -> Font {
        .system(size: 13, weight: .semibold)
    }

}

// MARK: - Financial Number Formatter

/// Formats financial amounts according to design system rules:
/// - Currency: $ prefix, comma separators, 2 decimal places ($12,345.67)
/// - Negative amounts: minus sign (use with AppColors.negative for color)
/// - Positive amounts: optional + sign (use with AppColors.positive for color)
/// - Privacy mode: replace digits with bullet characters while preserving width
enum FinancialFormatter {

    /// Standard currency format: $12,345.67
    static func currency(_ amount: Double, showCents: Bool = true, currencySymbol: String = "$") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currencySymbol
        formatter.minimumFractionDigits = showCents ? 2 : 0
        formatter.maximumFractionDigits = showCents ? 2 : 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currencySymbol)0.00"
    }

    /// Standard currency format using a specific currency code for per-transaction display.
    static func currency(_ amount: Double, currencyCode: String, showCents: Bool = true) -> String {
        let symbol = CurrencyFormatter.symbol(for: currencyCode)
        let isZeroDecimal = CurrencyFormatter.isZeroDecimal(currencyCode)
        let effectiveShowCents = isZeroDecimal ? false : showCents
        return currency(amount, showCents: effectiveShowCents, currencySymbol: symbol)
    }

    /// Currency format with explicit sign: +$12,345.67 or -$12,345.67
    static func signedCurrency(_ amount: Double, showCents: Bool = true, currencySymbol: String = "$") -> String {
        let formatted = currency(abs(amount), showCents: showCents, currencySymbol: currencySymbol)
        if amount > 0 {
            return "+\(formatted)"
        } else if amount < 0 {
            return "-\(formatted)"
        }
        return formatted
    }

    /// Signed currency format using a specific currency code for per-transaction display.
    static func signedCurrency(_ amount: Double, currencyCode: String, showCents: Bool = true) -> String {
        let symbol = CurrencyFormatter.symbol(for: currencyCode)
        let isZeroDecimal = CurrencyFormatter.isZeroDecimal(currencyCode)
        let effectiveShowCents = isZeroDecimal ? false : showCents
        return signedCurrency(amount, showCents: effectiveShowCents, currencySymbol: symbol)
    }

    /// Privacy mode: masks digits with bullet characters (preserves layout width)
    /// e.g., "$12,345.67" becomes "$••,•••.••"
    static func masked(_ amount: Double, showCents: Bool = true, currencySymbol: String = "$") -> String {
        let formatted = currency(amount, showCents: showCents, currencySymbol: currencySymbol)
        return formatted.map { char in
            char.isNumber ? "•" : char
        }.map(String.init).joined()
    }

    /// Compact format for large numbers: $12.3K, $1.5M, $2.1B
    static func compact(_ amount: Double, currencySymbol: String = "$") -> String {
        let absAmount = abs(amount)
        let sign = amount < 0 ? "-" : ""

        switch absAmount {
        case 1_000_000_000...:
            return "\(sign)\(currencySymbol)\(String(format: "%.1f", absAmount / 1_000_000_000))B"
        case 1_000_000...:
            return "\(sign)\(currencySymbol)\(String(format: "%.1f", absAmount / 1_000_000))M"
        case 1_000...:
            return "\(sign)\(currencySymbol)\(String(format: "%.1f", absAmount / 1_000))K"
        default:
            return currency(amount, showCents: false, currencySymbol: currencySymbol)
        }
    }

    /// Percentage format: 12.5%
    static func percentage(_ value: Double, decimalPlaces: Int = 1) -> String {
        return String(format: "%.\(decimalPlaces)f%%", value)
    }

    /// Signed percentage: +12.5% or -12.5%
    static func signedPercentage(_ value: Double, decimalPlaces: Int = 1) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.\(decimalPlaces)f", value))%"
    }
}

// MARK: - Button Styles

/// Standard button style with scale animation
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppAnimation.fast, value: configuration.isPressed)
    }
}

/// Primary action button style - orange accent
struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.buttonDefault())
            .foregroundColor(isEnabled ? AppColors.buttonForeground : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .fill(isEnabled ? AppColors.buttonBackground : AppColors.disabled)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppAnimation.fast, value: configuration.isPressed)
    }
}

/// Secondary action button style - outlined with accent text
struct SecondaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.buttonDefault())
            .foregroundColor(isEnabled ? AppColors.accent : AppColors.disabled)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.button)
                            .strokeBorder(isEnabled ? AppColors.accent : AppColors.disabled, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppAnimation.fast, value: configuration.isPressed)
    }
}

/// Ghost button style - no background, secondary text
struct GhostButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.buttonDefault())
            .foregroundColor(isEnabled ? AppColors.textSecondary : AppColors.disabled)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(AppAnimation.fast, value: configuration.isPressed)
    }
}

/// Destructive button style - red fill
struct DestructiveButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.buttonDefault())
            .foregroundColor(isEnabled ? AppColors.onAccent : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .fill(isEnabled ? AppColors.negative : AppColors.disabled)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppAnimation.fast, value: configuration.isPressed)
    }
}

// MARK: - Validation Constants

/// Input validation limits for text fields and data entry
enum ValidationLimits {
    static let maxNameLength = 100
    static let maxDisplayNameLength = 50
    static let maxPhoneLength = 20
    static let maxEmailLength = 254
    static let maxTransactionTitleLength = 200
    static let maxNoteLength = 1000
    static let maxMessageLength = 500
    static let maxTransactionAmount: Double = 1_000_000
    static let maxSubscriptionAmount: Double = 100_000
}

// MARK: - Card Style Modifier

/// Card style modifier that uses environment to get proper shadow colors
private struct CardStyleModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let isElevated: Bool

    func body(content: Content) -> some View {
        let shadow = isElevated
            ? AppShadow.elevated(for: colorScheme)
            : AppShadow.card(for: colorScheme)

        content
            .padding(Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(isElevated ? AppColors.elevatedSurface : AppColors.cardBackground)
                    .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Applies standard card styling with shadow
    /// Card: bg=elevated surface, radius=14pt (CornerRadius.card), shadow, no border, padding=16pt
    func cardStyle() -> some View {
        self.modifier(CardStyleModifier(isElevated: false))
    }

    /// Applies elevated card styling
    /// Elevated card: higher shadow for modals/sheets
    func elevatedCardStyle() -> some View {
        self.modifier(CardStyleModifier(isElevated: true))
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

    // MARK: - Typography Style Modifiers

    /// Applies display hero style with proper tracking
    func displayHeroStyle() -> some View {
        self
            .font(AppTypography.displayHero())
            .tracking(AppTypography.Tracking.displayHero)
    }

    /// Applies display large style with proper tracking
    func displayLargeStyle() -> some View {
        self
            .font(AppTypography.displayLarge())
            .tracking(AppTypography.Tracking.displayLarge)
    }

    /// Applies display medium style with proper tracking
    func displayMediumStyle() -> some View {
        self
            .font(AppTypography.displayMedium())
            .tracking(AppTypography.Tracking.displayMedium)
    }

    /// Applies financial hero style with proper tracking and monospaced digits
    func financialHeroStyle() -> some View {
        self
            .font(AppTypography.financialHero())
            .tracking(AppTypography.Tracking.financialHero)
    }

    /// Applies financial large style with proper tracking and monospaced digits
    func financialLargeStyle() -> some View {
        self
            .font(AppTypography.financialLarge())
            .tracking(AppTypography.Tracking.financialLarge)
    }

    /// Applies label small style with proper tracking
    func labelSmallStyle() -> some View {
        self
            .font(AppTypography.labelSmall())
            .tracking(AppTypography.Tracking.labelSmall)
    }

    /// Applies caption style with proper tracking
    func captionStyle() -> some View {
        self
            .font(AppTypography.caption())
            .tracking(AppTypography.Tracking.caption)
    }
}

// MARK: - Text Extension for Financial Amounts

extension Text {
    /// Creates a Text view formatted as a financial amount with proper styling
    /// Automatically uses tabular/monospaced digits and semantic coloring
    static func financialAmount(
        _ amount: Double,
        style: FinancialAmountStyle = .default,
        showSign: Bool = false,
        showCents: Bool = true,
        currencySymbol: String = "$"
    ) -> some View {
        let formatted = showSign
            ? FinancialFormatter.signedCurrency(amount, showCents: showCents, currencySymbol: currencySymbol)
            : FinancialFormatter.currency(amount, showCents: showCents, currencySymbol: currencySymbol)

        let font: Font
        switch style {
        case .hero:
            font = AppTypography.financialHero()
        case .large:
            font = AppTypography.financialLarge()
        case .default:
            font = AppTypography.financialDefault()
        case .small:
            font = AppTypography.financialSmall()
        }

        return Text(formatted)
            .font(font)
    }

    /// Financial amount style size options
    enum FinancialAmountStyle {
        case hero
        case large
        case `default`
        case small
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - Flow Layout

/// A wrapping flow layout that arranges subviews horizontally and wraps to the next line when needed.
/// Requires iOS 16+ (Layout protocol).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (positions, CGSize(width: maxX, height: currentY + lineHeight))
    }
}

// MARK: - Shapes

/// A simple horizontal line shape for use with `.stroke()` modifiers.
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}
