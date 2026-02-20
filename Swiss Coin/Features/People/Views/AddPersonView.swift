import ContactsUI
import CoreData
import os
import SwiftUI

struct AddPersonView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingContactPicker = false
    @State private var name: String = ""
    @State private var phoneNumber: String = ""
    @State private var selectedCountry = CountryCode.unitedStates
    @State private var showCountryPicker = false
    @State private var showingDuplicateWarning = false
    @State private var duplicatePersonName: String = ""
    @State private var showingNameDuplicateWarning = false
    @State private var isSaving = false

    // Navigation state to conversation view
    @State private var newlyCreatedPerson: Person?
    @State private var existingPerson: Person?

    /// The full E.164 phone number composed from country code + digits
    private var e164Phone: String {
        let digits = phoneNumber.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        return selectedCountry.dialCode + digits
    }

    /// Whether the phone field has a valid number
    private var isPhoneValid: Bool {
        let digits = phoneNumber.filter(\.isNumber)
        return digits.count >= 4
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        // Contact Details Section
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("CONTACT DETAILS")
                                .font(AppTypography.bodySmall())
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, Spacing.lg + Spacing.xxs)

                            VStack(spacing: 0) {
                                // Name Input Row
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundColor(AppColors.accent)
                                        .frame(width: IconSize.lg)

                                    TextField("Name", text: $name)
                                        .font(AppTypography.bodyLarge())
                                        .foregroundColor(AppColors.textPrimary)
                                        .limitTextLength(to: ValidationLimits.maxNameLength, text: $name)
                                        .onChange(of: name) { _, newValue in
                                            checkDuplicateName(newValue)
                                        }
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)

                                Divider()
                                    .padding(.leading, Spacing.lg)

                                // Phone Input Row
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundColor(AppColors.accent)
                                        .frame(width: IconSize.lg)

                                    // Country code selector
                                    Button {
                                        HapticManager.tap()
                                        showCountryPicker = true
                                    } label: {
                                        HStack(spacing: Spacing.xxs) {
                                            Text(selectedCountry.flag)
                                                .font(.system(size: IconSize.sm))
                                            Text(selectedCountry.dialCode)
                                                .font(AppTypography.bodyLarge())
                                                .foregroundColor(AppColors.textPrimary)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(AppColors.textTertiary)
                                        }
                                    }
                                    .accessibilityLabel("\(selectedCountry.name), \(selectedCountry.dialCode)")

                                    Rectangle()
                                        .fill(AppColors.divider)
                                        .frame(width: 1, height: 24)

                                    TextField("Phone Number", text: $phoneNumber)
                                        .font(AppTypography.bodyLarge())
                                        .foregroundColor(AppColors.textPrimary)
                                        .keyboardType(.phonePad)
                                        .limitTextLength(to: ValidationLimits.maxPhoneLength, text: $phoneNumber)
                                        .onChange(of: phoneNumber) { _, newValue in
                                            let filtered = newValue.filter(\.isNumber)
                                            if filtered != newValue {
                                                phoneNumber = filtered
                                            }
                                            checkDuplicatePhone(e164Phone)
                                        }
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(AppColors.cardBackground)
                            )
                            .padding(.horizontal)

                            // Duplicate Warnings
                            if showingDuplicateWarning {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundColor(AppColors.warning)
                                    Text("Phone already used by \(duplicatePersonName)")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.warning)
                                }
                                .padding(.horizontal, Spacing.lg + Spacing.xxs)
                                .padding(.top, Spacing.xxs)
                            }

                            if showingNameDuplicateWarning && phoneNumber.isEmpty {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundColor(AppColors.textSecondary)
                                    Text("A contact with this name already exists")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(.horizontal, Spacing.lg + Spacing.xxs)
                                .padding(.top, Spacing.xxs)
                            }

                            // Phone required hint
                            if !isPhoneValid && !phoneNumber.isEmpty {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundColor(AppColors.textSecondary)
                                    Text("Enter at least 4 digits")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(.horizontal, Spacing.lg + Spacing.xxs)
                                .padding(.top, Spacing.xxs)
                            } else if phoneNumber.isEmpty {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundColor(AppColors.textTertiary)
                                    Text("Phone number required for sharing transactions")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textTertiary)
                                }
                                .padding(.horizontal, Spacing.lg + Spacing.xxs)
                                .padding(.top, Spacing.xxs)
                            }
                        }

                        // Import Section
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("IMPORT")
                                .font(AppTypography.bodySmall())
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, Spacing.lg + Spacing.xxs)

                            Button(action: {
                                HapticManager.tap()
                                showingContactPicker = true
                            }) {
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundColor(AppColors.accent)
                                        .frame(width: IconSize.lg)

                                    Text("Import from Phone Contacts")
                                        .font(AppTypography.bodyLarge())
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: IconSize.xs, weight: .semibold))
                                        .foregroundColor(AppColors.textTertiary)
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(AppButtonStyle(haptic: .none))
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(AppColors.cardBackground)
                            )
                            .padding(.horizontal)
                        }

                        // Save Button Section
                        Button {
                            HapticManager.tap()
                            addPerson()
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(AppColors.buttonForeground)
                            } else {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: IconSize.sm))
                                    Text("Save Contact")
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isPhoneValid && !showingDuplicateWarning && !isSaving))
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isPhoneValid || showingDuplicateWarning || isSaving)
                        .padding(.horizontal)
                    }
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.section)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.large)
            // Navigation to conversation view after saving
            .navigationDestination(item: $newlyCreatedPerson) { person in
                PersonConversationView(person: person)
                    .navigationBarBackButtonHidden(false)
            }
            // Navigation to conversation view for existing contact
            .navigationDestination(item: $existingPerson) { person in
                PersonConversationView(person: person)
                    .navigationBarBackButtonHidden(false)
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactPicker(name: $name, phoneNumber: $phoneNumber, selectedCountry: $selectedCountry)
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryCodePicker(selectedCountry: $selectedCountry)
            }
        }
    }

    private func checkDuplicatePhone(_ phone: String) {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showingDuplicateWarning = false
            return
        }

        let normalized = trimmed.normalizedPhoneNumber()

        // Check against both original and normalized phone numbers
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "phoneNumber == %@ OR phoneNumber == %@",
            trimmed, normalized
        )
        fetchRequest.fetchLimit = 1

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let existing = results.first {
                duplicatePersonName = existing.name ?? "another contact"
                showingDuplicateWarning = true
            } else {
                showingDuplicateWarning = false
            }
        } catch {
            AppLogger.coreData.error("Failed to check duplicate phone: \(error.localizedDescription)")
            showingDuplicateWarning = false
        }
    }

    private func checkDuplicateName(_ nameValue: String) {
        let trimmed = nameValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showingNameDuplicateWarning = false
            return
        }

        // Only warn about name duplicates when no phone number is provided
        // This is a soft warning since multiple people can have the same name
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "name ==[c] %@ AND (phoneNumber == nil OR phoneNumber == %@)",
            trimmed, ""
        )
        fetchRequest.fetchLimit = 1

        do {
            let results = try viewContext.fetch(fetchRequest)
            showingNameDuplicateWarning = !results.isEmpty
        } catch {
            showingNameDuplicateWarning = false
        }
    }

    /// Find existing person by phone number
    private func findExistingPerson(byPhone phone: String) -> Person? {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let normalized = trimmed.normalizedPhoneNumber()
        
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "phoneNumber == %@ OR phoneNumber == %@",
            trimmed, normalized
        )
        fetchRequest.fetchLimit = 1

        do {
            return try viewContext.fetch(fetchRequest).first
        } catch {
            AppLogger.coreData.error("Failed to find existing person: \(error.localizedDescription)")
            return nil
        }
    }

    private func addPerson() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            HapticManager.error()
            return
        }
        guard isPhoneValid else {
            HapticManager.error()
            return
        }

        guard !isSaving else { return }
        isSaving = true

        // Normalize phone to E.164 format
        let normalizedPhone = e164Phone

        // Check if contact with this phone already exists - navigate to them instead
        if let existingPerson = findExistingPerson(byPhone: normalizedPhone) {
            HapticManager.selectionChanged()
            self.existingPerson = existingPerson
            isSaving = false
            return
        }

        let newPerson = Person(context: viewContext)
        newPerson.id = UUID()
        newPerson.name = trimmedName
        newPerson.phoneNumber = normalizedPhone

        // Assign a random color hex for avatar - ensure proper 6-digit format
        let randomColor = Int.random(in: 0...0xFFFFFF)
        newPerson.colorHex = String(format: "#%06X", randomColor)

        do {
            try viewContext.save()
            HapticManager.success()

            // Navigate to conversation view instead of just dismissing
            newlyCreatedPerson = newPerson
            isSaving = false
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.coreData.error("Failed to save person: \(error.localizedDescription)")
            isSaving = false
        }
    }
}

// MARK: - Contact Picker

struct ContactPicker: UIViewControllerRepresentable {
    @Binding var name: String
    @Binding var phoneNumber: String
    @Binding var selectedCountry: CountryCode

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactPhoneNumbersKey, CNContactGivenNameKey, CNContactFamilyNameKey,
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context)
    {}

    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker

        init(_ parent: ContactPicker) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let givenName = contact.givenName
            let familyName = contact.familyName
            parent.name = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)

            if let firstPhoneNumber = contact.phoneNumbers.first?.value.stringValue {
                // Detect country code from the imported phone number
                let digits = firstPhoneNumber.filter(\.isNumber)
                let hasPlus = firstPhoneNumber.hasPrefix("+")

                if hasPlus {
                    // Phone has international prefix — detect country code
                    let fullDigits = "+" + digits
                    if let matched = CountryCode.all.first(where: { fullDigits.hasPrefix($0.dialCode) }) {
                        parent.selectedCountry = matched
                        // Strip the dial code prefix from digits
                        let dialDigits = matched.dialCode.filter(\.isNumber)
                        if digits.hasPrefix(dialDigits) {
                            parent.phoneNumber = String(digits.dropFirst(dialDigits.count))
                        } else {
                            parent.phoneNumber = digits
                        }
                    } else {
                        parent.phoneNumber = digits
                    }
                } else {
                    // Local number — strip leading zero if present, keep current country code
                    if digits.hasPrefix("0") {
                        parent.phoneNumber = String(digits.dropFirst())
                    } else {
                        parent.phoneNumber = digits
                    }
                }
            }
        }
    }
}
