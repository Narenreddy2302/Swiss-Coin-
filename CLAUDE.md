# Swiss Coin — Design System Reference

Premium finance app — warm, data-focused, MVVM + SwiftUI + CoreData.
Source of truth: `Swiss Coin/Utilities/DesignSystem.swift`. All colors are dynamic (auto light/dark via `UIColor { tc in … }`).

## Critical Rules

- **ALWAYS** use `AppColors.xxx` — **NEVER** hardcode hex values
- **NEVER** use SwiftUI system colors (`.red`, `.blue`, `.gray`) — use semantic tokens
- **ALWAYS** use `AppTypography.xxx()` — **NEVER** use raw `.font(.system(...))`
- **ALWAYS** use `Spacing.xxx` — **NEVER** hardcode padding/margin values
- **ALWAYS** use `CornerRadius.xxx` — **NEVER** hardcode corner radii
- Use semantic color names matching purpose: `positive` for income (not "green"), `negative` for expenses (not "red")
- Use `FinancialFormatter.currency()` / `.signedCurrency()` for money display
- Use `.cardStyle()` view modifier for standard cards — don't manually assemble card backgrounds
- Only exception for `.font(.system(size:))`: SF Symbol icons using `IconSize.xxx`
- Reference `DesignSystem.swift` for any token not listed here

## Colors — Brand & Accent

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `accent` | `#F35B16` | `#F36D30` | CTAs, active states, links |
| `accentPressed` | `#D94E12` | `#E05A1A` | Tap/press state |
| `accentMuted` | `#FEF0EA` | `#3D2215` | Subtle accent backgrounds |
| `onAccent` | white | white | Text on accent surfaces |

## Colors — Text Hierarchy

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `textPrimary` | `#22201D` | `#F5F5F3` | Primary text (warm near-black) |
| `textSecondary` | `#6B6560` | `#A8A29E` | Supporting/descriptive text |
| `textTertiary` | `#A8A29E` | `#6B6560` | Captions, timestamps, muted |
| `textDisabled` | `#D4D0CC` | `#3D3A37` | Disabled text |
| `textInverse` | white | `#22201D` | Text on opposite-mode surfaces |
| `textLink` | `#F35B16` | `#F36D30` | Tappable link text (= accent) |

## Colors — Backgrounds (Layered Depth)

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `background` | white | `#1C1C1E` | Layer 0 — main screen |
| `backgroundSecondary` | `#F7F5F3` | `#2C2C2E` | Layer 1 — grouped/inset |
| `backgroundTertiary` | `#EFEDEB` | `#3A3A3C` | Layer 2 — nested surfaces |
| `cardBackground` | white | `#3A3A3C` | Card surfaces |
| `cardBackgroundElevated` | white | `#48484A` | Higher elevation cards |
| `elevatedSurface` | white | `#3A3A3C` | Sheets, modals (use with shadow) |
| `surface` | `#F7F5F3` | `#2C2C2E` | Search bars, input fields |
| `groupedBackground` | `#F7F5F3` | `#1C1C1E` | Grouped list background |

## Colors — Borders & Dividers

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `border` | `#E8E5E1` | `#3A3A3C` | Default border |
| `borderStrong` | `#D4D0CC` | `#545456` | Emphasized border |
| `borderSubtle` | `#F0EDEA` | `#2C2C2E` | Minimal border |
| `borderFocus` | `#F35B16` | `#F36D30` | Input focus ring (= accent) |
| `divider` | `#F0EDEA` | `#38383A` | Hairline list separators |
| `separator` | `#F0EDEA` | `#38383A` | Legacy alias for divider |

## Colors — Semantic Financial

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `positive` | `#1B8A5A` | `#34C77B` | Income, gains, "owes you" |
| `positiveMuted` | `#E8F5EE` | `#1A3328` | Positive background tint |
| `negative` | `#D93025` | `#F87171` | Expenses, losses, "you owe" |
| `negativeMuted` | `#FDF0EF` | `#3D1F1F` | Negative background tint |
| `neutral` | `#6B6560` | `#A8A29E` | Settled, balanced |
| `neutralMuted` | `#F7F5F3` | `#2C2C2E` | Neutral background tint |
| `warning` | `#D97706` | `#FBBF24` | Caution, pending |
| `warningMuted` | `#FEF9EC` | `#3D3015` | Warning background tint |
| `info` | `#2563EB` | `#60A5FA` | Informational, upcoming |
| `infoMuted` | `#EFF6FF` | `#1E2A3D` | Info background tint |

## Colors — Interactive States

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `hoverBackground` | `#F7F5F3` | `#3A3A3C` | Hover state |
| `pressedBackground` | `#EFEDEB` | `#545456` | Pressed state |
| `selectedBackground` | `#FEF0EA` | `#3D2215` | Selected/active row |
| `disabled` | secondaryLabel@38% | secondaryLabel@38% | Disabled elements |
| `buttonBackground` | `#F35B16` | `#F36D30` | Primary button fill (= accent) |
| `buttonForeground` | white | white | Primary button text |

## Colors — Conversation & Messages

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `userBubble` | white | `#3A3A3C` | Current user message bubble |
| `userBubbleText` | `#22201D` | `#F5F5F3` | Text in user bubble |
| `otherBubble` | `#F0EDE8` | `#2C2C2E` | Other person message bubble |
| `otherBubbleText` | `#22201D` | `#F5F5F3` | Text in other bubble |
| `conversationBackground` | `#F7F5F3` | `#2C2C2E` | Chat scroll area |
| `messageInputBackground` | `#F7F5F3` | `#2C2C2E` | Input bar area |
| `messageInputFieldBackground` | `#EFEDEB` | `#38383A` | Text input field |
| `actionBarBackground` | `#F7F5F3` | `#2C2C2E` | Action bar area |
| `settlementBackground` | `#E6F4EC` | `#1D3028` | Settlement message bg |
| `reminderBackground` | `#FDF5E6` | `#3A2E15` | Reminder message bg |
| `settlementStripBackground` | `#27AE60` | `#1E6B45` | Settlement notification strip |
| `reminderStripBackground` | `#E74C3C` | `#8B2D2D` | Reminder notification strip |
| `stripText` | white | white | Text on colored strips |

## Colors — Specialty

**Asset classes:** `assetCash`(green), `assetInvestments`(blue), `assetRealEstate`(purple), `assetCrypto`(violet), `assetVehicles`(cyan), `assetOther`(gray)

**Liabilities:** `liabilityCreditCards`(red), `liabilityLoans`(yellow), `liabilityMortgages`(amber), `liabilityOther`(orange)

**Budget status:** `budgetUnder`(green), `budgetOn`(gray), `budgetOver`(red)

**Charts:** `chartSeries1`–`chartSeries8` (accent, blue, green, purple, amber, cyan, pink, gray), `chartGrid`, `chartAxisLabels`

**Receipt theme:** `receiptBackground`, `receiptDot`, `receiptSeparator`, `receiptLeader`

**Timeline:** `timelineConnector`, `timelineCircle`

**Transaction cards:** `transactionCardBackground`, `transactionCardAccent`, `transactionCardDivider`, `dateHeaderBackground`, `dateHeaderText`

**Shadows:** `shadow`(8%/24%), `shadowSubtle`(4%/16%), `shadowMicro`(2%/12%) + `AppShadow.card()`, `.elevated()`, `.bubble()`

**Overlay:** `scrim` (black) + `scrimOpacity`(0.5), `scrimOpacityLight`(0.3), `scrimOpacityHeavy`(0.4)

## Typography

| Token | Size | Weight | Use |
|-------|------|--------|-----|
| `displayHero()` | 34 | Bold | Hero amounts, big numbers |
| `displayLarge()` | 28 | Bold | Screen titles |
| `displayMedium()` | 22 | Bold | Section headers |
| `headingLarge()` | 20 | Semibold | Card titles |
| `headingMedium()` | 17 | Semibold | Row titles, form labels |
| `headingSmall()` | 15 | Semibold | Small headings |
| `bodyLarge()` | 17 | Regular | Primary body text |
| `bodyDefault()` | 15 | Regular | Default body text |
| `bodySmall()` | 13 | Regular | Secondary body text |
| `labelLarge()` | 15 | Medium | Emphasized labels |
| `labelDefault()` | 13 | Medium | Standard labels |
| `labelSmall()` | 11 | Medium | Tags, badges |
| `caption()` | 11 | Regular | Timestamps, footnotes |
| `financialHero()` | 34 | Bold mono | Hero balance display |
| `financialLarge()` | 24 | Bold mono | Large amounts |
| `financialDefault()` | 17 | Bold mono | Inline amounts |
| `financialSmall()` | 13 | Bold mono | Compact amounts |
| `buttonLarge()` | 17 | Semibold | Primary buttons |
| `buttonDefault()` | 15 | Semibold | Standard buttons |
| `buttonSmall()` | 13 | Semibold | Compact buttons |

Style modifiers with tracking: `.displayHeroStyle()`, `.displayLargeStyle()`, `.displayMediumStyle()`, `.financialHeroStyle()`, `.financialLargeStyle()`, `.labelSmallStyle()`, `.captionStyle()`

Sub-enums: `AppTypography.LineHeight.tokenName`, `AppTypography.Tracking.tokenName`

## Spacing (8pt grid)

| Token | Value | Use |
|-------|-------|-----|
| `xxs` | 2 | Micro gaps |
| `xs` | 4 | Tight internal gaps |
| `sm` | 8 | Default internal spacing |
| `md` | 12 | Between elements in a card |
| `lg` | 16 | Card padding, screen margins |
| `xl` | 20 | Between card groups |
| `xxl` | 24 | Major section gaps |
| `xxxl` | 32 | Hero area breathing room |

**Named:** `screenHorizontal`(16), `screenTopPad`(8), `cardPadding`(16), `cardGap`(12), `rowHeight`(60), `rowDividerInset`(52), `settingsRowDividerInset`(70), `sectionGap`(24), `modalTopMargin`(12), `compactVertical`(6)

## Other Design Tokens

**CornerRadius:** `small`(6) tags/badges, `medium`(10) inputs, `button`(12) buttons, `card`(14) cards/sheets, `large`(16) hero containers, `extraLarge`(20) feature cards, `full`(9999) pills

**IconSize:** `xs`(12), `sm`(16), `md`(20), `lg`(24) tab bar, `category`(28), `categoryBackground`(36), `xl`(32), `xxl`(48)

**AvatarSize:** `xs`(32) compact lists, `sm`(36) dense headers, `md`(44) standard rows, `lg`(48) emphasized, `xl`(80) profile headers, `xxl`(100) detail views

**ButtonHeight:** `sm`(36) compact, `md`(44) standard, `input`(48) fields, `lg`(50) primary action, `xl`(56) hero

## Button Styles

| Style | Use |
|-------|-----|
| `PrimaryButtonStyle` | Main CTAs — accent fill, white text |
| `SecondaryButtonStyle` | Secondary actions — accent outline, accent text |
| `GhostButtonStyle` | Tertiary actions — no background, secondary text |
| `DestructiveButtonStyle` | Dangerous actions — negative (red) fill, white text |
| `AppButtonStyle` | Generic scale+opacity animation, optional haptic |

All accept `isEnabled:` parameter. All use `CornerRadius.button`(12), `ButtonHeight.lg`(50).

## Button System

See **[BUTTONS.md](docs/design-system/BUTTONS.md)** for the complete button standard.

### Quick Rules (MANDATORY)
1. **Always use button styles** — `PrimaryButtonStyle`, `SecondaryButtonStyle`, `GhostButtonStyle`, `DestructiveButtonStyle`, or `AppButtonStyle`
2. **Always use design tokens** — `ButtonHeight.*`, `CornerRadius.button`, `AppColors.buttonBackground`, `IconSize.sm`
3. **Always pair haptic feedback** — every interactive button gets a `HapticManager.*` call
4. **Always add accessibility** — `.accessibilityLabel()` on icon-only buttons
5. **Never hardcode** colors, heights, corner radii, or font sizes for buttons

## Common Patterns

- **Card:** `.cardStyle()` modifier (= `cardBackground` + `CornerRadius.card` + `AppShadow.card()` + `Spacing.cardPadding`)
- **Financial display:** `positive` for amount > 0, `negative` for amount < 0, `neutral` for 0
- **Empty states:** `textSecondary` + `headingLarge()` centered
- **Screen structure:** `backgroundSecondary` base + `.padding(.horizontal, Spacing.xl)` + `.padding(.top, Spacing.screenTopPad)`
- **Amounts:** `FinancialFormatter.currency()`, `.signedCurrency()`, `.compact()`, `.masked()`, `.percentage()`
- **Current user:** `CurrentUser.isCurrentUser()`, `CurrentUser.currentUserId`

## Build & Architecture

- Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Swiss Coin" -project "Swiss Coin.xcodeproj" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Architecture: MVVM + SwiftUI + CoreData
- CoreData entities: `FinancialTransaction`, `TransactionSplit`, `TransactionPayer`, `Person`, `UserGroup`
- Balance calc: net-position algorithm via `pairwiseBalance()` on `FinancialTransaction`
- Multi-payer: `effectivePayers` handles backward compat with legacy single `payer` field
- Theme switching: `ThemeTransitionManager.shared.transition(to:)` — light/dark/system with cross-fade
- `Color(hex:)` initializer, `.toHex()`, `.isLight`, `.contrastingColor` via `Color+Hex.swift`
- Key paths: `Swiss Coin/Features/{Auth,Home,People,Profile,QuickAction,Search,Subscriptions,Transactions}/`
