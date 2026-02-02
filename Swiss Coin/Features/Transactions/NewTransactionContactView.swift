import Contacts
import CoreData
import os
import SwiftUI

struct NewTransactionContactView: View {
    @StateObject private var contactsManager = ContactsManager()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var searchText = ""
    @State private var selectedPersonForTransaction: Person?
    @State private var navigateToAddTransaction = false

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
                    List {
                        // WhatsApp Style Header Rows
                        Section {
                            NavigationLink(destination: AddGroupView()) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: AvatarSize.md, height: AvatarSize.md)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())
                                    Text("New Group")
                                        .font(AppTypography.headline())
                                        .foregroundColor(.blue)
                                }
                            }

                            NavigationLink(destination: AddPersonView()) {
                                HStack {
                                    Image(systemName: "person.fill.badge.plus")
                                        .foregroundColor(.blue)
                                        .frame(width: AvatarSize.md, height: AvatarSize.md)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())
                                    Text("New Contact")
                                        .font(AppTypography.headline())
                                        .foregroundColor(.blue)
                                }
                            }
                        }

                        // Contacts List - Clean, borderless style
                        ForEach(Array(filteredContacts.enumerated()), id: \.element.id) { index, contact in
                            Button(action: {
                                selectContact(contact)
                            }) {
                                HStack(spacing: Spacing.md) {
                                    if let data = contact.thumbnailImageData,
                                        let uiImage = UIImage(data: data)
                                    {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: AvatarSize.md, height: AvatarSize.md)
                                            .clipShape(Circle())
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(AppColors.backgroundSecondary)
                                            Text(contact.initials)
                                                .font(AppTypography.caption())
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                        .frame(width: AvatarSize.md, height: AvatarSize.md)
                                    }

                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text(contact.fullName)
                                            .font(AppTypography.body())
                                            .foregroundColor(AppColors.textPrimary)
                                        if let phone = contact.phoneNumbers.first {
                                            Text(phone)
                                                .font(AppTypography.caption())
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, Spacing.xs)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.selectionChanged()
                            })
                            
                            if index < filteredContacts.count - 1 {
                                Divider()
                                    .padding(.leading, AvatarSize.md + Spacing.md + Spacing.lg)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(
                        text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
                } else if contactsManager.authorizationStatus == .denied {
                    VStack(spacing: Spacing.xl) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: IconSize.xxl))
                            .foregroundColor(AppColors.warning)
                        Text("Access Denied")
                            .font(AppTypography.title2())
                        Text("Please enable contact access in Settings.")
                            .font(AppTypography.subheadline())
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppColors.textSecondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: Spacing.xl) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: IconSize.xxl))
                            .foregroundColor(.blue)
                        Text("Load Contacts")
                            .font(AppTypography.title2())
                        Button("Continue") {
                            Task {
                                await contactsManager.requestAccess()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Message")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }

            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationDestination(isPresented: $navigateToAddTransaction) {
                if let person = selectedPersonForTransaction {
                    PersonDetailView(person: person)
                }
            }
        }
        .task {
            if contactsManager.authorizationStatus == .authorized {
                await contactsManager.fetchContacts()
            }
        }
    }

    private func selectContact(_ contact: ContactsManager.PhoneContact) {
        // 1. Check if Person exists by phone number first, then by name
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        
        // Prefer phone number matching if available
        if let phoneNumber = contact.phoneNumbers.first {
            fetchRequest.predicate = NSPredicate(format: "phoneNumber == %@", phoneNumber)
        } else {
            fetchRequest.predicate = NSPredicate(format: "name == %@", contact.fullName)
        }
        fetchRequest.fetchLimit = 1

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let existingPerson = results.first {
                self.selectedPersonForTransaction = existingPerson
                HapticManager.selectionChanged()
            } else {
                // 2. Create new Person
                let newPerson = Person(context: viewContext)
                newPerson.id = UUID()
                newPerson.name = contact.fullName
                newPerson.phoneNumber = contact.phoneNumbers.first
                
                // Generate a nice random color hex
                let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FECA57", "#FF9FF3", "#54A0FF", "#5F27CD"]
                newPerson.colorHex = colors.randomElement() ?? "#4ECDC4"

                try viewContext.save()
                self.selectedPersonForTransaction = newPerson
                HapticManager.success()
            }
            // 3. Navigate
            self.navigateToAddTransaction = true
        } catch {
            AppLogger.contacts.error("Failed to select contact: \(error.localizedDescription)")
            HapticManager.error()
        }
    }
}
