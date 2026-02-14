# AI Prompt: Fix Currency Selection in New Transaction Page

## Problem Statement

**User is not able to select the currency in the new transaction page.**

The app has TWO transaction creation flows, and **neither** allows proper per-transaction currency selection with persistence:

1. **`AddTransactionView`** (primary flow from Home → "New Transaction") — has **NO currency picker at all**. It reads a global `@AppStorage("default_currency")` setting and displays the symbol as read-only text. The user cannot change the currency for an individual transaction.

2. **`QuickActionSheet`** (alternative 3-step flow) — has a `CurrencyPickerSheet` that lets the user select a currency, but the selection is **display-only**. The selected currency is shown in Steps 1–3 but is **never persisted** to CoreData when the transaction is saved. After saving, the currency data is lost.

Additionally, the `FinancialTransaction` CoreData entity has **no `currency` attribute** at all — meaning even if the UI allowed selection, there's nowhere to store it.

---

## Root Cause Analysis

### Issue 1: `AddTransactionView` has no currency picker
- **File**: `Swiss Coin/Features/Transactions/AddTransactionView.swift`
- The view uses `@AppStorage("default_currency")` (line ~13) and displays `CurrencyFormatter.currencySymbol` as static text
- There is no button, sheet, or interaction to change currency per-transaction
- The user must go to Profile → Currency Settings to change the global default, which affects ALL transactions

### Issue 2: CoreData model has no currency field
- **File**: `Swiss Coin/Models/CoreData/FinancialTransaction.swift`
- The entity only has: `id`, `title`, `amount`, `date`, `splitMethod`, `note`, plus relationships (`payer`, `createdBy`, `group`, `splits`, `payers`, `comments`)
- There is no `@NSManaged public var currency: String?` attribute
- **Schema file**: `Swiss Coin/Resources/Swiss_Coin.xcdatamodeld/Swiss_Coin 3.xcdatamodel/contents` (current version)
- The schema must be updated with a new version (Version 4) to add the `currency` attribute

### Issue 3: `TransactionViewModel.saveTransaction()` doesn't save currency
- **File**: `Swiss Coin/Features/Transactions/TransactionViewModel.swift`
- `saveTransaction()` (line 451) creates a `FinancialTransaction` entity but never sets a currency field
- `updateTransaction()` (line 678) also has no currency handling
- The ViewModel has no `@Published var currency` or `selectedCurrency` property

### Issue 4: `QuickActionViewModel.saveTransaction()` also doesn't persist currency
- **File**: `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift`
- Has `@Published var selectedCurrency: Currency` (initialized from global setting)
- Has `@Published var showCurrencyPicker: Bool = false`
- The `CurrencyPickerSheet` binding works correctly for UI updates
- But `saveTransaction()` never writes `selectedCurrency.code` to the CoreData entity

### Issue 5: Two duplicate, disconnected currency type systems
- **`Currency` struct** in `QuickActionModels.swift` (15 currencies) — used by QuickAction flow
- **`CurrencyOption` struct** in `CurrencySettingsView.swift` (16 currencies, includes NZD) — used by Profile settings
- **`CurrencyFormatter.configs`** in `CurrencyFormatter.swift` (15 currencies) — used for formatting
- These are not synchronized. NZD exists in settings but not in `Currency.all` or `CurrencyFormatter`

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    CURRENT STATE (BROKEN)                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  AddTransactionView                QuickActionSheet         │
│  ┌─────────────────┐               ┌──────────────────┐    │
│  │ Currency: $      │ (read-only)   │ Currency: [$ ▼]  │    │
│  │ (from global     │               │ (selectable but  │    │
│  │  AppStorage)     │               │  NOT persisted)  │    │
│  └────────┬────────┘               └────────┬─────────┘    │
│           │                                  │              │
│           ▼                                  ▼              │
│  TransactionViewModel            QuickActionViewModel       │
│  ┌─────────────────┐             ┌──────────────────┐      │
│  │ NO currency      │             │ selectedCurrency │      │
│  │ property         │             │ (in-memory only) │      │
│  └────────┬────────┘             └────────┬─────────┘      │
│           │                                │                │
│           ▼                                ▼                │
│  ┌──────────────────────────────────────────────────┐      │
│  │       FinancialTransaction (CoreData)             │      │
│  │  id | title | amount | date | splitMethod | note  │      │
│  │                                                    │      │
│  │  ❌ NO CURRENCY FIELD                              │      │
│  └──────────────────────────────────────────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────┐
│                    TARGET STATE (FIXED)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  AddTransactionView                QuickActionSheet         │
│  ┌─────────────────┐               ┌──────────────────┐    │
│  │ Currency: [$ ▼]  │ (selectable)  │ Currency: [$ ▼]  │    │
│  │ (defaults from   │               │ (selectable,     │    │
│  │  global setting)  │               │  persisted)      │    │
│  └────────┬────────┘               └────────┬─────────┘    │
│           │                                  │              │
│           ▼                                  ▼              │
│  TransactionViewModel            QuickActionViewModel       │
│  ┌─────────────────┐             ┌──────────────────┐      │
│  │ selectedCurrency │             │ selectedCurrency │      │
│  │ (Currency struct) │             │ (Currency struct) │      │
│  └────────┬────────┘             └────────┬─────────┘      │
│           │                                │                │
│           ▼                                ▼                │
│  ┌──────────────────────────────────────────────────┐      │
│  │       FinancialTransaction (CoreData)             │      │
│  │  id | title | amount | date | splitMethod | note  │      │
│  │  ✅ currency (String, optional, defaults "USD")   │      │
│  └──────────────────────────────────────────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Files to Modify (Priority Order)

### Phase 1: CoreData Schema Update

#### 1. Create new CoreData model version (Version 4)
- **Path**: `Swiss Coin/Resources/Swiss_Coin.xcdatamodeld/`
- **Action**: Create `Swiss_Coin 4.xcdatamodel` as a copy of Version 3
- Add `currency` attribute to `FinancialTransaction` entity:
  - Name: `currency`
  - Type: `String`
  - Optional: `YES`
  - Default Value: none (nil means "use global default" for backward compatibility)
- Update `.xccurrentversion` plist to point to `Swiss_Coin 4.xcdatamodel`
- This uses lightweight migration (no mapping model needed) since it's just adding an optional attribute

#### 2. `Swiss Coin/Models/CoreData/FinancialTransaction.swift`
- **Action**: Add managed property:
```swift
@NSManaged public var currency: String?
```
- Add computed convenience property:
```swift
/// Returns the currency code, falling back to the global default if not set
var effectiveCurrency: String {
    currency ?? (UserDefaults.standard.string(forKey: "default_currency") ?? "USD")
}
```

### Phase 2: ViewModel Updates

#### 3. `Swiss Coin/Features/Transactions/TransactionViewModel.swift`
- **Add** a `@Published var selectedCurrency: Currency` property, initialized from global setting:
```swift
@Published var selectedCurrency: Currency = Currency.fromGlobalSetting()
@Published var showCurrencyPicker: Bool = false
```
- **Modify** `saveTransaction()` (line 451): After creating the transaction entity, set:
```swift
transaction.currency = selectedCurrency.code
```
- **Modify** `updateTransaction()` (line 678): Also set:
```swift
transaction.currency = selectedCurrency.code
```
- **Modify** `loadTransaction()` (line 578): Load currency from existing transaction:
```swift
if let currencyCode = transaction.currency {
    selectedCurrency = Currency.fromCode(currencyCode)
}
```
- **Modify** `resetForm()` (line 556): Reset currency to global default:
```swift
selectedCurrency = Currency.fromGlobalSetting()
showCurrencyPicker = false
```

#### 4. `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift`
- **Modify** `saveTransaction()`: Set currency on the CoreData entity:
```swift
transaction.currency = selectedCurrency.code
```
- No other changes needed — this ViewModel already has `selectedCurrency` and `showCurrencyPicker`

### Phase 3: View Updates

#### 5. `Swiss Coin/Features/Transactions/AddTransactionView.swift`
- **Add** a currency selector button near the amount input field (similar to Step1BasicDetailsView)
- The button should:
  - Display `viewModel.selectedCurrency.symbol` (e.g., "$", "€", "CHF")
  - On tap: set `viewModel.showCurrencyPicker = true`
- **Add** a `.sheet` modifier that presents `CurrencyPickerSheet`:
```swift
.sheet(isPresented: $viewModel.showCurrencyPicker) {
    CurrencyPickerSheet(
        selectedCurrency: $viewModel.selectedCurrency,
        isPresented: $viewModel.showCurrencyPicker
    )
    .presentationDetents([.medium, .large])
}
```
- **Replace** any hardcoded `CurrencyFormatter.currencySymbol` references with `viewModel.selectedCurrency.symbol`
- **Remove** the `@AppStorage("default_currency")` property if it was only used for currency display (the ViewModel now owns this state)

#### 6. `Swiss Coin/Features/Transactions/TransactionEditView.swift`
- Same changes as AddTransactionView — add currency picker button and sheet
- When editing, the currency should be pre-populated from `viewModel.selectedCurrency` (loaded from the transaction in `loadTransaction()`)

### Phase 4: Display Updates (Show Saved Currency)

#### 7. `Swiss Coin/Features/Transactions/TransactionDetailView.swift`
- **Modify** amount display to use the transaction's saved currency instead of the global default
- Replace `CurrencyFormatter.format(transaction.amount)` with a per-transaction format:
```swift
CurrencyFormatter.format(transaction.amount, currencyCode: transaction.effectiveCurrency)
```
- OR use the Currency model:
```swift
let currency = Currency.fromCode(transaction.effectiveCurrency)
Text("\(currency.symbol)\(String(format: "%.2f", transaction.amount))")
```

#### 8. `Swiss Coin/Features/Transactions/TransactionRowView.swift`
- Same as above — display amounts with the transaction's own currency, not the global one

#### 9. `Swiss Coin/Features/Transactions/TransactionHistoryView.swift`
- Update any amount formatting to use per-transaction currency

### Phase 5: Utility Updates

#### 10. `Swiss Coin/Utilities/CurrencyFormatter.swift`
- **Add** an overloaded `format` method that accepts a currency code parameter:
```swift
/// Formats an amount using a specific currency code (for per-transaction display)
static func format(_ amount: Double, currencyCode: String) -> String {
    let config = configs[currencyCode] ?? configs["USD"]!
    let isZeroDecimal = (currencyCode == "JPY" || currencyCode == "KRW")

    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = config.code
    formatter.locale = Locale(identifier: config.locale)
    formatter.maximumFractionDigits = isZeroDecimal ? 0 : 2
    formatter.minimumFractionDigits = isZeroDecimal ? 0 : 2

    return formatter.string(from: NSNumber(value: amount))
        ?? "\(config.symbol)\(String(format: "%.2f", amount))"
}
```
- Consider caching these formatters if performance becomes an issue
- **Add** `formatAbsolute(_:currencyCode:)` and `formatWithSign(_:currencyCode:)` overloads as well

### Phase 6: Unify Currency Model (Cleanup)

#### 11. `Swiss Coin/Features/QuickAction/QuickActionModels.swift`
- **Add** NZD to `Currency.all` (currently missing but exists in CurrencySettingsView):
```swift
Currency(id: "NZD", code: "NZD", symbol: "NZ$", name: "New Zealand Dollar", flag: "🇳🇿"),
```
- This ensures the currency picker in the transaction flow matches what's available in settings

#### 12. `Swiss Coin/Features/Profile/CurrencySettingsView.swift`
- **Consider** refactoring `CurrencyOption` to use the shared `Currency` struct from QuickActionModels, eliminating the duplicate type
- Or at minimum, ensure both lists contain the same currencies

#### 13. `Swiss Coin/Utilities/CurrencyFormatter.swift`
- **Add** NZD config to the `configs` dictionary:
```swift
"NZD": CurrencyConfig(code: "NZD", locale: "en_NZ", symbol: "NZ$", flag: "🇳🇿"),
```

---

## Detailed Code Changes

### CoreData Schema XML (Version 4)

Add this attribute to the `FinancialTransaction` entity in the new `.xcdatamodel`:
```xml
<attribute name="currency" optional="YES" attributeType="String"/>
```

Full entity should look like:
```xml
<entity name="FinancialTransaction" representedClassName="FinancialTransaction" syncable="YES">
    <attribute name="id" optional="NO" attributeType="UUID" usesScalarValueType="NO"/>
    <attribute name="title" optional="NO" attributeType="String"/>
    <attribute name="amount" optional="NO" attributeType="Double" usesScalarValueType="YES"/>
    <attribute name="date" optional="NO" attributeType="Date" usesScalarValueType="NO"/>
    <attribute name="splitMethod" optional="YES" attributeType="String"/>
    <attribute name="note" optional="YES" attributeType="String"/>
    <attribute name="currency" optional="YES" attributeType="String"/>
    <relationship name="payer" ... />
    <relationship name="createdBy" ... />
    <relationship name="group" ... />
    <relationship name="splits" ... />
    <relationship name="payers" ... />
    <relationship name="comments" ... />
</entity>
```

### TransactionViewModel Changes

```swift
// ADD these properties (after line 12):
@Published var selectedCurrency: Currency = Currency.fromGlobalSetting()
@Published var showCurrencyPicker: Bool = false

// MODIFY saveTransaction() — after line 469 (transaction.splitMethod = ...):
transaction.currency = selectedCurrency.code

// MODIFY updateTransaction() — after line 692 (transaction.splitMethod = ...):
transaction.currency = selectedCurrency.code

// MODIFY loadTransaction() — add after line 588 (splitMethod loading):
if let currencyCode = transaction.currency {
    selectedCurrency = Currency.fromCode(currencyCode)
} else {
    selectedCurrency = Currency.fromGlobalSetting()
}

// MODIFY resetForm() — add after line 566 (rawInputs = [:]):
selectedCurrency = Currency.fromGlobalSetting()
showCurrencyPicker = false
```

### AddTransactionView Currency Picker Button

Add adjacent to the amount input field:
```swift
// Currency selector button
Button {
    HapticManager.tap()
    viewModel.showCurrencyPicker = true
} label: {
    HStack(spacing: Spacing.xs) {
        Text(viewModel.selectedCurrency.flag)
            .font(.system(size: IconSize.md))
        Text(viewModel.selectedCurrency.symbol)
            .font(AppTypography.bodyLarge())
            .foregroundColor(AppColors.textSecondary)
    }
    .padding(.horizontal, Spacing.md)
    .padding(.vertical, Spacing.xs)
    .background(AppColors.backgroundTertiary)
    .cornerRadius(CornerRadius.xs)
}
.sheet(isPresented: $viewModel.showCurrencyPicker) {
    CurrencyPickerSheet(
        selectedCurrency: $viewModel.selectedCurrency,
        isPresented: $viewModel.showCurrencyPicker
    )
    .presentationDetents([.medium, .large])
}
```

---

## Backward Compatibility

- **Existing transactions** have `currency == nil`. The `effectiveCurrency` computed property falls back to the global default, so old transactions will display using whatever currency the user has set globally — same behavior as before.
- **Lightweight migration** handles adding an optional String attribute without data loss.
- **No breaking changes** to any existing API or data.

---

## Test Checklist

1. [ ] **AddTransactionView**: Currency picker button appears next to amount field
2. [ ] **AddTransactionView**: Tapping currency button opens `CurrencyPickerSheet`
3. [ ] **AddTransactionView**: Selecting a currency updates the displayed symbol
4. [ ] **AddTransactionView**: Default currency matches global setting from Profile
5. [ ] **AddTransactionView**: Saving transaction persists the selected currency to CoreData
6. [ ] **QuickActionSheet**: Currency selection still works in Step 1
7. [ ] **QuickActionSheet**: Saving transaction now persists currency to CoreData
8. [ ] **TransactionDetailView**: Displays amount with the transaction's saved currency
9. [ ] **TransactionRowView**: Shows correct currency symbol per transaction
10. [ ] **TransactionEditView**: Currency is pre-populated from saved transaction
11. [ ] **TransactionEditView**: User can change currency and save
12. [ ] **Backward compat**: Old transactions (currency=nil) display with global default
13. [ ] **CoreData migration**: App launches without crash after schema update
14. [ ] **Currency list consistency**: All 16 currencies appear in picker (including NZD)
15. [ ] **CurrencyFormatter**: `format(_:currencyCode:)` overload works correctly
16. [ ] **Reset form**: Creating a new transaction after saving resets currency to default

---

## Summary Table

| File | Action | Priority |
|------|--------|----------|
| `Swiss_Coin.xcdatamodeld` | Create Version 4, add `currency` attribute | P0 |
| `FinancialTransaction.swift` | Add `@NSManaged currency`, add `effectiveCurrency` | P0 |
| `TransactionViewModel.swift` | Add `selectedCurrency`, persist in save/update/load/reset | P0 |
| `AddTransactionView.swift` | Add currency picker button + sheet | P0 |
| `QuickActionViewModel.swift` | Persist `selectedCurrency.code` on save | P0 |
| `CurrencyFormatter.swift` | Add `format(_:currencyCode:)` overload, add NZD | P1 |
| `TransactionDetailView.swift` | Use per-transaction currency for display | P1 |
| `TransactionRowView.swift` | Use per-transaction currency for display | P1 |
| `TransactionEditView.swift` | Add currency picker, pre-populate from transaction | P1 |
| `TransactionHistoryView.swift` | Use per-transaction currency for display | P2 |
| `QuickActionModels.swift` | Add NZD to `Currency.all` | P2 |
| `CurrencySettingsView.swift` | Consider unifying with `Currency` struct | P3 |

---

## Constraints

- **iOS 16+** minimum target
- **SwiftUI** only (no UIKit for new views)
- **CoreData lightweight migration** (no mapping models)
- **No external dependencies** — all currency data is hardcoded
- Use the app's existing **Design System**: `AppColors`, `AppTypography`, `Spacing`, `CornerRadius`, `IconSize`, `HapticManager`
- Follow existing code patterns (e.g., `CurrencyPickerSheet` already exists and works — reuse it)
- Do NOT remove or break the global currency setting in Profile — it should still work as the default for new transactions
