# Currency System Changes

## Summary

Completely rewrote the currency system to support 15 currencies with proper locale formatting, replacing the hardcoded CHF/USD approach. Users can now select their preferred currency in Settings, and all views dynamically reflect that choice.

---

## Files Changed

### 1. `Swiss Coin/Utilities/CurrencyFormatter.swift` — **Full Rewrite**

- **Before:** Hardcoded to Swiss Franc (CHF) with `de_CH` locale only.
- **After:** Reads the user's selected currency from `UserDefaults("default_currency")`, defaulting to `"USD"`.
- Supports 15 currencies: USD, EUR, GBP, INR, CNY, JPY, CHF, CAD, AUD, KRW, SGD, AED, BRL, MXN, SEK.
- Each currency has a proper `NumberFormatter` with locale-specific formatting (e.g., CHF uses Swiss apostrophe grouping `1'234.56`, EUR uses comma decimals `1.234,56`, JPY/KRW use zero decimal places).
- Formatters are cached and automatically rebuilt when the selected currency changes.
- **Preserved all existing method signatures:** `format(_:)`, `formatAbsolute(_:)`, `formatDecimal(_:)`, `formatWithSign(_:)`, `formatCompact(_:)`, `parse(_:)` — drop-in compatible everywhere.
- **New computed properties:** `currencySymbol` (e.g., "$", "€", "CHF"), `currencyFlag` (e.g., "🇺🇸"), `currencyCode` (e.g., "USD").
- Backward-compatible `parse()` still handles legacy "CHF" and "Fr." strings.

### 2. `Swiss Coin/Features/Profile/CurrencySettingsView.swift` — **Rewritten**

- Uses `@AppStorage("default_currency")` (same key as `CurrencyFormatter`, `ProfileView`, and `SupabaseManager`).
- All 15 supported currencies listed with flags, names, and symbols.
- Currencies grouped into **Popular** (USD, EUR, GBP, JPY, CHF, CAD, AUD, INR) and **Other** (CNY, KRW, SGD, AED, BRL, MXN, SEK).
- Live format preview showing `CurrencyFormatter.format(1234.56)` for the selected currency.
- Search filters by name, code, or symbol.
- Removed non-functional display settings (show_currency_symbol, decimal_places) that were never wired to the formatter.
- Uses the app's design system consistently (AppColors, AppTypography, Spacing, etc.).

### 3. `Swiss Coin/Features/QuickAction/QuickActionModels.swift` — **Updated**

- **Currency.all** expanded from 6 to 15 currencies, including CHF (Swiss Franc).
- Added `Currency.fromCode(_:)` static method for lookup by ISO code.
- Added `Currency.fromGlobalSetting()` static method that reads from `UserDefaults("default_currency")`.
- **SplitMethod.amount.icon** changed from hardcoded `"$"` to `CurrencyFormatter.currencySymbol` so the split method chip dynamically shows the user's currency symbol.

### 4. `Swiss Coin/Features/QuickAction/Step1BasicDetailsView.swift` — **Updated**

- **Removed** the per-transaction currency picker (the currency was collected but never persisted to the transaction entity, causing confusion).
- Currency display now reads from the global setting via `CurrencyFormatter.currencyFlag` and `CurrencyFormatter.currencySymbol`.
- Users set their currency once in Settings → Currency, and it applies everywhere.

### 5. `Swiss Coin/Features/QuickAction/Step3SplitMethodView.swift` — **Updated**

- All `viewModel.selectedCurrency.symbol` references → `CurrencyFormatter.currencySymbol`.
- All `currency.symbol` references in `SplitPersonRow` → `CurrencyFormatter.currencySymbol`.
- Removed `currency: Currency` parameter from `SplitPersonRow` (no longer needed).
- Affected sub-views: `SplitSummaryBar`, `SplitPersonRow`, `OwesSummaryView`.

### 6. `Swiss Coin/Features/QuickAction/QuickActionViewModel.swift` — **Updated**

- `selectedCurrency` now initializes from `Currency.fromGlobalSetting()` instead of `Currency.all[0]`.
- `resetForm()` also resets to the global setting.

### 7. `Swiss Coin/Features/Transactions/AddTransactionView.swift` — **Updated**

- Replaced `String(format: "$%.2f", calculated)` with `CurrencyFormatter.format(calculated)`.

### 8. `Swiss Coin/Features/Subscriptions/AddSubscriptionView.swift` — **Updated**

- Replaced `Text("$")` with `Text(CurrencyFormatter.currencySymbol)`.

### 9. `Swiss Coin/Features/Subscriptions/EditSubscriptionView.swift` — **Updated**

- Replaced `Text("$")` with `Text(CurrencyFormatter.currencySymbol)`.

### 10. `Swiss Coin/Features/Subscriptions/RecordSubscriptionPaymentView.swift` — **Updated**

- Replaced `Text("$")` with `Text(CurrencyFormatter.currencySymbol)`.

### 11. `Swiss Coin/Features/Subscriptions/SubscriptionSettlementView.swift` — **Updated**

- Replaced `Text("$")` with `Text(CurrencyFormatter.currencySymbol)`.

---

## Design Decisions

| Decision | Rationale |
|---|---|
| Used `"default_currency"` UserDefaults key (not `"selected_currency"`) | Matches the existing key used by `ProfileView.swift` and `SupabaseManager.swift` for cloud sync. Changing the key would break existing user preferences and sync. |
| Removed per-transaction currency picker from QuickAction Step 1 | The selected currency was never saved to the transaction entity — it was collected but discarded. Removed to avoid user confusion. Currency is now set globally in Settings. |
| Used `en_AE` locale for AED (not `ar_AE`) | `ar_AE` produces Arabic-Indic numerals (١٢٣) which would look inconsistent in an English-primary app. `en_AE` gives Western digits. |
| JPY and KRW use 0 decimal places | Standard convention — these currencies don't use fractional units in everyday use. |
| Cached formatters with lazy invalidation | `NumberFormatter` creation is expensive. Formatters are cached and only rebuilt when the currency selection changes. |

---

## What Stayed the Same

- All existing `CurrencyFormatter` method signatures — every call site works without changes.
- `CurrencyOption` struct in `CurrencySettingsView` (used only by that view).
- `Currency` struct in `QuickActionModels` (expanded but backward-compatible).
- Core Data model — no schema changes.
- All other views that call `CurrencyFormatter.format()` etc. — they automatically pick up the new currency.
