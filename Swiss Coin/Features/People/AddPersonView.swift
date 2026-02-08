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
    @State private var showingDuplicateWarning = false
    @State private var duplicatePersonName: String = ""
    @State private var showingNameDuplicateWarning = false
    @State private var isSaving = false
    
    // Navigation state to conversation view
    @State private var newlyCreatedPerson: Person?
    @State private var existingPerson: Person?

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
                                .font(AppTypography.footnote())
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, Spacing.lg + Spacing.xxs)

                            VStack(spacing: 0) {
                                // Name Input Row
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundColor(AppColors.accent)
                                        .frame(width: 24)

                                    TextField("Name", text: $name)
                                        .font(AppTypography.body())
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
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundColor(AppColors.accent)
                                        .frame(width: 24)

                                    TextField("Phone Number", text: $phoneNumber)
                                        .font(AppTypography.body())
                                        .foregroundColor(AppColors.textPrimary)
                                        .keyboardType(.phonePad)
                                        .limitTextLength(to: ValidationLimits.maxPhoneLength, text: $phoneNumber)
                                        .onChange(of: phoneNumber) { _, newValue in
                                            // Filter to only allow valid phone number characters
                                            let filtered = newValue.filter { char in
                                                char.isNumber || char == "+" || char == " " || char == "-" || char == "(" || char == ")"
                                            }
                                            if filtered != newValue {
                                                phoneNumber = filtered
                                            }
                                            checkDuplicatePhone(filtered)
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
                        }

                        // Import Section
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("IMPORT")
                                .font(AppTypography.footnote())
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
                                        .frame(width: 24)

                                    Text("Import from Phone Contacts")
                                        .font(AppTypography.body())
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
                        .buttonStyle(PrimaryButtonStyle(isEnabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !showingDuplicateWarning && !isSaving))
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || showingDuplicateWarning || isSaving)
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
                ContactPicker(name: $name, phoneNumber: $phoneNumber)
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

        guard !isSaving else { return }
        isSaving = true

        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if contact with this phone already exists - navigate to them instead
        if !trimmedPhone.isEmpty {
            if let existingPerson = findExistingPerson(byPhone: trimmedPhone) {
                HapticManager.selectionChanged()
                self.existingPerson = existingPerson
                isSaving = false
                return
            }
        }

        let newPerson = Person(context: viewContext)
        newPerson.id = UUID()
        newPerson.name = trimmedName
        newPerson.phoneNumber = trimmedPhone.isEmpty ? nil : trimmedPhone

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
                parent.phoneNumber = firstPhoneNumber
            }
        }
    }
}
