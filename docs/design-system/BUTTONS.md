# Swiss Coin Button Standard

> Comprehensive button guidelines for consistent, professional interactive elements across the entire application.

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Decision Tree — "Which Button Should I Use?"](#decision-tree--which-button-should-i-use)
3. [Button Style Summary Table](#button-style-summary-table)
4. [Button Styles (Detailed)](#button-styles-detailed)
5. [Reusable Button Components](#reusable-button-components)
6. [Design Token Reference](#design-token-reference)
7. [Haptic Feedback Pairing](#haptic-feedback-pairing)
8. [Animation Reference](#animation-reference)
9. [Disabled & Loading States](#disabled--loading-states)
10. [Accessibility Requirements](#accessibility-requirements)
11. [Button Patterns by Use Case](#button-patterns-by-use-case)
12. [DO's and DON'Ts](#dos-and-donts)
13. [File Reference Map](#file-reference-map)

---

## Design Principles

1. **Consistency**: Every button must use a design-system `ButtonStyle` or a reusable component. No ad-hoc button styling.
2. **Hierarchy**: Primary > Secondary > Ghost > Destructive. One primary per screen. Use secondary alongside primary, ghost for tertiary actions.
3. **Touch Targets**: Minimum 44pt height on all interactive buttons (Apple HIG). Primary CTAs use `ButtonHeight.lg` (50pt).
4. **Feedback**: Every interactive button gets haptic feedback via `HapticManager`. Match haptic intensity to action importance.
5. **Accessibility**: Icon-only buttons must have `.accessibilityLabel()`. Custom button-like views must add `.accessibilityAddTraits(.isButton)`.

---

## Decision Tree — "Which Button Should I Use?"

```
Is it a full-width CTA at the bottom of a form/sheet?
  ├─ Yes, positive/confirm action ──────── PrimaryButtonStyle
  ├─ Yes, dangerous/destructive action ─── DestructiveButtonStyle
  └─ No
      │
Is it a secondary action alongside a primary button?
  ├─ Yes ──────────────────────────────── SecondaryButtonStyle
  └─ No
      │
Is it a text-only/ghost action (cancel, skip, dismiss)?
  ├─ Yes ──────────────────────────────── GhostButtonStyle
  └─ No
      │
Is it in a toolbar/navigation bar?
  ├─ Yes, text button (Done/Cancel) ───── Plain Button (system default)
  ├─ Yes, icon button ─────────────────── Plain Button + .accessibilityLabel()
  └─ No
      │
Is it in a conversation action bar?
  ├─ Yes ──────────────────────────────── ActionBarButton component
  └─ No
      │
Is it a floating add button?
  ├─ Yes ──────────────────────────────── FloatingActionButton component
  └─ No
      │
Is it a segmented toggle / tab picker?
  ├─ Yes, simple segment ──────────────── CustomSegmentedControl component
  ├─ Yes, icon+text header button ──────── ActionHeaderButton component
  └─ No
      │
Is it a profile avatar in a header?
  ├─ Yes ──────────────────────────────── ProfileButton component
  └─ No
      │
Is it a list row that navigates?
  ├─ Yes ──────────────────────────────── NavigationLink + .buttonStyle(.plain)
  └─ No
      │
Is it inside a context menu?
  ├─ Yes ──────────────────────────────── Standard Button inside .contextMenu
  └─ No
      │
Is it an alert/confirmation button?
  ├─ Yes ──────────────────────────────── Button(role: .cancel/.destructive)
  └─ No
      │
Fallback: use AppButtonStyle with appropriate haptic
```

---

## Button Style Summary Table

| Style | Background | Text Color | Width | Height | Radius | Press Scale | Press Opacity | Animation | Built-in Haptic |
|-------|-----------|------------|-------|--------|--------|-------------|---------------|-----------|-----------------|
| `PrimaryButtonStyle` | `buttonBackground` | `buttonForeground` (white) | Full-width | 50pt | 12pt | 0.98 | 0.9 | `AppAnimation.fast` | None (caller adds) |
| `SecondaryButtonStyle` | Clear + accent border | `accent` | Full-width | 50pt | 12pt | 0.98 | 0.9 | `AppAnimation.fast` | None (caller adds) |
| `GhostButtonStyle` | None | `textSecondary` | Intrinsic | Intrinsic | — | 0.98 | 0.7 | `AppAnimation.fast` | None (caller adds) |
| `DestructiveButtonStyle` | `negative` | `onAccent` (white) | Full-width | 50pt | 12pt | 0.98 | 0.9 | `AppAnimation.fast` | None (caller adds) |
| `AppButtonStyle` | None (label only) | Inherit | Inherit | Inherit | — | 0.98 | 0.9 | `AppAnimation.fast` | None (caller adds) |

---

## Button Styles (Detailed)

### AppButtonStyle

**Location:** `Swiss Coin/Utilities/DesignSystem.swift:1202`

Generic animation-only button style. Applies scale and opacity effects without setting background, foreground, or frame. Use when you need consistent press animation on a custom-styled button.

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `haptic` | `HapticStyle` | `.medium` | Haptic enum: `.light`, `.medium`, `.heavy`, `.selection`, `.none` |

> **Note:** The `haptic` parameter is defined but not fired automatically in `makeBody`. Haptic feedback should be triggered by the caller or via `.withHaptic()` modifier.

**Visual Spec:**
- Background: None (inherits from label)
- Foreground: None (inherits from label)
- Scale on press: 0.98
- Opacity on press: 0.9
- Animation: `AppAnimation.fast` (0.15s easeOut)

**When to use:** Wrapping custom-designed buttons that need consistent press animation.

**Example:**
```swift
Button(action: { /* action */ }) {
    Text("Custom Button")
}
.buttonStyle(AppButtonStyle(haptic: .light))
```

---

### PrimaryButtonStyle

**Location:** `Swiss Coin/Utilities/DesignSystem.swift:1226`

Full-width accent-filled button for primary CTAs. One per screen maximum.

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `isEnabled` | `Bool` | `true` | Controls enabled/disabled appearance |

**Visual Spec:**
- Font: `AppTypography.buttonDefault()` (15pt Semibold)
- Foreground: enabled → `AppColors.buttonForeground` (white) / disabled → `AppColors.textSecondary`
- Frame: `maxWidth: .infinity`, height: `ButtonHeight.lg` (50pt)
- Background: `RoundedRectangle(cornerRadius: CornerRadius.button)` (12pt)
  - Enabled: `AppColors.buttonBackground` (accent orange)
  - Disabled: `AppColors.disabled` (secondaryLabel@38%)
- Scale on press: 0.98
- Opacity on press: 0.9
- Animation: `AppAnimation.fast` (0.15s easeOut)

**When to use:** Main call-to-action — Save, Add, Continue, Submit, Confirm.

**Example:**
```swift
Button("Save Transaction") {
    HapticManager.primaryAction()
    viewModel.save()
}
.buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.isValid))
.disabled(!viewModel.isValid)
.padding(.horizontal, Spacing.lg)
```

---

### SecondaryButtonStyle

**Location:** `Swiss Coin/Utilities/DesignSystem.swift:1250`

Full-width outlined button for secondary actions alongside a primary button.

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `isEnabled` | `Bool` | `true` | Controls enabled/disabled appearance |

**Visual Spec:**
- Font: `AppTypography.buttonDefault()` (15pt Semibold)
- Foreground: enabled → `AppColors.accent` / disabled → `AppColors.disabled`
- Frame: `maxWidth: .infinity`, height: `ButtonHeight.lg` (50pt)
- Background: Clear fill with `strokeBorder` (1pt)
  - Enabled: `AppColors.accent` border
  - Disabled: `AppColors.disabled` border
- Scale on press: 0.98
- Opacity on press: 0.9
- Animation: `AppAnimation.fast` (0.15s easeOut)

**When to use:** Secondary action paired with a primary — Cancel alongside Save, Skip alongside Continue.

**Example:**
```swift
VStack(spacing: Spacing.md) {
    Button("Add Expense") {
        HapticManager.primaryAction()
        onAdd()
    }
    .buttonStyle(PrimaryButtonStyle())

    Button("Cancel") {
        HapticManager.cancel()
        dismiss()
    }
    .buttonStyle(SecondaryButtonStyle())
}
```

---

### GhostButtonStyle

**Location:** `Swiss Coin/Utilities/DesignSystem.swift:1278`

Text-only button with no background. For tertiary actions and text links.

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `isEnabled` | `Bool` | `true` | Controls enabled/disabled appearance |

**Visual Spec:**
- Font: `AppTypography.buttonDefault()` (15pt Semibold)
- Foreground: enabled → `AppColors.textSecondary` / disabled → `AppColors.disabled`
- Frame: Intrinsic (no forced width/height)
- Background: None
- Scale on press: 0.98
- **Opacity on press: 0.7** (more dramatic than other styles)
- Animation: `AppAnimation.fast` (0.15s easeOut)

**When to use:** Skip, Dismiss, "Forgot password?", low-emphasis text links.

**Example:**
```swift
Button("Skip for now") {
    HapticManager.lightTap()
    dismiss()
}
.buttonStyle(GhostButtonStyle())
```

---

### DestructiveButtonStyle

**Location:** `Swiss Coin/Utilities/DesignSystem.swift:1296`

Full-width red-filled button for dangerous/irreversible actions.

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `isEnabled` | `Bool` | `true` | Controls enabled/disabled appearance |

**Visual Spec:**
- Font: `AppTypography.buttonDefault()` (15pt Semibold)
- Foreground: enabled → `AppColors.onAccent` (white) / disabled → `AppColors.textSecondary`
- Frame: `maxWidth: .infinity`, height: `ButtonHeight.lg` (50pt)
- Background: `RoundedRectangle(cornerRadius: CornerRadius.button)` (12pt)
  - Enabled: `AppColors.negative` (red)
  - Disabled: `AppColors.disabled`
- Scale on press: 0.98
- Opacity on press: 0.9
- Animation: `AppAnimation.fast` (0.15s easeOut)

**When to use:** Delete, Remove, Leave Group — always behind a confirmation dialog.

**Example:**
```swift
Button("Delete Transaction") {
    HapticManager.destructiveAction()
    viewModel.delete()
}
.buttonStyle(DestructiveButtonStyle())
```

---

## Reusable Button Components

### ActionBarButton

**Location:** `Swiss Coin/Components/ActionBarButton.swift`

Professional action button for conversation action bars. Handles haptics internally.

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `title` | `String` | — | Button label text |
| `icon` | `String` | — | SF Symbol name |
| `isPrimary` | `Bool` | `false` | Primary (accent fill) or secondary (tertiary bg) |
| `isEnabled` | `Bool` | `true` | Interactive state |
| `action` | `() -> Void` | — | Tap handler |

**Visual Spec:**
- Height: 44pt
- Corner radius: `CornerRadius.md` (12pt)
- Icon: `IconSize.sm` (16pt), weight `.semibold`
- Font: `AppTypography.buttonDefault()` (15pt Semibold)
- Spacing: `Spacing.sm` (8pt) between icon and text
- Primary: `buttonBackground` fill, `buttonForeground` text
- Secondary: `backgroundTertiary` fill, `textPrimary`/`textSecondary` text
- Disabled opacity: 0.6
- Press style: `ActionBarPressStyle` — scale 0.96, opacity 0.85, spring(0.2, 0.7)

**Built-in Haptics** (do NOT add additional haptics when using this component):
- Primary: `HapticManager.primaryAction()` (rigid, intensity 0.8)
- Non-primary: `HapticManager.actionBarTap()` (medium, intensity 0.7)

**Pre-built Containers:**

`StandardActionBar` — Three-button bar for person/group conversations:
```swift
StandardActionBar(
    balance: person.balance,
    canRemind: balance < 0,
    onAdd: { showAddSheet = true },
    onSettle: { showSettleSheet = true },
    onRemind: { showReminderSheet = true }
)
```

`SubscriptionActionBarView` — Three-button bar for subscription conversations:
```swift
SubscriptionActionBarView(
    balance: subscription.balance,
    membersWhoOwe: viewModel.membersWhoOwe,
    onRecordPayment: { showPaySheet = true },
    onSettle: { showSettleSheet = true },
    onRemind: { showReminderSheet = true }
)
```

`ActionBarContainer` — Generic container for custom action bar layouts:
```swift
ActionBarContainer {
    ActionBarButton(title: "Add", icon: "plus", isPrimary: true, action: onAdd)
    ActionBarButton(title: "Remind", icon: "bell.fill", isEnabled: canRemind, action: onRemind)
}
```

> **Note:** `ActionBarContainer` calls `HapticManager.prepare()` on appear automatically.

---

### ActionHeaderButton

**Location:** `Swiss Coin/Components/ActionHeaderButton.swift`

Segmented-style header button for navigation between sections (e.g., Personal/Shared tabs).

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `title` | `String` | — | Button label |
| `icon` | `String` | — | SF Symbol name |
| `color` | `Color` | — | `AppColors.accent` for selected, `AppColors.textSecondary` for unselected |
| `action` | `() -> Void` | — | Tap handler |

**Visual Spec:**
- Icon: `IconSize.sm` (16pt), weight `.medium`
- Font: `AppTypography.buttonDefault()` (15pt Semibold)
- Padding: horizontal `Spacing.lg` (16pt), vertical `Spacing.md` (12pt)
- Selected (`color == accent`): `buttonBackground` fill, `buttonForeground` text
- Unselected: `backgroundTertiary.opacity(0.6)` fill, `color` text
- Corner radius: `CornerRadius.md` (12pt)
- Press: scale 0.96, `AppAnimation.buttonPress` (0.15s easeOut)
- Style: `PlainButtonStyle` (overrides system press appearance)

**Built-in Accessibility:**
- `.accessibilityLabel(title)`
- `.accessibilityAddTraits(.isButton)`

**No built-in haptics** — add your own if needed.

**Example:**
```swift
HStack(spacing: Spacing.sm) {
    ActionHeaderButton(
        title: "Personal",
        icon: "person.fill",
        color: isPersonal ? AppColors.accent : AppColors.textSecondary,
        action: { isPersonal = true }
    )
    ActionHeaderButton(
        title: "Shared",
        icon: "person.2.fill",
        color: !isPersonal ? AppColors.accent : AppColors.textSecondary,
        action: { isPersonal = false }
    )
}
```

---

### FloatingActionButton

**Location:** `Swiss Coin/Components/FloatingActionButton.swift`

Circular floating action button for adding transactions. Positioned bottom-right.

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `action` | `() -> Void` | — | Tap handler |

**Visual Spec:**
- Size: 56x56pt circular
- Icon: "plus", 24pt semibold, white
- Background: `LinearGradient` from `accent` to `accent.opacity(0.85)`
- Shadow: `accent.opacity(0.3)`, radius 8, y-offset 4
- Style: `.plain`

**Built-in Haptics:** `HapticManager.tap()` (medium impact)

**Built-in Accessibility:** `.accessibilityLabel("Add transaction")`

**Example:**
```swift
ZStack(alignment: .bottomTrailing) {
    // Main content...

    FloatingActionButton {
        showAddTransaction = true
    }
    .padding(.trailing, Spacing.lg)
    .padding(.bottom, Spacing.xl)
}
```

---

### ProfileButton

**Location:** `Swiss Coin/Features/Home/Components/ProfileButton.swift`

Circular profile avatar button for the home screen header.

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `action` | `() -> Void` | — | Tap handler |

**Visual Spec:**
- Size: `AvatarSize.xs` (32pt) circle
- Background: `buttonBackground` (accent) circle
- Icon: `person.circle.fill`, size 30pt (AvatarSize.xs - 2)
- Style: `ProfileButtonStyle` — scale 0.92, `AppAnimation.quick` (0.15s easeOut)

**Built-in Haptics:** `HapticManager.lightTap()` (light impact)

**Built-in Accessibility:** `.accessibilityLabel("Profile")`

**Example:**
```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        ProfileButton {
            showProfile = true
        }
    }
}
```

---

### CustomSegmentedControl

**Location:** `Swiss Coin/Views/Components/CustomSegmentedControl.swift`

Design-system segmented control with matched geometry animation. Replaces SwiftUI's native `Picker(.segmented)`.

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `selection` | `Binding<Int>` | — | Selected index |
| `options` | `[String]` | — | Tab labels |

**Visual Spec:**
- Selected tab: `buttonBackground` fill, `buttonForeground` text, shadow
- Unselected tab: `backgroundSecondary`, `textSecondary` text
- Inner radius: `CornerRadius.sm` (8pt, legacy)
- Outer radius: `CornerRadius.md` (12pt, legacy)
- Font: `AppTypography.labelLarge()` (15pt Medium)
- Outer padding: `Spacing.xxs` (2pt)
- Animation: `AppAnimation.spring` (0.3, 0.7) with `matchedGeometryEffect`

**Built-in Haptics:** `HapticManager.selectionChanged()` (selection feedback)

**Built-in Accessibility:**
- `.accessibilityLabel("[option], tab N of M")`
- `.accessibilityAddTraits(.isSelected)` on active tab
- `.accessibilityElement(children: .contain)` on container
- `.accessibilityLabel("Segment picker")` on container

**Example:**
```swift
CustomSegmentedControl(
    selection: $selectedTab,
    options: ["People", "Groups"]
)
.padding(.horizontal, Spacing.lg)
```

---

## Design Token Reference

### Button Heights

| Token | Value | Use |
|-------|-------|-----|
| `ButtonHeight.sm` | 36pt | Compact buttons, tags |
| `ButtonHeight.md` | 44pt | Standard buttons (minimum touch target) |
| `ButtonHeight.input` | 48pt | Input field height |
| `ButtonHeight.lg` | 50pt | Primary action buttons (PrimaryButtonStyle, etc.) |
| `ButtonHeight.xl` | 56pt | Hero buttons, FAB |

### Corner Radii

| Token | Value | Use |
|-------|-------|-----|
| `CornerRadius.small` | 6pt | Tags, badges |
| `CornerRadius.medium` | 10pt | Input fields, small containers |
| `CornerRadius.button` | 12pt | All standard button styles |
| `CornerRadius.full` | 9999pt | Pill shapes, circular elements |

### Button Typography

| Token | Size | Weight | Use |
|-------|------|--------|-----|
| `AppTypography.buttonLarge()` | 17pt | Semibold | Primary full-width buttons |
| `AppTypography.buttonDefault()` | 15pt | Semibold | Standard buttons (used by all styles) |
| `AppTypography.buttonSmall()` | 13pt | Semibold | Compact buttons, text links |

### Button Colors

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `buttonBackground` | `#F35B16` | `#F36D30` | Primary button fill |
| `buttonForeground` | white | white | Primary button text |
| `accent` | `#F35B16` | `#F36D30` | Secondary button text/border |
| `accentPressed` | `#D94E12` | `#E05A1A` | Press state (manual use) |
| `negative` | `#D93025` | `#F87171` | Destructive button fill |
| `onAccent` | white | white | Text on accent/destructive surfaces |
| `disabled` | secondaryLabel@38% | secondaryLabel@38% | Disabled button fill |
| `textSecondary` | `#6B6560` | `#A8A29E` | Ghost button text, disabled text |
| `textPrimary` | `#22201D` | `#F5F5F3` | ActionBarButton secondary text |
| `backgroundTertiary` | `#EFEDEB` | `#3A3A3C` | ActionBarButton secondary fill |

### Icon Sizes for Buttons

| Token | Value | Use |
|-------|-------|-----|
| `IconSize.sm` | 16pt | Button icons (ActionBarButton, ActionHeaderButton) |
| `IconSize.md` | 20pt | Header/toolbar icons |
| `IconSize.lg` | 24pt | FAB icon, large button icons |
| `IconSize.xl` | 32pt | Send button, hero actions |

### Spacing in Buttons

| Token | Value | Use |
|-------|-------|-----|
| `Spacing.sm` | 8pt | Icon-to-text gap inside buttons |
| `Spacing.md` | 12pt | Vertical padding in header buttons |
| `Spacing.lg` | 16pt | Horizontal padding, screen-edge insets |

---

## Haptic Feedback Pairing

Every interactive button should trigger haptic feedback. Match the haptic to the action's importance.

### Standard Pairings

| Button Context | HapticManager Method | Generator | Intensity | Notes |
|---------------|---------------------|-----------|-----------|-------|
| Primary CTA (Save, Add, Continue) | `.primaryAction()` | Rigid | 0.8 | Firm, deliberate |
| Destructive action (Delete, Remove) | `.destructiveAction()` | Warning + Rigid | 1.0 + 0.5 | Double-tap pattern (0.1s gap) |
| Secondary button (Cancel) | `.cancel()` | Light | 1.0 | Quick, light |
| Ghost/text button (Skip, Dismiss) | `.lightTap()` | Light | 1.0 | Subtle |
| Save/confirm | `.save()` | Light | 1.0 | Quick confirmation |
| Action bar (non-primary) | `.actionBarTap()` | Medium | 0.7 | Professional tap |
| FAB tap | `.tap()` | Medium | 1.0 | Standard tap |
| Profile button | `.lightTap()` | Light | 1.0 | Subtle navigation |
| Segmented control | `.selectionChanged()` | Selection | — | System selection |
| Toggle switch | `.toggle()` | Selection | — | System selection |
| Navigation push/pop | `.navigationTap()` | Light | 0.4 | Subtle directional |
| Context menu peek | `.contextMenuPeek()` | Medium | 0.8 | Long-press recognition |
| Send message | `.messageSent()` | Rigid | 0.6 | Crisp iMessage-like |
| Copy to clipboard | `.copyAction()` | Light | 0.5 | Quick confirmation |
| Undo action | `.undoAction()` | Notification Success | — | Satisfying relief |
| Sheet present | `.sheetPresent()` | Soft | 0.5 | Modal slide-in |
| Sheet dismiss | `.sheetDismiss()` | Light | 0.3 | Lighter counterpart |
| Error/alert | `.errorAlert()` | Notification Error | — | Firm error |
| Delete confirm | `.delete()` | Notification Warning | — | Warning before action |

### CoreHaptics Patterns (Advanced)

| Pattern | Method | Events | Fallback |
|---------|--------|--------|----------|
| Settlement complete | `.settlementComplete()` | Transient 0.7 @ 0s → Transient 1.0 @ 0.12s | `.success()` |
| Reminder sent | `.reminderSent()` | Triple transient 0.6 @ 0s/0.08s/0.16s | `.warning()` |
| Transaction added | `.transactionAdded()` | Transient 0.5 (soft) @ 0s → Transient 0.9 (sharp) @ 0.15s | `.success()` |

### Preparation

Call `HapticManager.prepare()` on view appear to pre-warm generators:

```swift
.onAppear {
    HapticManager.prepare()
}
```

> **Note:** `ActionBarContainer` calls `HapticManager.prepare()` automatically.

---

## Animation Reference

### Animation Presets

| Preset | Duration | Curve | Use |
|--------|----------|-------|-----|
| `AppAnimation.fast` / `.buttonPress` | 0.15s | easeOut | Standard button press (all 5 styles) |
| `AppAnimation.spring` | 0.3, 0.7 | Spring | Segmented control selection |
| `ActionBarPressStyle` spring | 0.2, 0.7 | Spring | Action bar button press |
| `AppAnimation.quick` (legacy) | 0.15s | easeOut | ProfileButton press (same as `.fast`) |

### Press Effect Values by Style

| Style | Scale | Opacity | Animation |
|-------|-------|---------|-----------|
| `PrimaryButtonStyle` | 0.98 | 0.9 | `AppAnimation.fast` |
| `SecondaryButtonStyle` | 0.98 | 0.9 | `AppAnimation.fast` |
| `GhostButtonStyle` | 0.98 | **0.7** | `AppAnimation.fast` |
| `DestructiveButtonStyle` | 0.98 | 0.9 | `AppAnimation.fast` |
| `AppButtonStyle` | 0.98 | 0.9 | `AppAnimation.fast` |
| `ActionBarPressStyle` | **0.96** | **0.85** | spring(0.2, 0.7) |
| `ProfileButtonStyle` | **0.92** | 1.0 | `AppAnimation.quick` |

---

## Disabled & Loading States

### Pattern A: Style-Managed Disabled (Recommended)

Use the style's built-in `isEnabled` parameter alongside `.disabled()`:

```swift
Button("Save") {
    HapticManager.primaryAction()
    viewModel.save()
}
.buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.isValid))
.disabled(!viewModel.isValid)
```

Both `isEnabled: false` (visual change) AND `.disabled()` (interaction block) are required. The style handles visual appearance; `.disabled()` prevents tap events.

### Pattern B: Opacity-Based Disabled (Action Bar)

For `ActionBarButton`, disabled state is managed via opacity:

```swift
ActionBarButton(
    title: "Settle",
    icon: "checkmark",
    isPrimary: false,
    isEnabled: canSettle,  // Controls opacity (0.6 when false)
    action: onSettle
)
```

The component handles `.disabled()` and opacity internally.

### Pattern C: Toolbar Disabled

For toolbar buttons without a custom style:

```swift
Button(action: save) {
    Text("Done")
        .font(AppTypography.buttonDefault())
        .foregroundColor(isValid ? AppColors.accent : AppColors.textDisabled)
}
.disabled(!isValid)
```

### Loading State Pattern

Swap button content with a `ProgressView` while maintaining frame:

```swift
Button(action: submit) {
    if isLoading {
        ProgressView()
            .tint(AppColors.buttonForeground)
    } else {
        Text("Submit")
    }
}
.buttonStyle(PrimaryButtonStyle(isEnabled: !isLoading))
.disabled(isLoading)
```

---

## Accessibility Requirements

### Mandatory Rules

1. **Icon-only buttons must have `.accessibilityLabel()`:**
```swift
Button(action: close) {
    Image(systemName: "xmark")
        .font(.system(size: IconSize.md))
}
.accessibilityLabel("Close")
```

2. **Contextual buttons should have `.accessibilityHint()`:**
```swift
Button("Settle Up") { ... }
    .accessibilityHint("Records that the balance has been paid")
```

3. **Custom button-like views must add `.accessibilityAddTraits(.isButton)`:**
```swift
customTappableView
    .onTapGesture { action() }
    .accessibilityAddTraits(.isButton)
```

4. **Decorative icons inside buttons use `.accessibilityHidden(true)`:**
```swift
Button(action: add) {
    HStack {
        Image(systemName: "plus")
            .accessibilityHidden(true)
        Text("Add Expense")
    }
}
```

5. **Minimum 44pt touch target** — use `.frame(minHeight: 44)` or `.contentShape(Rectangle())` to expand hit areas:
```swift
Button(action: tap) {
    Text("Small text")
        .font(AppTypography.bodySmall())
}
.frame(minHeight: 44)
.contentShape(Rectangle())
```

6. **Compound buttons use `.accessibilityElement(children: .combine)`:**
```swift
Button(action: navigate) {
    HStack {
        Image(systemName: "person.fill")
        VStack(alignment: .leading) {
            Text("John")
            Text("$50.00")
        }
    }
}
.accessibilityElement(children: .combine)
```

---

## Button Patterns by Use Case

### 1. Primary CTA (Full-Width Bottom of Form)

```swift
Button("Add Expense") {
    HapticManager.primaryAction()
    viewModel.save()
}
.buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.isValid))
.disabled(!viewModel.isValid)
.padding(.horizontal, Spacing.lg)
```

### 2. Toolbar Text Button (Done/Cancel)

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button("Done") {
            HapticManager.save()
            dismiss()
        }
        .font(AppTypography.buttonDefault())
        .foregroundColor(AppColors.accent)
    }
    ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") {
            HapticManager.cancel()
            dismiss()
        }
        .font(AppTypography.buttonDefault())
        .foregroundColor(AppColors.textSecondary)
    }
}
```

### 3. Toolbar Icon Button

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button(action: {
            HapticManager.lightTap()
            showSettings = true
        }) {
            Image(systemName: "gearshape")
                .font(.system(size: IconSize.md))
                .foregroundColor(AppColors.textPrimary)
        }
        .accessibilityLabel("Settings")
    }
}
```

### 4. NavigationLink as List Row

```swift
NavigationLink(destination: PersonDetailView(person: person)) {
    HStack {
        AvatarView(person: person)
        VStack(alignment: .leading) {
            Text(person.name)
                .font(AppTypography.headingMedium())
            Text("Last active 2h ago")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
        }
    }
}
.buttonStyle(.plain)
```

### 5. Action Bar Buttons

```swift
StandardActionBar(
    balance: viewModel.balance,
    canRemind: viewModel.canRemind,
    onAdd: { showAddSheet = true },
    onSettle: { showSettleSheet = true },
    onRemind: { showReminderSheet = true }
)
```

### 6. Context Menu Items

```swift
.contextMenu {
    Button(action: {
        HapticManager.copyAction()
        UIPasteboard.general.string = amount
    }) {
        Label("Copy Amount", systemImage: "doc.on.doc")
    }

    Button(role: .destructive, action: {
        HapticManager.destructiveAction()
        viewModel.delete()
    }) {
        Label("Delete", systemImage: "trash")
    }
}
```

### 7. Alert/Confirmation Buttons

```swift
.alert("Delete Transaction?", isPresented: $showDeleteAlert) {
    Button("Cancel", role: .cancel) {
        HapticManager.cancel()
    }
    Button("Delete", role: .destructive) {
        HapticManager.destructiveAction()
        viewModel.delete()
    }
} message: {
    Text("This action cannot be undone.")
}
```

### 8. Swipe Actions

```swift
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) {
        HapticManager.destructiveAction()
        viewModel.delete(transaction)
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
```

### 9. Floating Action Button

```swift
ZStack(alignment: .bottomTrailing) {
    ScrollView {
        // Content...
    }

    FloatingActionButton {
        showAddTransaction = true
    }
    .padding(.trailing, Spacing.lg)
    .padding(.bottom, Spacing.xl)
}
```

### 10. Segmented Control

```swift
CustomSegmentedControl(
    selection: $selectedTab,
    options: ["People", "Groups"]
)
.padding(.horizontal, Spacing.lg)
```

---

## DO's and DON'Ts

### DO

1. **DO** use `PrimaryButtonStyle`, `SecondaryButtonStyle`, `GhostButtonStyle`, or `DestructiveButtonStyle` for all standard buttons.
2. **DO** use design tokens: `ButtonHeight.*`, `CornerRadius.button`, `AppColors.buttonBackground`.
3. **DO** call `HapticManager.prepare()` in `.onAppear` on screens with interactive buttons.
4. **DO** add `.accessibilityLabel()` on every icon-only button.
5. **DO** use `.contentShape(Rectangle())` to expand tappable area on sparse layouts.
6. **DO** pair `isEnabled:` parameter with `.disabled()` modifier — both are required.
7. **DO** use `AppTypography.buttonDefault()` (or `buttonLarge()`/`buttonSmall()`) for button text.
8. **DO** use `ActionBarButton` for conversation action bars — it handles haptics internally.
9. **DO** use `FloatingActionButton` for the floating add button — it handles haptics internally.
10. **DO** use `CustomSegmentedControl` instead of SwiftUI's native `Picker(.segmented)`.

### DON'T

1. **DON'T** hardcode button colors — use `AppColors.buttonBackground`, `AppColors.accent`, etc.
2. **DON'T** hardcode button heights — use `ButtonHeight.*` tokens.
3. **DON'T** hardcode corner radii — use `CornerRadius.button` (12pt).
4. **DON'T** hardcode font sizes for button text — use `AppTypography.button*()` tokens.
5. **DON'T** double-fire haptics on components that handle them internally (`ActionBarButton`, `FloatingActionButton`, `ProfileButton`, `CustomSegmentedControl`).
6. **DON'T** skip `.disabled()` when using `isEnabled: false` — the style only changes appearance, `.disabled()` blocks interaction.
7. **DON'T** use `.fontWeight()` to override button typography — pick the correct `AppTypography.button*()` token.
8. **DON'T** use SwiftUI system colors (`.red`, `.blue`) for button styling — use semantic tokens.
9. **DON'T** create ad-hoc button styles — if you need a new pattern, add it to `DesignSystem.swift`.
10. **DON'T** use `.fontDesign(.rounded)` on buttons — all fonts use `.default` design.

---

## File Reference Map

| File | Contents |
|------|----------|
| `Swiss Coin/Utilities/DesignSystem.swift` | `AppButtonStyle`, `PrimaryButtonStyle`, `SecondaryButtonStyle`, `GhostButtonStyle`, `DestructiveButtonStyle`, all design tokens (`Spacing`, `CornerRadius`, `ButtonHeight`, `IconSize`, `AppColors`, `AppTypography`, `AppAnimation`), `.withHaptic()` modifier |
| `Swiss Coin/Utilities/HapticManager.swift` | All `HapticManager.*` methods (impact, selection, notification, semantic, conversation, CoreHaptics patterns) |
| `Swiss Coin/Components/ActionBarButton.swift` | `ActionBarButton`, `ActionBarContainer`, `StandardActionBar`, `SubscriptionActionBarView`, `ActionBarPressStyle` |
| `Swiss Coin/Components/ActionHeaderButton.swift` | `ActionHeaderButton` component |
| `Swiss Coin/Components/FloatingActionButton.swift` | `FloatingActionButton` component |
| `Swiss Coin/Features/Home/Components/ProfileButton.swift` | `ProfileButton`, `ProfileButtonStyle` |
| `Swiss Coin/Views/Components/CustomSegmentedControl.swift` | `CustomSegmentedControl` component |

---

*This document is the single source of truth for buttons in Swiss Coin. All interactive elements must conform to these standards.*
