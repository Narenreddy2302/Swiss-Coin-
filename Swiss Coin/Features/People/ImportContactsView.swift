import Contacts
import CoreData
import SwiftUI

struct ImportContactsView: View {
    @StateObject private var contactsManager = ContactsManager()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedContacts: Set<ContactsManager.PhoneContact> = []
    @State private var searchText = ""

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
        NavigationView {
            VStack {
                if contactsManager.authorizationStatus == .authorized {
                    List {
                        ForEach(filteredContacts) { contact in
                            Button(action: {
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

                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        Text(contact.fullName)
                                            .font(AppTypography.headline())
                                            .foregroundColor(AppColors.textPrimary)
                                        if let phone = contact.phoneNumbers.first {
                                            Text(phone)
                                                .font(AppTypography.caption())
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: selectedContacts.contains(contact) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: IconSize.md))
                                        .foregroundColor(selectedContacts.contains(contact) ? AppColors.accent : AppColors.textSecondary)
                                }
                                .padding(.vertical, Spacing.xs)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText)
                } else if contactsManager.authorizationStatus == .denied {
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: IconSize.xxl))
                            .foregroundColor(AppColors.warning)
                        Text("Access Denied")
                            .font(AppTypography.title2())
                            .foregroundColor(AppColors.textPrimary)
                        Text("Please enable contact access in Settings to import people.")
                            .font(AppTypography.subheadline())
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
                            .font(AppTypography.title2())
                            .foregroundColor(AppColors.textPrimary)
                        Text("Connect your address book to easily split bills with friends.")
                            .font(AppTypography.subheadline())
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
                            .font(AppTypography.subheadline())
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
            print("Error saving imported contacts: \(error)")
            HapticManager.error()
            // TODO: Show error alert to user
        }
    }
}
