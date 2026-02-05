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
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Adding contact...")
                            .font(AppTypography.subheadline())
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
                List {
                    // Manual entry option at top
                    Section {
                        Button {
                            HapticManager.tap()
                            showingManualEntry()
                        } label: {
                            HStack(spacing: Spacing.md) {
                                Image(systemName: "person.fill.badge.plus")
                                    .font(.system(size: IconSize.md))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: AvatarSize.md, height: AvatarSize.md)
                                
                                Text("Add Manually")
                                    .font(AppTypography.body())
                                    .foregroundColor(AppColors.accent)
                                
                                Spacer()
                            }
                        }
                    }
                    
                    // Contacts list
                    Section(header: Text("From Phone Contacts")) {
                        ForEach(filteredContacts) { contact in
                            ContactRowView(
                                contact: contact,
                                isExisting: contactAlreadyExists(contact)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleContactTap(contact)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading contacts...")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private var emptyContactsView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "person.2.slash")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary)
            
            Text("No Contacts Found")
                .font(AppTypography.title3())
                .foregroundColor(AppColors.textPrimary)
            
            Text("Your phone contacts will appear here")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                HapticManager.tap()
                showingManualEntry()
            } label: {
                Text("Add Contact Manually")
                    .font(AppTypography.bodyBold())
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
                .font(.system(size: 80))
                .foregroundColor(AppColors.accent)
            
            Text("Access Your Contacts")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)
            
            Text("Allow access to your phone contacts to easily add people you know.")
                .font(AppTypography.subheadline())
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
                        .font(AppTypography.bodyBold())
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button {
                    HapticManager.tap()
                    showingManualEntry()
                } label: {
                    Text("Add Manually")
                        .font(AppTypography.body())
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
                .font(.system(size: 80))
                .foregroundColor(AppColors.warning)
            
            Text("Access Denied")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)
            
            Text("Please enable contact access in Settings to import people from your phone.")
                .font(AppTypography.subheadline())
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
                        .font(AppTypography.bodyBold())
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button {
                    HapticManager.tap()
                    showingManualEntry()
                } label: {
                    Text("Add Manually")
                        .font(AppTypography.body())
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
            self.existingPerson = existingPerson
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
            
            // Notify parent
            onContactAdded?(newPerson)
            
            // Navigate to conversation
            isSaving = false
            self.newlyCreatedPerson = newPerson
            
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
                            .font(AppTypography.headline())
                            .foregroundColor(isExisting ? AppColors.textSecondary : AppColors.accent)
                    )
            }
            
            // Info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(contact.fullName)
                    .font(AppTypography.body())
                    .foregroundColor(isExisting ? AppColors.textSecondary : AppColors.textPrimary)
                    .lineLimit(1)
                
                if let phone = contact.phoneNumbers.first {
                    Text(phone)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            if isExisting {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(AppColors.positive)
                    Text("Added")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.positive)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: IconSize.sm))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, Spacing.xs)
        .opacity(isExisting ? 0.7 : 1.0)
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
