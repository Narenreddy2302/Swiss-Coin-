import CoreData
import os
import SwiftUI

struct EditPersonView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var person: Person

    @State private var name: String
    @State private var phoneNumber: String
    @State private var colorHex: String
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDuplicateWarning = false
    @State private var duplicatePersonName: String = ""

    init(person: Person) {
        self.person = person
        _name = State(initialValue: person.name ?? "")
        _phoneNumber = State(initialValue: person.phoneNumber ?? "")
        _colorHex = State(initialValue: person.colorHex ?? "#007AFF")
    }

    private var hasChanges: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalName = person.name ?? ""
        let originalPhone = person.phoneNumber ?? ""
        let originalColor = person.colorHex ?? "#007AFF"

        return trimmedName != originalName
            || trimmedPhone != originalPhone
            || colorHex != originalColor
    }

    var body: some View {
        ZStack {
            AppColors.backgroundSecondary
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Avatar Preview
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color(hex: colorHex).opacity(0.2))
                            .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                            .overlay(
                                Text(editingInitials)
                                    .font(AppTypography.displayMedium())
                                    .foregroundColor(Color(hex: colorHex))
                            )
                        Spacer()
                    }
                    .padding(.vertical, Spacing.sm)

                    // Details Section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("DETAILS")
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
                                    .frame(width: IconSize.lg)

                                TextField("Phone Number", text: $phoneNumber)
                                    .font(AppTypography.bodyLarge())
                                    .foregroundColor(AppColors.textPrimary)
                                    .keyboardType(.phonePad)
                                    .limitTextLength(to: ValidationLimits.maxPhoneLength, text: $phoneNumber)
                                    .onChange(of: phoneNumber) { _, newValue in
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

                        // Duplicate Warning
                        if showingDuplicateWarning {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: IconSize.sm))
                                    .foregroundColor(AppColors.warning)
                                Text("Phone number already used by \(duplicatePersonName)")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.warning)
                            }
                            .padding(.horizontal, Spacing.lg + Spacing.xxs)
                            .padding(.top, Spacing.xxs)
                        }
                    }

                    // Color Section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("COLOR")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, Spacing.lg + Spacing.xxs)

                        ColorPickerRow(selectedColor: $colorHex)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(AppColors.cardBackground)
                            )
                            .padding(.horizontal)
                    }
                }
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.section)
            }
        }
        .navigationTitle("Edit Contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    HapticManager.cancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    HapticManager.tap()
                    savePerson()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasChanges)
                .foregroundColor(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasChanges
                        ? AppColors.disabled : AppColors.accent
                )
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            HapticManager.prepare()
        }
    }

    private var editingInitials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count >= 2 {
            return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
        } else if let first = words.first, first.count >= 2 {
            return String(first.prefix(2)).uppercased()
        } else {
            return String(trimmed.prefix(1)).uppercased()
        }
    }

    private func checkDuplicatePhone(_ phone: String) {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showingDuplicateWarning = false
            return
        }

        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "phoneNumber == %@ AND id != %@",
            trimmed,
            (person.id ?? UUID()) as CVarArg
        )
        fetchRequest.fetchLimit = 1

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let existing = results.first {
                duplicatePersonName = existing.name ?? "another person"
                showingDuplicateWarning = true
            } else {
                showingDuplicateWarning = false
            }
        } catch {
            AppLogger.coreData.error("Failed to check duplicate phone: \(error.localizedDescription)")
            showingDuplicateWarning = false
        }
    }

    private func savePerson() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            HapticManager.error()
            return
        }

        person.name = trimmedName
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        person.phoneNumber = trimmedPhone.isEmpty ? nil : trimmedPhone
        person.colorHex = colorHex

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to save changes. Please try again."
            showingError = true
        }
    }
}
