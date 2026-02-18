# People & Group Edit/Delete Features — Changes Summary

## New Files Created

### 1. `Swiss Coin/Features/People/EditPersonView.swift`
- Full edit form for Person entities with pre-populated data (name, phone, color)
- Live avatar preview that updates as the user types
- `ColorPickerRow` integration for profile color selection
- Duplicate phone number detection (warns if phone already used by another person)
- Change tracking — Save button is disabled when no changes have been made
- Proper CoreData save with `try/catch` and `context.rollback()` on failure
- Cancel/Save toolbar buttons with `HapticManager` feedback

### 2. `Swiss Coin/Features/People/EditGroupView.swift`
- Full edit form for UserGroup entities with pre-populated data (name, color, members)
- `ColorPickerRow` integration for group color selection
- Member selection list showing all existing Person entities (excluding current user)
- Selected members preview with horizontal scroll (tap to remove)
- Search bar to filter people
- CurrentUser is always preserved as a group member (cannot be removed)
- Change tracking — Save disabled when nothing has changed
- Proper CoreData save with rollback on failure

## Modified Files

### 3. `Swiss Coin/Features/People/PersonDetailView.swift`
- Added `@Environment(\.managedObjectContext)` and `@Environment(\.dismiss)`
- Added toolbar with ellipsis menu containing **Edit** and **Delete** options
- Edit opens `EditPersonView` as a sheet inside a `NavigationStack`
- Delete shows a confirmation alert before removing the Person entity
- `deletePerson()` function with CoreData save, rollback on error, haptic feedback
- On successful delete, view dismisses automatically

### 4. `Swiss Coin/Features/People/GroupDetailView.swift`
- Added `@Environment(\.managedObjectContext)` and `@Environment(\.dismiss)`
- Added toolbar with ellipsis menu containing **Edit** and **Delete** options
- Edit opens `EditGroupView` as a sheet inside a `NavigationStack`
- Delete shows a confirmation alert before removing the UserGroup entity
- `deleteGroup()` function with CoreData save, rollback on error, haptic feedback
- On successful delete, view dismisses automatically

### 5. `Swiss Coin/Features/People/PeopleView.swift`
**PersonListRowView:**
- Added `@Environment(\.managedObjectContext)`
- Added `showingEditPerson` and `showingDeleteConfirmation` state
- Context menu now includes: View Profile, **Edit**, Add Expense, Send Reminder, **Delete** (destructive, with divider)
- Edit opens `EditPersonView` in a sheet
- Delete shows confirmation alert, then removes Person via CoreData
- `deletePerson()` function with proper error handling

**GroupListRowView:**
- Added `@Environment(\.managedObjectContext)`
- Added `showingEditGroup` and `showingDeleteConfirmation` state
- Context menu now includes: View Group Info, **Edit**, Add Expense, Send Reminders, **Delete** (destructive, with divider)
- Edit opens `EditGroupView` in a sheet
- Delete shows confirmation alert, then removes UserGroup via CoreData
- `deleteGroup()` function with proper error handling

### 6. `Swiss Coin/Features/People/ImportContactsView.swift`
- Added `existingPhoneNumbers` state to cache known phone numbers on load
- `loadExistingPhoneNumbers()` fetches all Person phone numbers from CoreData on appear
- `contactAlreadyExists()` checks if any of a contact's phone numbers match existing ones
- Contact rows for already-added contacts show "Already added" label in warning color
- Already-added contacts are visually dimmed (0.6 opacity) and their buttons are disabled
- `importContacts()` now skips contacts that already exist as a safety net

### 7. `Swiss Coin/Features/People/AddPersonView.swift`
- Added `showingDuplicateWarning` and `duplicatePersonName` state
- Phone number field has `onChange` handler that triggers `checkDuplicatePhone()`
- `checkDuplicatePhone()` queries CoreData for existing Person with same phone number
- Warning banner shown below phone field when duplicate detected (orange triangle icon + text)

## Design Patterns Followed
- All UI uses `AppColors`, `AppTypography`, `Spacing`, `CornerRadius`, `IconSize`, `AvatarSize`, `ButtonHeight`
- `HapticManager` used for all interactions: `.tap()` for actions, `.success()` on save, `.error()` on failure, `.cancel()` on cancel, `.selectionChanged()` for toggles
- CoreData saves wrapped in `do/try/catch` with `viewContext.rollback()` on failure
- Confirmation alerts before destructive delete actions
- Sheets wrapped in `NavigationStack` for proper navigation bar display
- `@ObservedObject` for CoreData entities to auto-refresh UI on changes
