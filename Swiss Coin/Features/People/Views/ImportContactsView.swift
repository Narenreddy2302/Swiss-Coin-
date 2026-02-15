import Contacts
import CoreData
import os
import SwiftUI

struct ImportContactsView: View {
    @StateObject private var contactsManager = ContactsManager()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedContacts: Set<ContactsManager.PhoneContact> = []
    @State private var searchText = ""
    @State private var existingPhoneNumbers: Set<String> = []

    var onImport: (([Person]) -> Void)?

    var filteredContacts: [ContactsManager.PhoneContact] {
        if searchText.isEmpty {
            return contactsManager.contacts
        } else {
            return contactsManager.contacts.filter {
                $0.fullName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if contactsManager.authorizationStatus == .authorized {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredContacts.enumerated()), id: \.element.id) { index, contact in
                                let isAlreadyAdded = contactAlreadyExists(contact)
                                Button(action: {
                                    guard !isAlreadyAdded else { return }
                                    HapticManager.selectionChanged()
                                    toggleSelection(contact)
                                }) {
                                    HStack(spacing: Spacing.md) {
                                        if let data = contact.thumbnailImageData,
                                            let uiImage = UIImage(data: data)
                                        {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(AppColors.textSecondary.opacity(0.3))
                                                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                                .overlay(
                                                    Text(contact.initials)
                                                        .font(AppTypography.caption())
                                                        .foregroundColor(AppColors.textPrimary)
                                                )
                                        }

                                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                                            Text(contact.fullName)
                                                .font(AppTypography.bodyLarge())
                                                .foregroundColor(isAlreadyAdded ? AppColors.textSecondary : AppColors.textPrimary)
                                            if let phone = contact.phoneNumbers.first {
                                                Text(phone)
                                                    .font(AppTypography.caption())
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                            if isAlreadyAdded {
                                                Text("Already added")
                                                    .font(AppTypography.caption())
                                                    .foregroundColor(AppColors.warning)
                                            }
                                        }

                                        Spacer()

                                        if isAlreadyAdded {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: IconSize.md))
                                                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                                        } else {
                                            Image(systemName: selectedContacts.contains(contact) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: IconSize.md))
                                                .foregroundColor(selectedContacts.contains(contact) ? AppColors.accent : AppColors.textSecondary)
                                        }
                                    }
                                    .padding(.horizontal, Spacing.lg)
                                    .padding(.vertical, Spacing.sm)
                                    .opacity(isAlreadyAdded ? 0.6 : 1.0)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isAlreadyAdded)
                                .background(AppColors.background)
                                
                                if index < filteredContacts.count - 1 {
                                    Divider()
                                        .padding(.leading, AvatarSize.sm + Spacing.md + Spacing.lg)
                                }
                            }
                        }
                    }
                    .background(AppColors.backgroundSecondary)
                    .searchable(text: $searchText)
                } else if contactsManager.authorizationStatus == .denied {
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: IconSize.xxl))
                            .foregroundColor(AppColors.warning)
                        Text("Access Denied")
                            .font(AppTypography.displayMedium())
                            .foregroundColor(AppColors.textPrimary)
                        Text("Please enable contact access in Settings to import people.")
                            .font(AppTypography.bodyDefault())
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppColors.textSecondary)
                        Button("Open Settings") {
                            HapticManager.tap()
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(Spacing.xxl)
                } else {
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: IconSize.xxl))
                            .foregroundColor(AppColors.accent)
                        Text("Import Contacts")
                            .font(AppTypography.displayMedium())
                            .foregroundColor(AppColors.textPrimary)
                        Text("Connect your address book to easily split bills with friends.")
                            .font(AppTypography.bodyDefault())
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppColors.textSecondary)
                        Button("Continue") {
                            HapticManager.tap()
                            Task {
                                await contactsManager.requestAccess()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(Spacing.xxl)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Import Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.tap()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.selectionChanged()
                        toggleSelectAll()
                    }) {
                        Text(areAllSelected ? "Deselect All" : "Select All")
                            .font(AppTypography.bodyDefault())
                            .foregroundColor(AppColors.accent)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import (\(selectedContacts.count))") {
                        HapticManager.tap()
                        importContacts()
                    }
                    .disabled(selectedContacts.isEmpty)
                    .foregroundColor(selectedContacts.isEmpty ? AppColors.disabled : AppColors.accent)
                }
            }
        }
        .task {
            // Load existing phone numbers to detect duplicates
            loadExistingPhoneNumbers()
            // Re-check status on appear in case user came back from settings
            if contactsManager.authorizationStatus == .authorized {
                await contactsManager.fetchContacts()
            }
        }
    }

    // Check if all CURRENTLY filtered contacts are selected
    var areAllSelected: Bool {
        guard !filteredContacts.isEmpty else { return false }
        // We check if the set of filtered contacts is a subset of selectedContacts
        return filteredContacts.allSatisfy { selectedContacts.contains($0) }
    }

    private func toggleSelectAll() {
        if areAllSelected {
            // Deselect all visible
            for contact in filteredContacts {
                selectedContacts.remove(contact)
            }
        } else {
            // Select all visible
            for contact in filteredContacts {
                selectedContacts.insert(contact)
            }
        }
    }

    private func loadExistingPhoneNumbers() {
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "phoneNumber != nil AND phoneNumber != %@", "")
        fetchRequest.propertiesToFetch = ["phoneNumber"]

        do {
            let results = try viewContext.fetch(fetchRequest)
            let phones = results.compactMap { $0.phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            existingPhoneNumbers = Set(phones)
        } catch {
            AppLogger.contacts.error("Failed to fetch existing phone numbers: \(error.localizedDescription)")
        }
    }

    private func contactAlreadyExists(_ contact: ContactsManager.PhoneContact) -> Bool {
        for phone in contact.phoneNumbers {
            let cleaned = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            if existingPhoneNumbers.contains(cleaned) {
                return true
            }
        }
        return false
    }

    private func toggleSelection(_ contact: ContactsManager.PhoneContact) {
        if selectedContacts.contains(contact) {
            selectedContacts.remove(contact)
        } else {
            selectedContacts.insert(contact)
        }
    }

    private func importContacts() {
        var newPeople: [Person] = []

        for contact in selectedContacts {
            // Skip contacts that already exist (safety check)
            if contactAlreadyExists(contact) {
                continue
            }

            let newPerson = Person(context: viewContext)
            newPerson.id = UUID()
            newPerson.name = contact.fullName
            newPerson.phoneNumber = contact.phoneNumbers.first

            // Assign random color - ensure proper 6-digit format
            let randomColor = Int.random(in: 0...0xFFFFFF)
            newPerson.colorHex = String(format: "#%06X", randomColor)

            newPeople.append(newPerson)
        }

        do {
            try viewContext.save()
            HapticManager.success()
            onImport?(newPeople)
            dismiss()
        } catch {
            viewContext.rollback()
            AppLogger.coreData.error("Failed to save imported contacts: \(error.localizedDescription)")
            HapticManager.error()
        }
    }
}
