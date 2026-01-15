import Contacts
import CoreData
import SwiftUI

struct AddGroupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var contactsManager = ContactsManager()

    @State private var groupName: String = ""
    @State private var searchText = ""
    @State private var selectedContacts: Set<ContactsManager.PhoneContact> = []
    @State private var showingError = false
    @State private var errorMessage = ""

    /// Generate a valid 6-character hex color code
    private static func randomColorHex() -> String {
        String(format: "#%06X", Int.random(in: 0...0xFFFFFF))
    }

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
        VStack(spacing: 0) {
            // Group Name Input
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Group Name")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.lg)

                TextField("Enter group name", text: $groupName)
                    .font(AppTypography.body())
                    .padding(Spacing.md)
                    .background(AppColors.backgroundTertiary)
                    .cornerRadius(CornerRadius.sm)
                    .padding(.horizontal, Spacing.lg)
            }
            .padding(.top, Spacing.lg)

            // Selected Members Preview
            if !selectedContacts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(Array(selectedContacts), id: \.id) { contact in
                            VStack(spacing: Spacing.xs) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.accent.opacity(0.2))
                                        .frame(width: AvatarSize.md, height: AvatarSize.md)
                                    Text(contact.initials)
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.accent)
                                }

                                Text(contact.firstName)
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                            }
                            .onTapGesture {
                                HapticManager.selectionChanged()
                                selectedContacts.remove(contact)
                            }
                        }
                    }
                    .padding(Spacing.lg)
                }
                .background(AppColors.backgroundSecondary)
            }

            // Contact List
            List {
                if contactsManager.authorizationStatus == .authorized {
                    Section(header: Text("Add Members").font(AppTypography.subheadlineMedium())) {
                        ForEach(filteredContacts) { contact in
                            Button(action: {
                                HapticManager.selectionChanged()
                                toggleSelection(for: contact)
                            }) {
                                HStack(spacing: Spacing.md) {
                                    // Avatar Logic
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

                                    Text(contact.fullName)
                                        .font(AppTypography.body())
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()

                                    Image(systemName: selectedContacts.contains(contact) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(selectedContacts.contains(contact) ? AppColors.accent : AppColors.textSecondary)
                                }
                            }
                        }
                    }
                } else {
                    // Permission Request
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: IconSize.xxl))
                            .foregroundColor(AppColors.textSecondary)

                        Text("Contact Access Required")
                            .font(AppTypography.headline())
                            .foregroundColor(AppColors.textPrimary)

                        Text("Grant access to your contacts to add members to this group.")
                            .font(AppTypography.subheadline())
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)

                        Button {
                            HapticManager.buttonPress()
                            Task { await contactsManager.requestAccess() }
                        } label: {
                            Text("Grant Access")
                                .font(AppTypography.bodyBold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: ButtonHeight.md)
                                .background(AppColors.accent)
                                .cornerRadius(CornerRadius.md)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Spacing.xxl)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundSecondary)
            .searchable(text: $searchText, prompt: "Search contacts")
        }
        .background(AppColors.backgroundSecondary)
        .navigationTitle("New Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    HapticManager.cancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    HapticManager.buttonPress()
                    createGroup()
                }
                .disabled(groupName.isEmpty || selectedContacts.isEmpty)
                .foregroundColor(groupName.isEmpty || selectedContacts.isEmpty ? AppColors.disabled : AppColors.accent)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            HapticManager.prepare()
            if contactsManager.authorizationStatus == .authorized {
                await contactsManager.fetchContacts()
            }
        }
    }

    private func toggleSelection(for contact: ContactsManager.PhoneContact) {
        if selectedContacts.contains(contact) {
            selectedContacts.remove(contact)
        } else {
            selectedContacts.insert(contact)
        }
    }

    private func createGroup() {
        let newGroup = UserGroup(context: viewContext)
        newGroup.id = UUID()
        newGroup.name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        newGroup.createdDate = Date()
        newGroup.colorHex = Self.randomColorHex()

        // Add current user to the group
        let currentUser = CurrentUser.getOrCreate(in: viewContext)
        newGroup.addToMembers(currentUser)

        for contact in selectedContacts {
            // Find or Create Person Logic
            let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", contact.fullName)
            fetchRequest.fetchLimit = 1

            do {
                let results = try viewContext.fetch(fetchRequest)
                let person: Person
                if let existing = results.first {
                    person = existing
                } else {
                    person = Person(context: viewContext)
                    person.id = UUID()
                    person.name = contact.fullName
                    person.phoneNumber = contact.phoneNumbers.first
                    person.colorHex = Self.randomColorHex()
                }
                newGroup.addToMembers(person)
            } catch {
                print("Error finding/creating person: \(error)")
            }
        }

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to create group. Please try again."
            showingError = true
        }
    }
}
