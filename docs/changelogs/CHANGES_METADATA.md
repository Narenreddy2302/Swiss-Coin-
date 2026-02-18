# Metadata & Project Configuration Audit — Changes Summary

**Date:** 2026-02-02  
**Scope:** Xcode project settings, Info.plist, assets, CoreData, .gitignore, README, entry point, bundle config, cleanup

---

## 1. Xcode Project Settings

### ✅ FIXED: Deployment Target Lowered from iOS 18.0 → 17.0
- **Why:** The app uses iOS 17+ APIs (2-parameter `.onChange`, `#Preview` macro) but nothing iOS 18-specific. iOS 17.0 covers a much broader device base.
- **Changed in:** All 6 build configurations (project-level Debug/Release, Swiss Coin Debug/Release, Tests Debug/Release, UITests Debug/Release)
- **Build settings consistency:** ✅ All configurations now consistent at 17.0

### ✅ OK: Build Settings
- `SWIFT_VERSION = 5.0` ✓
- `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad) ✓
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` ✓
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` ✓ (Swift 6 readiness)
- `ENABLE_PREVIEWS = YES` ✓
- `CODE_SIGN_STYLE = Automatic` ✓
- `DEVELOPMENT_TEAM = 4A7TYP7FGW` ✓ (consistent across all targets)

---

## 2. Info.plist / Privacy Descriptions

### ✅ FIXED: Created `Swiss Coin/Info.plist`
New file with all required privacy descriptions:
- `NSContactsUsageDescription` — for ContactsManager phone contacts import
- `NSFaceIDUsageDescription` — for PrivacySecurityView biometric authentication
- `NSPhotoLibraryUsageDescription` — for PersonalDetailsView profile photo picker

### ✅ FIXED: Added Missing INFOPLIST_KEY entries to pbxproj
Added to both Debug and Release configurations of the main target:
- `INFOPLIST_FILE = "Swiss Coin/Info.plist"`
- `INFOPLIST_KEY_CFBundleDisplayName = "Swiss Coin"`
- `INFOPLIST_KEY_NSFaceIDUsageDescription` — **was completely missing** ⚠️
- `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` — **was completely missing** ⚠️
- Improved `NSContactsUsageDescription` wording (was generic, now mentions app name)

### ⚠️ Note: Notifications
- `UNUserNotificationCenter.requestAuthorization()` does NOT require an Info.plist entry — the system shows a standard prompt. No action needed.

---

## 3. App Icons and Assets

### ⚠️ WARNING: AppIcon has no actual image files
- `AppIcon.appiconset/Contents.json` has 3 entries (universal, dark, tinted) but **none have `"filename"` keys** — meaning no icon images are present.
- **Action required:** Add a 1024×1024 app icon PNG to the asset catalog before App Store submission.
- This was NOT auto-fixed (requires actual image file from designer).

### ✅ FIXED: AccentColor was empty
- Previously had no color values defined (just `"idiom": "universal"` with no color data)
- Added a Swiss-inspired red accent color:
  - Light mode: `rgb(217, 48, 52)` — Swiss red
  - Dark mode: `rgb(234, 72, 76)` — lighter variant for dark backgrounds

---

## 4. CoreData Model Versioning

### ✅ OK: Model version properly set
- `.xccurrentversion` correctly points to `Swiss_Coin.xcdatamodel`
- Single model version (no versioning complexity)

### ✅ OK: Lightweight migration configured
In `Persistence.swift`:
- `shouldMigrateStoreAutomatically = true` ✓
- `shouldInferMappingModelAutomatically = true` ✓
- Robust error handling with store destruction fallback for incompatible migrations ✓

### ✅ OK: Model integrity
- 11 entities with proper relationships and inverse relationships
- All delete rules properly set (Cascade for owned data, Nullify for references)

---

## 5. .gitignore

### ✅ FIXED: Added missing entries
Added:
- `*.xcworkspace/xcuserdata/`
- `build/`
- `*.ipa`
- `*.dSYM.zip`
- `*.dSYM`
- `._*` (macOS resource forks)
- `iOSInjectionProject/`
- `timeline.xctimeline`
- `playground.xcworkspace`
- Temp files (`*.swp`, `*~`)

Already present (kept):
- `xcuserdata/`, `DerivedData/`, `.DS_Store`, `Pods/`, `.build/`, `.swiftpm/`, fastlane, Carthage ✓

---

## 6. README.md

### ✅ FIXED: Complete rewrite
- Was: single line `# Swiss-Coin-`
- Now: comprehensive documentation with:
  - App description and feature list
  - Screenshots placeholder table
  - Tech stack details
  - Full architecture diagram with directory structure
  - Getting Started / setup instructions
  - CoreData model overview
  - License section

---

## 7. App Entry Point Verification

### ✅ OK: `Swiss_CoinApp.swift`
- `@main` annotation present ✓
- `PersistenceController.shared` properly initialized ✓
- `.environment(\.managedObjectContext, ...)` properly injected ✓
- Clean, minimal entry point ✓

---

## 8. Bundle Identifier and Display Name

### ✅ OK (with enhancement)
- `PRODUCT_BUNDLE_IDENTIFIER` = `SV.Swiss-Coin` ✓
- `PRODUCT_NAME` = `$(TARGET_NAME)` ✓
- `MARKETING_VERSION` = `1.0` ✓
- `CURRENT_PROJECT_VERSION` = `1` ✓

### ✅ FIXED: Added `CFBundleDisplayName`
- Added `INFOPLIST_KEY_CFBundleDisplayName = "Swiss Coin"` to ensure the app name displays correctly on the home screen (with space, not hyphen).

---

## 9. Report/Audit File Cleanup

### ✅ OK: No .md files inside app bundle
- All 28 SCAN_*, AUDIT_*, CHANGES_*, and other development .md files are in the **project root** (outside `Swiss Coin/` directory)
- Since the project uses `PBXFileSystemSynchronizedRootGroup` for `Swiss Coin/`, only files inside that directory get bundled
- **No cleanup action needed** — they won't ship with the app

---

## Files Modified
1. `Swiss Coin.xcodeproj/project.pbxproj` — deployment target, privacy keys, display name, Info.plist reference
2. `Swiss Coin/Info.plist` — **CREATED** — privacy usage descriptions
3. `Swiss Coin/Resources/Assets.xcassets/AccentColor.colorset/Contents.json` — added actual color values
4. `.gitignore` — expanded with missing iOS entries
5. `README.md` — complete rewrite

## Remaining Action Items (Manual)
1. **🎨 Add app icon images** — Drop 1024×1024 PNGs into `AppIcon.appiconset/` for light, dark, and tinted variants
2. **📸 Add screenshots** — Create `screenshots/` directory and add device screenshots for README
3. **🔑 Verify signing** — Confirm `DEVELOPMENT_TEAM = 4A7TYP7FGW` matches your Apple Developer account
