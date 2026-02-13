# Swiss Coin Typography Standard

> Comprehensive typography guidelines for consistent, professional font usage across the entire application.

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Font Family](#font-family)
3. [Type Scale Reference](#type-scale-reference)
4. [Typography Tokens](#typography-tokens)
5. [Usage Rules by Context](#usage-rules-by-context)
6. [Font Weight Hierarchy](#font-weight-hierarchy)
7. [No Rounded Fonts](#no-rounded-fonts)
8. [Tracking & Line Height](#tracking--line-height)
9. [Component-Level Mapping](#component-level-mapping)
10. [Rules & Enforcement](#rules--enforcement)

---

## Design Principles

1. **Consistency**: Every text element must use an `AppTypography` token. No raw `.system(size:)` calls for text content.
2. **Hierarchy**: Font sizes and weights establish a clear visual hierarchy — larger/bolder = more important.
3. **Professionalism**: Clean, sharp typography with no rounded font designs. All fonts use `.default` design.
4. **Readability**: Sufficient size and contrast for all text. Minimum 11pt for any visible text.
5. **Semantic Naming**: Typography tokens describe their purpose (display, heading, body, label, caption, financial, button), not their appearance.

---

## Font Family

- **Primary Font**: SF Pro (Apple system font)
- **Design**: `.default` only — **never** `.rounded`, `.serif`, or `.monospaced` (except for financial digits)
- **Financial Numbers**: SF Pro with `.monospacedDigit()` for tabular alignment of currency values

---

## Type Scale Reference

```
TOKEN                 SIZE    WEIGHT      LINE-H   TRACKING   USAGE
─────────────────────────────────────────────────────────────────────────────────
DISPLAY (Bold — Page titles, hero numbers)
  display.hero        34pt    Bold        40pt     -0.4pt     Main screen titles, hero amounts
  display.large       28pt    Bold        34pt     -0.3pt     Section hero titles
  display.medium      22pt    Bold        28pt     -0.2pt     Sheet/modal titles, section headers

HEADING (Semibold — Section titles, card headers)
  heading.large       20pt    Semibold    25pt      0         Card titles, major section headers
  heading.medium      17pt    Semibold    22pt      0         Card subtitles, row primary text
  heading.small       15pt    Semibold    20pt      0         Small section titles, emphasized labels

BODY (Regular — Reading text, descriptions)
  body.large          17pt    Regular     22pt      0         Primary content text, form labels
  body.default        15pt    Regular     20pt      0         Standard body text, descriptions
  body.small          13pt    Regular     18pt      0         Secondary text, supporting info

LABEL (Medium — UI labels, metadata)
  label.large         15pt    Medium      20pt      0         Form field labels, tab labels
  label.default       13pt    Medium      18pt      0         Metadata, tags, status text
  label.small         11pt    Medium      14pt      0.1pt     Badges, micro labels, overlines

CAPTION (Regular — Timestamps, fine print)
  caption             11pt    Regular     14pt      0.1pt     Timestamps, footnotes, hints

FINANCIAL (Bold + Monospaced Digits — Currency values)
  financial.hero      34pt    Bold        40pt     -0.4pt     Hero balance amount
  financial.large     24pt    Bold        30pt     -0.2pt     Card balance amounts
  financial.default   17pt    Bold        22pt      0         List item amounts, inline amounts
  financial.small     13pt    Bold        18pt      0         Small amounts, per-unit cost

BUTTON (Semibold — Interactive elements)
  button.large        17pt    Semibold    22pt      0         Primary full-width buttons
  button.default      15pt    Semibold    20pt      0         Standard buttons, toolbar items
  button.small        13pt    Semibold    18pt      0         Compact buttons, text links
─────────────────────────────────────────────────────────────────────────────────
```

---

## Typography Tokens

All text **must** use one of these `AppTypography` function calls:

### Display
| Token | Code | When to Use |
|-------|------|-------------|
| Display Hero | `AppTypography.displayHero()` | Main screen title (e.g., "Home"), hero balance |
| Display Large | `AppTypography.displayLarge()` | Page-level titles (e.g., "Transactions", "People") |
| Display Medium | `AppTypography.displayMedium()` | Sheet titles, modal headers, section hero text |

### Heading
| Token | Code | When to Use |
|-------|------|-------------|
| Heading Large | `AppTypography.headingLarge()` | Card titles, section headers within a page |
| Heading Medium | `AppTypography.headingMedium()` | List row primary text, card subtitles |
| Heading Small | `AppTypography.headingSmall()` | Small section titles, emphasized row text |

### Body
| Token | Code | When to Use |
|-------|------|-------------|
| Body Large | `AppTypography.bodyLarge()` | Primary readable text, form descriptions |
| Body Default | `AppTypography.bodyDefault()` | Standard body text, secondary descriptions |
| Body Small | `AppTypography.bodySmall()` | Tertiary text, supporting information |

### Label
| Token | Code | When to Use |
|-------|------|-------------|
| Label Large | `AppTypography.labelLarge()` | Form field labels, navigation tab text |
| Label Default | `AppTypography.labelDefault()` | Metadata, category tags, status indicators |
| Label Small | `AppTypography.labelSmall()` | Badges, overline text, micro labels |

### Caption
| Token | Code | When to Use |
|-------|------|-------------|
| Caption | `AppTypography.caption()` | Timestamps, footnotes, helper text |

### Financial
| Token | Code | When to Use |
|-------|------|-------------|
| Financial Hero | `AppTypography.financialHero()` | Home screen total balance |
| Financial Large | `AppTypography.financialLarge()` | Card-level balance, person detail balance |
| Financial Default | `AppTypography.financialDefault()` | List row amounts, inline monetary values |
| Financial Small | `AppTypography.financialSmall()` | Small amounts, per-member cost |

### Button
| Token | Code | When to Use |
|-------|------|-------------|
| Button Large | `AppTypography.buttonLarge()` | Primary full-width action buttons |
| Button Default | `AppTypography.buttonDefault()` | Standard buttons, secondary actions |
| Button Small | `AppTypography.buttonSmall()` | Compact inline buttons, text-style actions |

---

## Usage Rules by Context

### Navigation & Screen Titles
- **Navigation bar title**: `AppTypography.headingMedium()` (17pt semibold)
- **Large navigation title**: `AppTypography.displayLarge()` (28pt bold)
- **Sheet/modal title**: `AppTypography.displayMedium()` (22pt bold)
- **Section header on page**: `AppTypography.headingLarge()` (20pt semibold)

### Cards
- **Card title**: `AppTypography.headingMedium()` (17pt semibold)
- **Card subtitle/description**: `AppTypography.bodyDefault()` (15pt regular)
- **Card amount**: `AppTypography.financialDefault()` (17pt bold mono)
- **Card metadata**: `AppTypography.labelDefault()` (13pt medium)
- **Card timestamp**: `AppTypography.caption()` (11pt regular)

### List Rows
- **Primary text (name)**: `AppTypography.headingMedium()` (17pt semibold)
- **Secondary text (description)**: `AppTypography.bodyDefault()` (15pt regular)
- **Tertiary text (date/time)**: `AppTypography.bodySmall()` (13pt regular)
- **Amount**: `AppTypography.financialDefault()` (17pt bold mono)
- **Small amount**: `AppTypography.financialSmall()` (13pt bold mono)

### Forms & Input
- **Field label**: `AppTypography.labelLarge()` (15pt medium)
- **Field value/input text**: `AppTypography.bodyLarge()` (17pt regular)
- **Placeholder text**: `AppTypography.bodyLarge()` (17pt regular) with `.textTertiary` color
- **Helper/error text**: `AppTypography.bodySmall()` (13pt regular)
- **Section header in form**: `AppTypography.headingSmall()` (15pt semibold)

### Conversations & Messages
- **Message text**: `AppTypography.bodyDefault()` (15pt regular)
- **Sender name**: `AppTypography.headingSmall()` (15pt semibold)
- **Timestamp**: `AppTypography.caption()` (11pt regular)
- **Date separator**: `AppTypography.labelSmall()` (11pt medium)

### Financial Displays
- **Hero balance (top of screen)**: `AppTypography.financialHero()` (34pt bold mono)
- **Card balance**: `AppTypography.financialLarge()` (24pt bold mono)
- **Inline amount**: `AppTypography.financialDefault()` (17pt bold mono)
- **Small amount (per-member)**: `AppTypography.financialSmall()` (13pt bold mono)

### Buttons & Actions
- **Primary button**: `AppTypography.buttonLarge()` (17pt semibold)
- **Standard button**: `AppTypography.buttonDefault()` (15pt semibold)
- **Small/compact button**: `AppTypography.buttonSmall()` (13pt semibold)
- **Text link**: `AppTypography.buttonSmall()` (13pt semibold) with accent color

### Badges, Tags & Status
- **Status pill text**: `AppTypography.labelSmall()` (11pt medium)
- **Tag/chip text**: `AppTypography.labelDefault()` (13pt medium)
- **Badge number**: `AppTypography.labelSmall()` (11pt medium)

### Empty States & Onboarding
- **Empty state title**: `AppTypography.displayMedium()` (22pt bold)
- **Empty state description**: `AppTypography.bodyDefault()` (15pt regular)
- **Onboarding title**: `AppTypography.displayLarge()` (28pt bold)
- **Onboarding description**: `AppTypography.bodyLarge()` (17pt regular)

### Profile & Settings
- **Profile name**: `AppTypography.displayMedium()` (22pt bold)
- **Settings section header**: `AppTypography.headingSmall()` (15pt semibold)
- **Settings row label**: `AppTypography.bodyLarge()` (17pt regular)
- **Settings row detail/value**: `AppTypography.bodyDefault()` (15pt regular)
- **Settings description**: `AppTypography.bodySmall()` (13pt regular)

---

## Font Weight Hierarchy

Font weights are strictly tied to token categories. Do **not** apply `.fontWeight()` modifiers to override `AppTypography` weights.

| Weight | Value | Used In |
|--------|-------|---------|
| **Bold** | `.bold` | Display tokens, Financial tokens |
| **Semibold** | `.semibold` | Heading tokens, Button tokens |
| **Medium** | `.medium` | Label tokens |
| **Regular** | `.regular` | Body tokens, Caption |

### Rules:
- **Never** use `.fontWeight(.bold)` on body text — use a `heading` or `financial` token instead.
- **Never** use `.fontWeight(.semibold)` after applying an AppTypography token — choose the correct token.
- **Only** use `.fontWeight(.bold)` inside `Text` concatenation for inline emphasis (e.g., bold amount within a sentence).
- **Never** use `.fontWeight(.medium)` to modify body text — use a `label` token instead.

---

## No Rounded Fonts

**Rule**: All typography must use `.design: .default` (the standard SF Pro design). The `.rounded` design is explicitly prohibited throughout the app.

- All `AppTypography` functions already use `.default` design
- Do not use `.fontDesign(.rounded)` anywhere
- Do not use `.system(size:weight:design: .rounded)` anywhere
- The only design variation allowed is `.monospacedDigit()` on financial tokens

---

## Tracking & Line Height

### Tracking (Letter Spacing)
Use `AppTypography.Tracking.*` constants. **Never** hardcode tracking values.

| Token | Value | Applies To |
|-------|-------|------------|
| `Tracking.displayHero` | -0.4pt | Display hero text |
| `Tracking.displayLarge` | -0.3pt | Display large text |
| `Tracking.displayMedium` | -0.2pt | Display medium text |
| `Tracking.labelSmall` | 0.1pt | Label small, overlines |
| `Tracking.caption` | 0.1pt | Caption text |
| `Tracking.financialHero` | -0.4pt | Financial hero |
| `Tracking.financialLarge` | -0.2pt | Financial large |
| All others | 0pt | No tracking adjustment needed |

### Applying Tracking
For tokens that require tracking, use the style modifier helpers:
```swift
// Correct - use style modifier for tokens with tracking
Text("Title").displayHeroStyle()
Text("$12,345").financialHeroStyle()
Text("OVERLINE").labelSmallStyle()
Text("12:30 PM").captionStyle()

// Correct - manual tracking when needed
Text("Title")
    .font(AppTypography.displayLarge())
    .tracking(AppTypography.Tracking.displayLarge)

// Wrong - hardcoded tracking
Text("Label").tracking(0.5)  // NEVER do this
```

---

## Component-Level Mapping

### Global Components

| Component | Element | Token |
|-----------|---------|-------|
| ActionBarButton | Label (compact) | `AppTypography.buttonSmall()` |
| ActionBarButton | Label (standard) | `AppTypography.buttonDefault()` |
| ActionHeaderButton | Icon | Use `IconSize` enum (not font) |
| ConversationAvatarView | Initials | Dynamic `size * 0.38` (acceptable) |
| FeedItemRow | Name | `AppTypography.headingSmall()` |
| FeedItemRow | Description | `AppTypography.bodySmall()` |
| FeedItemRow | Timestamp | `AppTypography.caption()` |
| FeedItemRow | Amount | `AppTypography.financialSmall()` |
| FeedMessageContent | Message text | `AppTypography.bodyDefault()` |
| FeedSystemContent | Type label | `AppTypography.labelSmall()` |
| FeedSystemContent | Body | `AppTypography.bodySmall()` |
| FeedTransactionContent | Title | `AppTypography.headingSmall()` |
| FeedTransactionContent | Amount | `AppTypography.financialDefault()` |
| SystemMessageView | Type label | `AppTypography.labelSmall()` |
| SystemMessageView | Body | `AppTypography.bodySmall()` |

### Home Feature

| Component | Element | Token |
|-----------|---------|-------|
| HomeView | Screen title | `AppTypography.displayLarge()` |
| HomeView | Balance amount | `AppTypography.financialHero()` |
| HomeView | Section header | `AppTypography.headingLarge()` |
| ProfileButton | Initial | Dynamic (acceptable for avatar) |

### People Feature

| Component | Element | Token |
|-----------|---------|-------|
| PeopleView | Screen title | `AppTypography.displayLarge()` |
| PersonDetailView | Person name | `AppTypography.displayMedium()` |
| PersonDetailView | Balance | `AppTypography.financialLarge()` |
| PersonDetailView | Section header | `AppTypography.headingSmall()` |
| PersonConversationView | Nav title | `AppTypography.headingMedium()` |
| AddPersonView | Title | `AppTypography.displayMedium()` |
| AddPersonView | Field label | `AppTypography.labelLarge()` |
| AddPersonView | Field input | `AppTypography.bodyLarge()` |
| GroupDetailView | Group name | `AppTypography.displayMedium()` |
| GroupDetailView | Member name | `AppTypography.headingMedium()` |
| BalanceHeaderView | Balance amount | `AppTypography.financialLarge()` |
| BalanceHeaderView | Label | `AppTypography.labelDefault()` |
| TransactionCardView | Title | `AppTypography.headingSmall()` |
| TransactionCardView | Amount | `AppTypography.financialDefault()` |
| TransactionCardView | Date | `AppTypography.caption()` |
| MessageBubbleView | Text | `AppTypography.bodyDefault()` |
| MessageInputView | Input text | `AppTypography.bodyLarge()` |
| DateHeaderView | Date text | `AppTypography.labelSmall()` |
| SettlementView | Title | `AppTypography.displayMedium()` |
| SettlementView | Amount | `AppTypography.financialLarge()` |
| ReminderSheetView | Title | `AppTypography.displayMedium()` |

### Profile Feature

| Component | Element | Token |
|-----------|---------|-------|
| ProfileView | User name | `AppTypography.displayMedium()` |
| ProfileView | Settings row label | `AppTypography.bodyLarge()` |
| ProfileView | Settings row detail | `AppTypography.bodyDefault()` |
| ProfileView | Section header | `AppTypography.headingSmall()` |
| PersonalDetailsView | Display name | `AppTypography.displayLarge()` |
| PersonalDetailsView | Field label | `AppTypography.labelLarge()` |
| PersonalDetailsView | Field value | `AppTypography.bodyLarge()` |
| AppearanceSettingsView | Title | `AppTypography.displayMedium()` |
| AppearanceSettingsView | Option label | `AppTypography.bodyLarge()` |
| CurrencySettingsView | Preview amount | `AppTypography.financialHero()` |
| CurrencySettingsView | Currency label | `AppTypography.bodyLarge()` |
| PrivacySecurityView | Toggle label | `AppTypography.bodyLarge()` |
| PrivacySecurityView | Description | `AppTypography.bodySmall()` |
| NotificationSettingsView | Toggle label | `AppTypography.bodyLarge()` |

### Subscriptions Feature

| Component | Element | Token |
|-----------|---------|-------|
| SubscriptionView | Screen title | `AppTypography.displayLarge()` |
| SubscriptionDetailView | Name | `AppTypography.displayMedium()` |
| SubscriptionDetailView | Amount | `AppTypography.financialLarge()` |
| SubscriptionListRowView | Name | `AppTypography.headingMedium()` |
| SubscriptionListRowView | Amount | `AppTypography.financialDefault()` |
| SubscriptionListRowView | Frequency | `AppTypography.bodySmall()` |
| StatusPill | Text | `AppTypography.labelSmall()` |
| MemberChip | Name | `AppTypography.labelDefault()` |
| SubscriptionInfoCard | Label | `AppTypography.bodyDefault()` |
| SubscriptionInfoCard | Value | `AppTypography.headingMedium()` |
| SubscriptionCostSummaryCard | Label | `AppTypography.bodyDefault()` |
| SubscriptionCostSummaryCard | Amount | `AppTypography.financialDefault()` |

### Transactions Feature

| Component | Element | Token |
|-----------|---------|-------|
| TransactionHistoryView | Title | `AppTypography.displayLarge()` |
| TransactionHistoryView | Amount | `AppTypography.financialHero()` |
| TransactionDetailView | Title | `AppTypography.displayMedium()` |
| TransactionDetailView | Amount | `AppTypography.financialLarge()` |
| TransactionRowView | Title | `AppTypography.headingMedium()` |
| TransactionRowView | Amount | `AppTypography.financialDefault()` |
| TransactionRowView | Date | `AppTypography.bodySmall()` |
| AddTransactionView | Title | `AppTypography.displayMedium()` |
| AddTransactionView | Field label | `AppTypography.labelLarge()` |

### Auth & Onboarding

| Component | Element | Token |
|-----------|---------|-------|
| LockScreenView | Title | `AppTypography.displayLarge()` |
| LockScreenView | PIN digits | `AppTypography.financialHero()` |
| PhoneLoginView | Title | `AppTypography.displayLarge()` |
| PhoneLoginView | Description | `AppTypography.bodyLarge()` |
| OnboardingView | Title | `AppTypography.displayLarge()` |
| OnboardingView | Description | `AppTypography.bodyLarge()` |

### Search Feature

| Component | Element | Token |
|-----------|---------|-------|
| SearchView | Screen title | `AppTypography.displayLarge()` |
| SearchView | Result name | `AppTypography.headingMedium()` |
| SearchView | Result detail | `AppTypography.bodySmall()` |
| SearchView | Amount | `AppTypography.financialDefault()` |

### Quick Action Feature

| Component | Element | Token |
|-----------|---------|-------|
| QuickActionSheet | Title | `AppTypography.displayMedium()` |
| Step views | Field label | `AppTypography.labelLarge()` |
| Step views | Amount input | `AppTypography.financialLarge()` |
| Step views | Description | `AppTypography.bodyDefault()` |

---

## Rules & Enforcement

### Mandatory Rules

1. **All text must use `AppTypography` tokens.** No raw `.system(size:)` calls for text content.
2. **No `.fontDesign(.rounded)`** or `.design: .rounded` anywhere in the codebase.
3. **No `.fontWeight()` modifiers** that override `AppTypography` weights — pick the correct token instead.
4. **No hardcoded tracking values.** Use `AppTypography.Tracking.*` constants only.
5. **Minimum text size is 11pt** (Caption / Label Small).
6. **Financial amounts must use `financial.*` tokens** with monospaced digits.
7. **Icon fonts are excluded** — use `IconSize` enum for SF Symbol sizing.
8. **Dynamic avatar text sizing** (proportional to avatar size) is the only acceptable raw font usage.

### Allowed Exceptions

| Exception | Reason |
|-----------|--------|
| `ConversationAvatarView` initials | Size is proportional to avatar: `size * 0.38` |
| SF Symbol icon sizing | Uses `IconSize` enum, not text typography |
| `Text` concatenation with `.fontWeight(.bold)` | For inline emphasis within mixed-weight text |

### Style Modifier Usage

For tokens with non-zero tracking, always use the convenience style modifiers:

```swift
// Display tokens — use style modifiers
Text("Title").displayHeroStyle()    // includes font + tracking
Text("Title").displayLargeStyle()   // includes font + tracking
Text("Title").displayMediumStyle()  // includes font + tracking

// Financial tokens — use style modifiers
Text("$1,234").financialHeroStyle()  // includes font + tracking
Text("$1,234").financialLargeStyle() // includes font + tracking

// Small text tokens — use style modifiers
Text("LABEL").labelSmallStyle()      // includes font + tracking
Text("12:30 PM").captionStyle()      // includes font + tracking

// All other tokens — just .font() is sufficient (tracking = 0)
Text("Hello").font(AppTypography.bodyDefault())
Text("Name").font(AppTypography.headingMedium())
```

---

*This document is the single source of truth for typography in Swiss Coin. All components and pages must conform to these standards.*
