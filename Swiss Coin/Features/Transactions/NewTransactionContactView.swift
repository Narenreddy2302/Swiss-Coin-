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
            ZStack {
                AppColors.backgroundSecondary
                    .ignoresSafeArea()

                if contactsManager.authorizationStatus == .authorized {
                    authorizedContent
                } else if contactsManager.authorizationStatus == .denied {
                    deniedContent
                } else {
                    pendingContent
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
            .navigationDestination(isPresented: $navigateToAddTransaction) {
                if let person = selectedPersonForTransaction {
                    PersonDetailView(person: person)
                }
            }
        }
        .searchable(
            text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .task {
            if contactsManager.authorizationStatus == .authorized {
                await contactsManager.fetchContacts()
            }
        }
    }

    // MARK: - Authorized Content

    private var authorizedContent: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                quickActionsSection
                contactsSection
            }
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.section)
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("QUICK ACTIONS")
                .font(AppTypography.footnote())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                NavigationLink(destination: AddGroupView()) {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(AppColors.accent)
                            .frame(width: AvatarSize.md, height: AvatarSize.md)
                            .background(AppColors.accent.opacity(0.1))
                            .clipShape(Circle())
                        Text("New Group")
                            .font(AppTypography.headline())
                            .foregroundColor(AppColors.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: IconSize.xs, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.lg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                Divider()
                    .padding(.leading, AvatarSize.md + Spacing.md + Spacing.lg)

                NavigationLink(destination: AddPersonView()) {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "person.fill.badge.plus")
                            .foregroundColor(AppColors.accent)
                            .frame(width: AvatarSize.md, height: AvatarSize.md)
                            .background(AppColors.accent.opacity(0.1))
                            .clipShape(Circle())
                        Text("New Contact")
                            .font(AppTypography.headline())
                            .foregroundColor(AppColors.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: IconSize.xs, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.lg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(AppColors.cardBackground)
        }
    }

    // MARK: - Contacts Section

    private var contactsSection: some View {
        Group {
            if !filteredContacts.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        Text("CONTACTS")
                            .font(AppTypography.footnote())
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        Text("\(filteredContacts.count)")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xxs)
                            .background(
                                Capsule()
                                    .fill(AppColors.surface)
                            )
                    }
                    .padding(.horizontal, Spacing.lg)

                    LazyVStack(spacing: 0) {
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
                                        Circle()
                                            .fill(AppColors.accent.opacity(0.15))
                                            .frame(width: AvatarSize.md, height: AvatarSize.md)
                                            .overlay(
                                                Text(contact.initials)
                                                    .font(AppTypography.headline())
                                                    .foregroundColor(AppColors.accent)
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        Text(contact.fullName)
                                            .font(AppTypography.body())
                                            .foregroundColor(AppColors.textPrimary)
                                            .lineLimit(1)
                                        if let phone = contact.phoneNumbers.first {
                                            Text(phone)
                                                .font(AppTypography.caption())
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: IconSize.xs, weight: .semibold))
                                        .foregroundColor(AppColors.textTertiary)
                                }
                                .padding(.vertical, Spacing.md)
                                .padding(.horizontal, Spacing.lg)
                                .contentShape(Rectangle())
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
                    .background(AppColors.cardBackground)
                }
            } else if !searchText.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Spacer()
                        .frame(height: Spacing.section)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: IconSize.xxl))
                        .foregroundColor(AppColors.textSecondary)
                        .accessibilityHidden(true)

                    Text("No Results")
                        .font(AppTypography.title2())
                        .foregroundColor(AppColors.textPrimary)

                    Text("No contacts matching \"\(searchText)\"")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxl)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Denied Content

    private var deniedContent: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.warning)
                .accessibilityHidden(true)

            Text("Access Denied")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)

            Text("Please enable contact access in Settings\nto see your contacts here.")
                .font(AppTypography.subheadline())
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.xxl)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Spacing.xxl)
            .padding(.top, Spacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pending Content

    private var pendingContent: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "person.2.circle")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.accent)
                .accessibilityHidden(true)

            Text("Load Contacts")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)

            Text("Allow access to your contacts to quickly\nadd transactions with people you know.")
                .font(AppTypography.subheadline())
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.xxl)

            Button("Continue") {
                Task {
                    await contactsManager.requestAccess()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Spacing.xxl)
            .padding(.top, Spacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

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
