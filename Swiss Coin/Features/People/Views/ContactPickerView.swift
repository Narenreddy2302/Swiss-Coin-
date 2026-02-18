import Contacts
import ContactsUI
import CoreData
import os
import SwiftUI

/// WhatsApp-style contact picker that shows phone contacts with already-added indicators
/// When a contact is tapped, it auto-saves and navigates directly to their conversation
struct ContactPickerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var contactsManager = ContactsManager()
    @State private var searchText = ""
    @State private var existingPhoneNumbers: Set<String> = []
    @State private var existingContactIds: Set<String> = []
    @State private var isLoading = true
    @State private var isSaving = false
    
    // Navigation state for auto-navigation to conversation
    @State private var newlyCreatedPerson: Person?
    @State private var existingPerson: Person?
    
    var onContactAdded: ((Person) -> Void)?
    
    var filteredContacts: [ContactsManager.PhoneContact] {
        if searchText.isEmpty {
            return contactsManager.contacts
        } else {
            return contactsManager.contacts.filter {
                $0.fullName.localizedCaseInsensitiveContains(searchText) ||
                $0.phoneNumbers.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary.ignoresSafeArea()
                
                Group {
                    switch contactsManager.authorizationStatus {
                    case .authorized, .limited:
                        contactListView
                    case .denied:
                        accessDeniedView
                    case .restricted:
                        accessDeniedView
                    case .notDetermined:
                        requestAccessView
                    @unknown default:
                        requestAccessView
                    }
                }
            }
            .navigationTitle("New Contact")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.tap()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.tap()
                        showingManualEntry()
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Add person manually")
                    .disabled(contactsManager.authorizationStatus != .authorized)
                }
            }
            .searchable(text: $searchText, prompt: "Search contacts")
            // Navigation to conversation view for newly created contact
            .navigationDestination(item: $newlyCreatedPerson) { person in
                PersonConversationView(person: person)
                    .navigationBarBackButtonHidden(false)
            }
            // Navigation to conversation view for existing contact
            .navigationDestination(item: $existingPerson) { person in
                PersonConversationView(person: person)
                    .navigationBarBackButtonHidden(false)
            }
        }
        .task {
            await loadExistingContacts()
            if contactsManager.authorizationStatus == .authorized {
                await contactsManager.fetchContacts()
            }
            isLoading = false
        }
        .overlay {
            if isSaving {
                ZStack {
                    AppColors.scrim.opacity(AppColors.scrimOpacityHeavy)
                        .ignoresSafeArea()
                    
                    VStack(spacing: Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Adding contact...")
                            .font(AppTypography.bodyDefault())
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(AppColors.cardBackground)
                    )
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var contactListView: some View {
        Group {
            if isLoading {
                loadingView
            } else if contactsManager.contacts.isEmpty {
                emptyContactsView
            } else {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        contactsSection
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.section + Spacing.sm)
                }
            }
        }
    }

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Phone Contacts")
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("\(filteredContacts.count)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(AppColors.backgroundTertiary)
                    )
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)

            // Contact rows
            if filteredContacts.isEmpty {
                // Search empty state
                VStack(spacing: Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: IconSize.xl))
                        .foregroundColor(AppColors.textTertiary)
                    Text("No contacts match your search")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxxl)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(AppColors.cardBackground)
                        .shadow(color: AppColors.shadowSubtle, radius: 8, x: 0, y: 2)
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredContacts) { contact in
                        let isExisting = contactAlreadyExists(contact)
                        ContactRowView(
                            contact: contact,
                            isExisting: isExisting,
                            onAdd: isExisting ? nil : {
                                handleContactTap(contact)
                            }
                        )
                        .onTapGesture {
                            handleContactTap(contact)
                        }

                        if contact.id != filteredContacts.last?.id {
                            Divider()
                                .padding(.leading, Spacing.lg)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(AppColors.cardBackground)
                        .shadow(color: AppColors.shadowSubtle, radius: 8, x: 0, y: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading contacts...")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private var emptyContactsView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "person.2.slash")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary)
            
            Text("No Contacts Found")
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textPrimary)
            
            Text("Your phone contacts will appear here")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                HapticManager.tap()
                showingManualEntry()
            } label: {
                Text("Add Contact Manually")
                    .font(AppTypography.buttonDefault())
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, Spacing.lg)
        }
        .padding(Spacing.xxl)
    }
    
    private var requestAccessView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            
            Image(systemName: "person.2.circle")
                .font(.system(size: AvatarSize.xl))
                .foregroundColor(AppColors.accent)
            
            Text("Access Your Contacts")
                .font(AppTypography.displayMedium())
                .foregroundColor(AppColors.textPrimary)
            
            Text("Allow access to your phone contacts to easily add people you know.")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            
            VStack(spacing: Spacing.md) {
                Button {
                    HapticManager.tap()
                    Task {
                        let granted = await contactsManager.requestAccess()
                        if granted {
                            await loadExistingContacts()
                        }
                    }
                } label: {
                    Text("Allow Access")
                        .font(AppTypography.buttonDefault())
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    HapticManager.tap()
                    showingManualEntry()
                } label: {
                    Text("Add Manually")
                        .font(AppTypography.buttonDefault())
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, Spacing.lg)

            Spacer()
        }
        .padding(Spacing.xxl)
    }

    private var accessDeniedView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: AvatarSize.xl))
                .foregroundColor(AppColors.warning)
            
            Text("Access Denied")
                .font(AppTypography.displayMedium())
                .foregroundColor(AppColors.textPrimary)
            
            Text("Please enable contact access in Settings to import people from your phone.")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            
            VStack(spacing: Spacing.md) {
                Button {
                    HapticManager.tap()
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(AppTypography.buttonDefault())
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    HapticManager.tap()
                    showingManualEntry()
                } label: {
                    Text("Add Manually")
                        .font(AppTypography.buttonDefault())
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, Spacing.lg)
            
            Spacer()
        }
        .padding(Spacing.xxl)
    }
    
    // MARK: - Helper Methods
    
    private func loadExistingContacts() async {
        loadExistingPhoneNumbers()
    }
    
    private func loadExistingPhoneNumbers() {
        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "phoneNumber != nil AND phoneNumber != %@", "")
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            var phones: Set<String> = []
            let ids: Set<String> = []
            
            for person in results {
                if let phone = person.phoneNumber {
                    // Store normalized versions
                    phones.insert(phone.normalizedPhoneNumber())
                    phones.insert(phone) // Also store original
                }
            }
            
            existingPhoneNumbers = phones
            existingContactIds = ids
        } catch {
            AppLogger.contacts.error("Failed to fetch existing contacts: \(error.localizedDescription)")
        }
    }
    
    private func contactAlreadyExists(_ contact: ContactsManager.PhoneContact) -> Bool {
        for phone in contact.phoneNumbers {
            let normalized = phone.normalizedPhoneNumber()
            if existingPhoneNumbers.contains(normalized) || existingPhoneNumbers.contains(phone) {
                return true
            }
        }
        return false
    }
    
    /// Find existing person by phone number
    private func findExistingPerson(for contact: ContactsManager.PhoneContact) -> Person? {
        for phone in contact.phoneNumbers {
            let normalized = phone.normalizedPhoneNumber()
            
            let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "phoneNumber == %@ OR phoneNumber == %@",
                normalized, phone
            )
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try viewContext.fetch(fetchRequest)
                if let person = results.first {
                    return person
                }
            } catch {
                AppLogger.contacts.error("Failed to find existing person: \(error.localizedDescription)")
            }
        }
        return nil
    }
    
    /// Handle contact tap - auto-save new contacts or navigate to existing
    private func handleContactTap(_ contact: ContactsManager.PhoneContact) {
        HapticManager.tap()
        
        // If contact already exists, navigate directly to their conversation
        if let existingPerson = findExistingPerson(for: contact) {
            HapticManager.selectionChanged()
            if let callback = onContactAdded {
                callback(existingPerson)
                dismiss()
            } else {
                self.existingPerson = existingPerson
            }
            return
        }
        
        // Otherwise, auto-save the new contact
        autoSaveContact(contact)
    }
    
    /// Auto-save contact and navigate to conversation (WhatsApp-style)
    private func autoSaveContact(_ contact: ContactsManager.PhoneContact) {
        guard !isSaving else { return }
        isSaving = true
        
        let trimmedName = contact.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = contact.phoneNumbers.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Final duplicate check before saving
        if !trimmedPhone.isEmpty {
            let normalizedPhone = trimmedPhone.normalizedPhoneNumber()
            let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "phoneNumber == %@ OR phoneNumber == %@",
                trimmedPhone, normalizedPhone
            )
            
            do {
                let existing = try viewContext.fetch(fetchRequest)
                if let person = existing.first {
                    // Contact was added while we were checking - navigate to them
                    isSaving = false
                    self.existingPerson = person
                    return
                }
            } catch {
                AppLogger.contacts.error("Failed to check duplicates: \(error.localizedDescription)")
            }
        }
        
        let newPerson = Person(context: viewContext)
        newPerson.id = UUID()
        newPerson.name = trimmedName
        newPerson.phoneNumber = trimmedPhone.isEmpty ? nil : trimmedPhone
        
        // Assign a random color hex for avatar
        let randomColor = Int.random(in: 0...0xFFFFFF)
        newPerson.colorHex = String(format: "#%06X", randomColor)
        
        // Save photo if available
        if let photoData = contact.thumbnailImageData {
            newPerson.photoData = photoData
        }
        
        do {
            try viewContext.save()
            HapticManager.success()
            
            // Update existing phone numbers set
            if !trimmedPhone.isEmpty {
                existingPhoneNumbers.insert(trimmedPhone)
                existingPhoneNumbers.insert(trimmedPhone.normalizedPhoneNumber())
            }
            
            isSaving = false

            if let callback = onContactAdded {
                callback(newPerson)
                dismiss()
            } else {
                self.newlyCreatedPerson = newPerson
            }
            
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.contacts.error("Failed to save person: \(error.localizedDescription)")
            isSaving = false
        }
    }
    
    private func showingManualEntry() {
        // Dismiss this sheet and show manual entry - handled by parent
        dismiss()
        // Post notification to show manual entry after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .showManualContactEntry, object: nil)
        }
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    let contact: ContactsManager.PhoneContact
    let isExisting: Bool
    var onAdd: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            if let data = contact.thumbnailImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: AvatarSize.md, height: AvatarSize.md)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(isExisting ? AppColors.textSecondary.opacity(0.2) : AppColors.accent.opacity(0.2))
                    .frame(width: AvatarSize.md, height: AvatarSize.md)
                    .overlay(
                        Text(contact.initials)
                            .font(AppTypography.headingMedium())
                            .foregroundColor(isExisting ? AppColors.textSecondary : AppColors.accent)
                    )
            }

            // Info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(contact.fullName)
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(isExisting ? AppColors.textSecondary : AppColors.textPrimary)
                    .lineLimit(1)

                if let phone = contact.phoneNumbers.first {
                    Text(phone)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            // Plus button for non-existing contacts only
            if !isExisting, let onAdd {
                Button {
                    HapticManager.tap()
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: IconSize.lg))
                        .foregroundColor(AppColors.accent)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Add \(contact.fullName)")
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
        .opacity(isExisting ? 0.6 : 1.0)
    }
}

// MARK: - Extensions

extension Notification.Name {
    static let showManualContactEntry = Notification.Name("showManualContactEntry")
    static let contactAddedSuccessfully = Notification.Name("contactAddedSuccessfully")
}

// MARK: - Phone Number Normalization

extension String {
    /// Normalizes phone number for duplicate comparison
    /// Removes all non-digit characters and handles country code variations
    func normalizedPhoneNumber() -> String {
        let digits = self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Handle Swiss number variations
        // +41 79 XXX XX XX -> 4179XXXXXXX
        // 079 XXX XX XX -> 4179XXXXXXX
        // 79 XXX XX XX -> 4179XXXXXXX
        
        if digits.hasPrefix("0") && digits.count == 10 {
            // Convert 0XX... to 41XX...
            return "41" + String(digits.dropFirst())
        } else if !digits.hasPrefix("0") && !digits.hasPrefix("1") && digits.count == 9 {
            // Convert XX... (without leading 0) to 41XX...
            return "41" + digits
        }
        
        return digits
    }
}
