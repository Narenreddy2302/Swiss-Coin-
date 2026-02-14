# Complete Redesign Plan: New Transaction Page (AddTransactionView)

## Reference Image Analysis

The target design transforms the transaction page from a dense, form-heavy layout into a **hero-amount-first, card-sectioned** layout with clear visual hierarchy, generous whitespace, and a premium finance-app feel. Key design characteristics:

- **Hero amount display** at the very top (large centered `$0.00`)
- **Currency selector** as a flag + code badge beside the amount
- **Transaction name** as a clean standalone input card
- **Category + Date** combined on a single compact row as pill/chips
- **Paid By** section with clean avatar-row card
- **Split With** section with horizontal chip flow + "Add People" CTA
- **Split Method** as horizontal scrollable pills
- **Breakdown** in a clean card with divider-separated rows + total footer
- **Note** section as an expandable tap-to-reveal field
- **Save button** as a full-width sticky bottom CTA

---

## Current State (AddTransactionView.swift — 1,349 lines)

The existing file is a single monolithic SwiftUI view with the following section order:
1. `transactionHeaderSection` — Category icon + title field combined
2. `amountAndDateSection` — Date + currency badge + amount input in one horizontal row
3. `paidBySection` — Payer selection with inline search
4. `splitWithSection` — Participant selection with inline search
5. `splitMethodSection` — Method pills (FlowLayout)
6. `paidByBreakdownSection` — Multi-payer amounts (conditional)
7. `breakdownSection` — Per-person split amounts
8. `noteSection` — Expandable note editor
9. `stickyBottomBar` — Validation message + Save button

### Issues with Current Design
- Amount field is buried in the date/currency row — not prominent enough
- Title and category are merged into one section — cluttered
- No hero visual element — lacks impact
- Sections run together without clear separation
- Category + date are in different sections instead of paired
- Dense vertical layout without breathing room

---

## Redesigned Layout (Top to Bottom)

### Section 0: Navigation Bar (unchanged structure)
- Title: "New Transaction" (`.inline` display mode)
- Left: X close button (existing)
- Right: Keyboard "Done" button (existing)
- Background: `AppColors.conversationBackground`

### Section 1: Hero Amount Display (NEW)
**Purpose:** Make the amount the most prominent element on the page.

**Layout:**
```
┌─────────────────────────────────────────────┐
│                                             │
│              $ 0.00                         │  ← financialHero (34pt bold mono)
│                                             │
│           [🇺🇸 USD ▾]                       │  ← Currency badge (tappable)
│                                             │
└─────────────────────────────────────────────┘
```

**Implementation Details:**
- `VStack(alignment: .center, spacing: Spacing.sm)`
- Amount text field: `AppTypography.financialHero()` centered, `AppColors.textPrimary`
- Use an invisible `TextField` overlaid behind a formatted `Text` display for clean large-number input, OR use a centered `TextField` with `.multilineTextAlignment(.center)`
- Currency badge: horizontal capsule with flag emoji + currency code + chevron.down
  - Background: `AppColors.backgroundTertiary`
  - Corner radius: `CornerRadius.full` (pill shape)
  - Tap opens existing `TransactionCurrencyPicker` sheet
- Card background: `AppColors.cardBackground` with standard card shadow
- Padding: `Spacing.xxl` vertical, `Spacing.cardPadding` horizontal

**Design Tokens:**
- Amount font: `AppTypography.financialHero()` (34pt bold monospaced)
- Amount color: `AppColors.textPrimary` (when has value), `AppColors.textTertiary` (placeholder)
- Currency badge font: `AppTypography.labelDefault()` (13pt medium)
- Currency badge background: `AppColors.backgroundTertiary`
- Currency badge border: `AppColors.border`, 1pt

### Section 2: Transaction Name Input (NEW — standalone)
**Purpose:** Clean, focused title entry separated from category.

**Layout:**
```
┌─────────────────────────────────────────────┐
│  📝  Transaction Name                       │
└─────────────────────────────────────────────┘
```

**Implementation Details:**
- Single-line `TextField` with "Transaction Name" placeholder
- Left icon: `pencil` or `square.and.pencil` SF Symbol in `AppColors.textTertiary`
- Card wrapper: `AppColors.cardBackground`, `CornerRadius.card`, standard shadow
- Padding: `Spacing.cardPadding`
- Focus state: border highlight with `AppColors.borderFocus` when active
- Max length: `ValidationLimits.maxTransactionTitleLength` (200)

**Design Tokens:**
- Placeholder font: `AppTypography.bodyLarge()` (17pt regular)
- Input font: `AppTypography.headingMedium()` (17pt semibold) when has text
- Icon size: `IconSize.sm` (16pt)
- Icon color: `AppColors.textTertiary`

### Section 3: Category & Date Row (NEW — combined)
**Purpose:** Pair category and date as secondary metadata on one row.

**Layout:**
```
┌──────────────────────────┐   ┌──────────────┐
│  🍽️ Food & Drinks  ▾    │   │  📅 Today    │
└──────────────────────────┘   └──────────────┘
```

**Implementation Details:**
- `HStack(spacing: Spacing.md)` with two tappable pills
- **Category pill (left):**
  - `HStack`: category emoji + category name + chevron.right
  - Background: category color at 0.1 opacity
  - Border: category color at 0.2 opacity, 1pt
  - Corner radius: `CornerRadius.full` (pill)
  - Tap opens existing `CategoryPickerSheet`
- **Date pill (right):**
  - `HStack`: calendar SF Symbol + formatted date text
  - Smart labels: "Today", "Yesterday", or "MMM d, yyyy"
  - Background: `AppColors.backgroundTertiary`
  - Border: `AppColors.border`, 1pt
  - Corner radius: `CornerRadius.full` (pill)
  - Tap opens existing date picker sheet
- Both pills have `.buttonStyle(.plain)` with scale animation

**Design Tokens:**
- Category pill text: `AppTypography.labelDefault()` (13pt medium)
- Category pill emoji: `IconSize.sm` (16pt) font
- Date pill text: `AppTypography.labelDefault()` (13pt medium)
- Date pill icon: `IconSize.xs` (12pt)
- Pill padding: horizontal `Spacing.md` (12pt), vertical `Spacing.sm` (8pt)

### Section 4: Paid By (REDESIGNED)
**Purpose:** Show who paid in a clean card format.

**Layout (default — single "You" payer):**
```
PAID BY

┌─────────────────────────────────────────────┐
│  [ME] You                    $100.00    ✓   │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  🔍 Search contacts...                     │
└─────────────────────────────────────────────┘
```

**Layout (multi-payer — chips):**
```
PAID BY

┌─────────────────────────────────────────────┐
│  [ME] You ×   [JD] John ×   [+ Add]        │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  🔍 Search contacts...                     │
└─────────────────────────────────────────────┘
```

**Implementation Details:**
- Keep existing logic from `paidBySection` but clean up visuals
- Default state: single row showing "You" avatar + name + amount + green checkmark
- Multi-payer state: `FlowLayout` with avatar chips + "+ Add" button
- Search field always visible at bottom of card (separated by divider)
- Floating search results dropdown (existing behavior preserved)
- Card wrapper: standard card background + shadow

**Changes from Current:**
- Cleaner spacing inside the card
- Avatar circles use consistent `AvatarSize.sm` (36pt)
- Search results panel: max height 220pt, elevated shadow (keep existing)
- Green checkmark for default payer uses `AppColors.positive`

### Section 5: Split With (REDESIGNED)
**Purpose:** Participant selection with horizontal chip flow.

**Layout:**
```
SPLIT WITH

┌─────────────────────────────────────────────┐
│  [ME] You 🔒   [JD] John ×   [+ Add People]│
│                                             │
│  2 people                                   │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│  🔍 Search contacts...                     │
└─────────────────────────────────────────────┘
```

**Implementation Details:**
- Keep existing `FlowLayout` chip system
- Current user chip: locked (lock icon, no X), outlined border
- Other participants: avatar chip with X to remove
- "+ Add People" button: accent-colored text with outline border (pill shape)
- Person count label: `"N people"` in caption style below chips
- Divider then search field at bottom
- Floating search results (groups + contacts) preserved
- Empty state: centered icon + "Select at least one person to split with"

**Changes from Current:**
- Rename "+ Add" to "+ Add People" for clarity
- Slightly increase chip padding for better touch targets
- Keep undo toast for removed participants

### Section 6: Split Method (REDESIGNED)
**Purpose:** Horizontal scrollable method selector.

**Layout:**
```
SPLIT METHOD

[ = Equal ]  [ $ Amount ]  [ % Percentage ]  [ ÷ Shares ]  [ ± Adjustments ]
  ^^^orange     ^^^outline     ^^^outline        ^^^outline     ^^^outline
```

**Implementation Details:**
- Change from `FlowLayout` to `ScrollView(.horizontal, showsIndicators: false)` + `HStack`
- Each pill: icon + label in a capsule
- Selected state: filled `AppColors.accent` background, white text
- Unselected state: clear background, `AppColors.border` outline, `AppColors.textPrimary` text
- Keep existing `methodPill()` function logic, just update layout container
- Spring animation on selection change

**Design Tokens:**
- Pill font: icon `AppTypography.labelLarge()`, text `AppTypography.labelSmall()`
- Pill padding: horizontal `Spacing.md`, vertical `Spacing.sm`
- Selected bg: `AppColors.accent`
- Selected text: `AppColors.onAccent`
- Unselected border: `AppColors.border`, 1pt

### Section 7: Paid By Breakdown (CONDITIONAL — unchanged logic)
**Purpose:** Show per-payer amounts when multiple payers exist.

- Only shown when `viewModel.selectedPayerPersons.count > 1`
- Keep existing `paidByBreakdownSection` layout
- Minor spacing cleanup to match new card style

### Section 8: Breakdown (REDESIGNED)
**Purpose:** Clean per-participant split display.

**Layout:**
```
BREAKDOWN

┌─────────────────────────────────────────────┐
│  [ME] You                        $ 50.00    │
│  ────────────────────────────────────────    │
│  [JD] John Doe                   $ 50.00    │
│  ════════════════════════════════════════    │
│  Total Balance                   $ 100.00   │
└─────────────────────────────────────────────┘
```

**Implementation Details:**
- Standard card background with shadow
- Each participant row: avatar (36pt) + name + spacer + amount
- Divider between rows (inset past avatar)
- Heavy divider before total row
- Total row: bold "Total Balance" label + formatted total amount
- Color coding: balanced = `AppColors.positive`, unbalanced = `AppColors.negative`
- For percentage/shares methods: show calculated amount as subtitle under name
- For amount method: editable `TextField` for each person's amount
- Keep `TwoPartySplitView` for 2-person equal splits
- Keep `SplitInputView` for percentage/shares/adjustment inputs
- Empty state: centered icon + "Select participants to see breakdown"

**Changes from Current:**
- Cleaner row spacing (increase vertical padding slightly)
- Avatar size: consistent `AvatarSize.sm` (36pt)
- Better visual distinction for the total row (heavier divider)
- Balance remaining text in `AppColors.negative` with caption style

### Section 9: Note (REDESIGNED)
**Purpose:** Optional expandable note field.

**Layout (collapsed):**
```
┌─────────────────────────────────────────────┐
│  📝 Add a note (optional)              ▸    │
└─────────────────────────────────────────────┘
```

**Layout (expanded):**
```
┌─────────────────────────────────────────────┐
│  [TextEditor area, min 80pt height]         │
│                                             │
│                                   42/1000   │
└─────────────────────────────────────────────┘
```

**Implementation Details:**
- Keep existing toggle logic (`showNoteField`)
- Collapsed: single-line button with icon + text + chevron
- Expanded: `TextEditor` with character counter
- Card wrapper with standard shadow
- Character limit: 1,000

### Section 10: Sticky Bottom Bar (REDESIGNED)
**Purpose:** Always-visible save action with validation feedback.

**Layout:**
```
┌─────────────────────────────────────────────┐
│  ⚠️ Please enter a transaction amount       │  ← Validation (conditional)
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │         Save Transaction            │    │  ← Primary CTA
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

**Implementation Details:**
- Validation message: warning icon + text in muted warning bg (existing)
- Save button: full-width, `ButtonHeight.lg` (50pt), `CornerRadius.xl` (20pt)
- Enabled: `AppColors.accent` background, white text
- Disabled: `AppColors.disabled` background, 0.6 opacity
- Loading state: `ProgressView` spinner
- Success state: checkmark icon
- Bottom safe area padding
- Frosted glass effect: card background with upward shadow

---

## File-Level Changes

### Primary File: `AddTransactionView.swift`
**Scope:** Complete rewrite of the view body and all section computed properties.

**Sections to Rewrite:**
1. `body` — New section ordering and spacing
2. `transactionHeaderSection` → REMOVE (split into hero amount + title + category/date)
3. NEW: `heroAmountSection` — Large centered amount + currency badge
4. NEW: `transactionNameSection` — Standalone title input card
5. NEW: `categoryAndDateRow` — Combined category pill + date pill
6. `amountAndDateSection` → REMOVE (merged into hero + category/date)
7. `paidBySection` → Redesign card layout (keep logic)
8. `splitWithSection` → Redesign card layout (keep logic)
9. `splitMethodSection` → Change to horizontal scroll
10. `paidByBreakdownSection` → Minor style cleanup
11. `breakdownSection` → Redesign card and row layout
12. `noteSection` → Minor style cleanup
13. `stickyBottomBar` → Visual refresh

**Sections to Keep Unchanged:**
- `setupInitialParticipants()`
- `sortedByCurrentUser()`
- `shortName(for:)`, `fullName(for:)`, `personColor(for:)`
- `avatarCircle()`, `avatarChip()`, `searchResultRow()`
- `paidBySearchResults`, `splitWithSearchResults` — Keep logic, minor style tweaks
- `rawInputBinding(for:)`, `initializeAmountDefault(for:)`
- All `@State` properties (add/modify as needed)
- All `.sheet()` modifiers for pickers
- All `.onChange()` handlers
- Preview provider

### No Changes Required:
- `TransactionViewModel.swift` — All state and logic preserved as-is
- `TwoPartySplitView.swift` — Keep existing component
- `SplitInputView.swift` — Keep existing component
- `DesignSystem.swift` — All tokens already defined, no new tokens needed
- `CurrencyFormatter.swift` — No changes needed
- CoreData models — No changes needed

---

## New Helper Functions Needed in AddTransactionView

### 1. `smartDateLabel` (computed property)
Returns "Today", "Yesterday", or formatted date string.

```swift
private var smartDateLabel: String {
    let calendar = Calendar.current
    if calendar.isDateInToday(viewModel.date) { return "Today" }
    if calendar.isDateInYesterday(viewModel.date) { return "Yesterday" }
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter.string(from: viewModel.date)
}
```

### 2. `currencyFlag` (computed property)
Returns flag emoji for currency code.

```swift
private var currencyFlag: String {
    CurrencyFormatter.flag(for: viewModel.transactionCurrency)
}
```

---

## Detailed Section Ordering in `body`

```swift
var body: some View {
    NavigationStack {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.sectionGap) {
                    heroAmountSection        // NEW: Hero amount + currency
                    transactionNameSection   // NEW: Title input card
                    categoryAndDateRow       // NEW: Category pill + date pill
                    paidBySection            // REDESIGNED
                    splitWithSection         // REDESIGNED
                    splitMethodSection       // REDESIGNED (horizontal scroll)
                    if viewModel.selectedPayerPersons.count > 1 {
                        paidByBreakdownSection // Minor cleanup
                    }
                    breakdownSection         // REDESIGNED
                    noteSection              // Minor cleanup
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.screenTopPad)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)

            stickyBottomBar              // Visual refresh
        }
        .background(/* existing dot grid background */)
        .navigationTitle("New Transaction")
        .navigationBarTitleDisplayMode(.inline)
        // ... existing toolbar, sheets, handlers
    }
}
```

**Note:** Add `.padding(.horizontal, Spacing.screenHorizontal)` to the VStack instead of individual sections. Remove per-section horizontal padding where it creates card insets — let the VStack handle screen margins consistently.

---

## Animation & Interaction Details

### Hero Amount
- Amount text scales with spring animation when first digit is entered
- Currency badge has press scale effect (0.95)

### Category/Date Pills
- Press scale effect (0.97) via `.buttonStyle(.plain)` + `.scaleEffect`
- Category pill background animates color change when category changes

### Split Method Pills
- Spring animation (`AppAnimation.spring`) on selection change
- Use `matchedGeometryEffect` or animated background for sliding selection indicator

### Participant Chips
- Insert/remove with `AppAnimation.spring`
- Undo toast preserved with existing timing

### Breakdown Rows
- Animate in with `.transition(.opacity.combined(with: .move(edge: .top)))`
- Total balance color transitions with `AppAnimation.standard`

### Save Button
- Pulse animation when form becomes valid (subtle opacity cycle)
- Scale effect on press (0.98)
- Checkmark appears with spring animation on success

---

## Accessibility Checklist

- [ ] All interactive elements have `accessibilityLabel`
- [ ] Currency badge: "Currency: USD. Tap to change."
- [ ] Category pill: "Category: Food & Drinks. Tap to change."
- [ ] Date pill: "Transaction date: Today. Tap to change."
- [ ] Amount field: "Transaction amount"
- [ ] Title field: "Transaction name"
- [ ] Split method pills: "Equal split method, selected"
- [ ] Participant chips: "Remove John" / "You, locked participant"
- [ ] Save button: "Save transaction"
- [ ] Minimum touch target: 44pt for all interactive elements

---

## Testing Strategy

### Visual Verification
1. Light mode and dark mode appearance
2. Empty state (no participants, no amount)
3. Single payer vs. multi-payer layout
4. All 5 split methods render correctly
5. 2-party split shows `TwoPartySplitView`
6. Note field expanded and collapsed states
7. Validation messages display correctly
8. Save button enabled/disabled states
9. Loading and success states on save
10. Currency picker, category picker, date picker sheets

### Functional Verification
1. Amount input sanitization still works (decimal handling, zero-decimal currencies)
2. Search contacts in Paid By and Split With
3. Add/remove participants with undo
4. Split calculations match for all 5 methods
5. Multi-payer amount breakdown validation
6. Save transaction persists correctly to CoreData
7. Initial participant/group pre-population
8. Currency change strips decimals for zero-decimal currencies
9. Keyboard dismiss on scroll and "Done" button
10. Focus field navigation (title → amount)

### Edge Cases
1. Very long transaction name (200 chars)
2. Many participants (10+) — chip wrapping
3. Large amounts ($999,999.99) — amount display doesn't truncate
4. Zero-decimal currencies (JPY, KRW) — no decimal point
5. Landscape orientation (if supported)
6. Dynamic Type accessibility sizes
7. VoiceOver navigation order

---

## Implementation Order

### Phase 1: Structural Refactor
1. Create `heroAmountSection` computed property
2. Create `transactionNameSection` computed property
3. Create `categoryAndDateRow` computed property
4. Add `smartDateLabel` helper
5. Update `body` with new section ordering
6. Remove old `transactionHeaderSection` and `amountAndDateSection`

### Phase 2: Section Redesigns
7. Redesign `paidBySection` card layout
8. Redesign `splitWithSection` card layout
9. Convert `splitMethodSection` to horizontal scroll
10. Redesign `breakdownSection` card and rows
11. Clean up `paidByBreakdownSection` styling
12. Refresh `noteSection` styling
13. Refresh `stickyBottomBar` visuals

### Phase 3: Polish
14. Add/verify all animations and transitions
15. Verify all accessibility labels
16. Test light mode and dark mode
17. Test all split methods
18. Test edge cases (empty states, long text, many participants)
19. Verify no regressions in save functionality

---

## Estimated Line Count

Current: ~1,349 lines
Expected: ~1,200-1,400 lines (similar — restructured, not necessarily shorter)

The rewrite reorganizes code for clarity rather than reducing it. Some sections get simpler (hero amount, category/date row) while others gain minor complexity (scroll-based split method, smart date label).
