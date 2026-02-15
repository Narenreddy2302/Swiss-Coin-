import Contacts
import CoreData
import os
import SwiftUI

struct PeopleView: View {
    @State private var selectedSegment = 0
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingManualEntry = false
    @State private var showingArchivedPeople = false

    // Navigation state for conversation view after adding contact
    @State private var selectedPersonForConversation: Person?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: Spacing.md) {
                    ActionHeaderButton(
                        title: "People",
                        icon: "person.2.fill",
                        color: selectedSegment == 0 ? AppColors.accent : AppColors.textPrimary
                    ) {
                        HapticManager.selectionChanged()
                        selectedSegment = 0
                    }

                    ActionHeaderButton(
                        title: "Groups",
                        icon: "person.3.fill",
                        color: selectedSegment == 1 ? AppColors.accent : AppColors.textPrimary
                    ) {
                        HapticManager.selectionChanged()
                        selectedSegment = 1
                    }
                }
                .padding(.horizontal)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.sm)
                .background(AppColors.backgroundSecondary)

                Group {
                    if selectedSegment == 0 {
                        PersonListView(selectedPersonForConversation: $selectedPersonForConversation)
                    } else {
                        GroupListView()
                    }
                }
                .animation(AppAnimation.standard, value: selectedSegment)
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            // Navigation to conversation after contact selection
            .navigationDestination(item: $selectedPersonForConversation) { person in
                PersonConversationView(person: person)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.tap()
                        showingArchivedPeople = true
                    } label: {
                        Image(systemName: "archivebox")
                            .font(AppTypography.labelLarge())
                    }
                    .accessibilityLabel("View archived people")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if selectedSegment == 0 {
                            Button {
                                HapticManager.lightTap()
                                showingManualEntry = true
                            } label: {
                                Image(systemName: "person.badge.plus")
                                    .font(AppTypography.buttonLarge())
                            }
                            .accessibilityLabel("Add person")
                        } else {
                            NavigationLink(destination: AddGroupView()) {
                                Image(systemName: "plus")
                                    .font(AppTypography.buttonLarge())
                            }
                            .accessibilityLabel("Add group")
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.lightTap()
                            })
                        }
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                NavigationStack {
                    AddPersonView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .sheet(isPresented: $showingArchivedPeople) {
                ArchivedPeopleView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .onAppear {
                HapticManager.prepare()
                setupNotifications()
            }
            .onDisappear {
                removeNotifications()
            }
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .showManualContactEntry,
            object: nil,
            queue: .main
        ) { _ in
            showingManualEntry = true
        }
    }

    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: .showManualContactEntry, object: nil)
    }
}

// MARK: - Person List (with inline phone contacts)

struct PersonListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedPersonForConversation: Person?
    @StateObject private var contactsManager = ContactsManager()
    @State private var showRefreshFeedback = false
    @State private var existingPhoneNumbers: Set<String> = []
    @State private var searchText = ""
    @State private var filteredPhoneContacts: [ContactsManager.PhoneContact] = []
    @State private var hasLoadedContacts = false

    // People with transaction history
    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<Person> = Person.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Person.name, ascending: true)]
        if let userId = CurrentUser.currentUserId {
            request.predicate = NSPredicate(
                format: "id != %@ AND (isArchived == NO OR isArchived == nil) AND (toTransactions.@count > 0 OR owedSplits.@count > 0 OR sentSettlements.@count > 0 OR receivedSettlements.@count > 0 OR chatMessages.@count > 0)",
                userId as CVarArg
            )
        } else {
            request.predicate = NSPredicate(
                format: "(isArchived == NO OR isArchived == nil) AND (toTransactions.@count > 0 OR owedSplits.@count > 0 OR sentSettlements.@count > 0 OR receivedSettlements.@count > 0 OR chatMessages.@count > 0)"
            )
        }
        request.fetchBatchSize = 20
        return request
    }(), animation: .default)
    private var people: FetchedResults<Person>

    /// People filtered by search
    private var filteredPeople: [Person] {
        if searchText.isEmpty { return Array(people) }
        let search = searchText.lowercased()
        return people.filter { ($0.name?.lowercased().contains(search) ?? false) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // MARK: - Recent / With Balances Section
                if !filteredPeople.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text("Recent")
                                .font(AppTypography.labelLarge())
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            Text("\(filteredPeople.count)")
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

                        LazyVStack(spacing: 0) {
                            ForEach(filteredPeople, id: \.objectID) { person in
                                NavigationLink(destination: PersonConversationView(person: person)) {
                                    PersonListRowView(person: person)
                                }
                                .buttonStyle(.plain)

                                if person.objectID != filteredPeople.last?.objectID {
                                    Divider()
                                        .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                                }
                            }
                        }
                    }
                }

                // MARK: - Phone Contacts (search only)
                if !searchText.isEmpty && !filteredPhoneContacts.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text("Phone Contacts")
                                .font(AppTypography.labelLarge())
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            Text("\(filteredPhoneContacts.count)")
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

                        LazyVStack(spacing: 0) {
                            ForEach(filteredPhoneContacts) { contact in
                                Button {
                                    handlePhoneContactTap(contact)
                                } label: {
                                    PhoneContactRowView(contact: contact)
                                }
                                .buttonStyle(.plain)

                                if contact.id != filteredPhoneContacts.last?.id {
                                    Divider()
                                        .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                                }
                            }
                        }
                    }
                }

                // Contact access prompts (when not searching)
                if searchText.isEmpty {
                    if contactsManager.authorizationStatus == .notDetermined {
                        contactAccessPrompt
                    } else if contactsManager.authorizationStatus == .denied {
                        contactAccessDeniedPrompt
                    }
                }

                // Empty state
                if searchText.isEmpty && people.isEmpty {
                    PersonEmptyStateView()
                } else if !searchText.isEmpty && filteredPeople.isEmpty && filteredPhoneContacts.isEmpty {
                    noSearchResultsView
                }

                Spacer()
                    .frame(height: Spacing.section + Spacing.sm)
            }
            .padding(.top, Spacing.lg)
        }
        .searchable(text: $searchText, prompt: "Search contacts")
        .refreshable {
            await refreshAll()
        }
        .refreshFeedback(isShowing: $showRefreshFeedback)
        .task {
            existingPhoneNumbers = ContactsManager.loadExistingPhoneNumbers(in: viewContext)
        }
        .task(id: searchText) {
            guard !searchText.isEmpty else {
                filteredPhoneContacts = []
                return
            }
            // 300ms debounce — task auto-cancels on new keystroke
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            // Lazy-load phone contacts on first search
            if !hasLoadedContacts && contactsManager.authorizationStatus == .authorized {
                await contactsManager.fetchContacts()
                existingPhoneNumbers = ContactsManager.loadExistingPhoneNumbers(in: viewContext)
                hasLoadedContacts = true
            }

            guard !Task.isCancelled else { return }
            filteredPhoneContacts = contactsManager.searchContacts(
                query: searchText,
                excludingPhoneNumbers: existingPhoneNumbers
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            existingPhoneNumbers = ContactsManager.loadExistingPhoneNumbers(in: viewContext)
        }
    }

    // MARK: - Contact Access Prompt

    private var contactAccessPrompt: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "person.2.circle")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.accent)

            Text("See Your Contacts")
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textPrimary)

            Text("Allow access to see your phone contacts here and easily split expenses.")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button {
                HapticManager.tap()
                Task {
                    let granted = await contactsManager.requestAccess()
                    if granted {
                        existingPhoneNumbers = ContactsManager.loadExistingPhoneNumbers(in: viewContext)
                    }
                }
            } label: {
                Text("Allow Access")
                    .font(AppTypography.headingMedium())
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Spacing.xxl)
        }
        .padding(Spacing.xxl)
    }

    private var contactAccessDeniedPrompt: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: IconSize.xl))
                .foregroundColor(AppColors.warning)

            Text("Contact Access Denied")
                .font(AppTypography.headingMedium())
                .foregroundColor(AppColors.textPrimary)

            Text("Enable in Settings to see your contacts here.")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                HapticManager.tap()
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(Spacing.xl)
    }

    private var noSearchResultsView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: IconSize.xl))
                .foregroundColor(AppColors.textTertiary)

            Text("No results for \"\(searchText)\"")
                .font(AppTypography.headingMedium())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func handlePhoneContactTap(_ contact: ContactsManager.PhoneContact) {
        HapticManager.tap()

        // Check if a Person already exists for this contact
        if let existing = ContactsManager.findExistingPerson(for: contact, in: viewContext) {
            selectedPersonForConversation = existing
            return
        }

        // Create new Person from phone contact
        let newPerson = ContactsManager.createPerson(from: contact, in: viewContext)
        do {
            try viewContext.save()
            HapticManager.success()
            existingPhoneNumbers = ContactsManager.loadExistingPhoneNumbers(in: viewContext)
            // Remove from phone contact results since they're now a Person
            filteredPhoneContacts.removeAll { $0.id == contact.id }
            selectedPersonForConversation = newPerson
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.coreData.error("Failed to save contact: \(error.localizedDescription)")
        }
    }

    private func refreshAll() async {
        await RefreshHelper.performStandardRefresh(context: viewContext)
        existingPhoneNumbers = ContactsManager.loadExistingPhoneNumbers(in: viewContext)
        // Reset lazy-load flag so next search fetches fresh contacts
        hasLoadedContacts = false
        filteredPhoneContacts = []
        withAnimation(AppAnimation.standard) { showRefreshFeedback = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(AppAnimation.standard) { showRefreshFeedback = false }
        }
    }
}

// MARK: - Phone Contact Row View

struct PhoneContactRowView: View {
    let contact: ContactsManager.PhoneContact

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            if let data = contact.thumbnailImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                    .overlay(
                        Text(contact.initials)
                            .font(AppTypography.headingLarge())
                            .foregroundColor(AppColors.accent)
                    )
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(contact.fullName)
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                if let phone = contact.phoneNumbers.first {
                    Text(phone)
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
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
}

// MARK: - Person Empty State

struct PersonEmptyStateView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("No Contacts")
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }
}

// MARK: - Person List Row

struct PersonListRowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var person: Person
    @State private var showingProfile = false
    @State private var showingAddExpense = false
    @State private var showingReminder = false
    @State private var showingEditPerson = false
    @State private var showingDeleteConfirmation = false

    @State private var balance: Double = 0

    private var balanceText: String {
        let formatted = CurrencyFormatter.formatAbsolute(balance)

        if balance > 0.01 {
            return "owes you \(formatted)"
        } else if balance < -0.01 {
            return "you owe \(formatted)"
        } else {
            return "settled up"
        }
    }

    private var balanceTextView: Text {
        let formatted = CurrencyFormatter.formatAbsolute(balance)

        if balance > 0.01 {
            return Text("owes you ") + Text(formatted).fontWeight(.bold)
        } else if balance < -0.01 {
            return Text("you owe ") + Text(formatted).fontWeight(.bold)
        } else {
            return Text("settled up")
        }
    }

    private var balanceColor: Color {
        if balance > 0.01 {
            return AppColors.positive
        } else if balance < -0.01 {
            return AppColors.negative
        } else {
            return AppColors.neutral
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Text(person.initials)
                        .font(AppTypography.headingLarge())
                        .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(person.name ?? "Unknown")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                balanceTextView
                    .font(AppTypography.bodySmall())
                    .foregroundColor(balanceColor)
                    .lineLimit(1)
            }

            Spacer()

            if abs(balance) > 0.01 {
                Text(CurrencyFormatter.formatAbsolute(balance))
                    .font(AppTypography.financialDefault())
                    .foregroundColor(balanceColor)
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(person.name ?? "Unknown"), \(balanceText)")
        .contextMenu {
            Button {
                HapticManager.lightTap()
                showingProfile = true
            } label: {
                Label("View Profile", systemImage: "person.circle")
            }

            Button {
                HapticManager.lightTap()
                showingEditPerson = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                HapticManager.lightTap()
                showingAddExpense = true
            } label: {
                Label("Add Expense", systemImage: "plus.circle")
            }

            if balance > 0.01 {
                Button {
                    HapticManager.lightTap()
                    showingReminder = true
                } label: {
                    Label("Send Reminder", systemImage: "bell")
                }
            }

            Divider()

            Button {
                HapticManager.tap()
                archivePerson()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }

            Button(role: .destructive) {
                HapticManager.delete()
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                PersonDetailView(person: person)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingProfile = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingEditPerson) {
            NavigationStack {
                EditPersonView(person: person)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddTransactionPresenter(initialPerson: person)
        }
        .sheet(isPresented: $showingReminder) {
            ReminderSheetView(person: person, amount: balance)
        }
        .alert("Delete Person", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePerson()
            }
        } message: {
            Text("This will permanently delete \(person.name ?? "this person") and ALL their transactions, payment history, and shared expenses. Other people's balances will be affected. This action cannot be undone.")
        }
        .task {
            balance = person.calculateBalance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            balance = person.calculateBalance()
        }
    }

    private func archivePerson() {
        person.isArchived = true
        do {
            try viewContext.save()
            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.coreData.error("Failed to archive person: \(error.localizedDescription)")
        }
    }

    private func deletePerson() {
        viewContext.delete(person)
        do {
            try viewContext.save()
            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.coreData.error("Failed to delete person: \(error.localizedDescription)")
        }
    }
}

// MARK: - Group List

struct GroupListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showRefreshFeedback = false

    @FetchRequest(fetchRequest: {
        let request: NSFetchRequest<UserGroup> = UserGroup.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UserGroup.name, ascending: true)]
        request.fetchBatchSize = 20
        return request
    }(), animation: .default)
    private var groups: FetchedResults<UserGroup>

    var body: some View {
        Group {
            if groups.isEmpty {
                ScrollView {
                    GroupEmptyStateView()
                }
                .refreshable {
                    await RefreshHelper.performStandardRefresh(context: viewContext)
                }
            } else {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Section
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            // Section header
                            HStack {
                                Text("All Groups")
                                    .font(AppTypography.labelLarge())
                                    .foregroundColor(AppColors.textSecondary)

                                Spacer()

                                Text("\(groups.count)")
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

                            // Group rows
                            LazyVStack(spacing: 0) {
                                ForEach(groups) { group in
                                    NavigationLink(destination: GroupConversationView(group: group)) {
                                        GroupListRowView(group: group)
                                    }
                                    .buttonStyle(.plain)

                                    if group.objectID != groups.last?.objectID {
                                        Divider()
                                            .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                        }

                        Spacer()
                            .frame(height: Spacing.section + Spacing.sm)
                    }
                    .padding(.top, Spacing.lg)
                }
                .refreshable {
                    await RefreshHelper.performStandardRefresh(context: viewContext)
                    withAnimation(AppAnimation.standard) { showRefreshFeedback = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        withAnimation(AppAnimation.standard) { showRefreshFeedback = false }
                    }
                }
                .refreshFeedback(isShowing: $showRefreshFeedback)
            }
        }
    }

}

// MARK: - Group Empty State

struct GroupEmptyStateView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("No Groups")
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }
}

// MARK: - Group List Row

struct GroupListRowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var group: UserGroup
    @State private var showingGroupInfo = false
    @State private var showingAddExpense = false
    @State private var showingReminders = false
    @State private var showingEditGroup = false
    @State private var showingDeleteConfirmation = false

    @State private var balance: Double = 0

    private var balanceText: String {
        let formatted = CurrencyFormatter.formatAbsolute(balance)

        if balance > 0.01 {
            return "you're owed \(formatted)"
        } else if balance < -0.01 {
            return "you owe \(formatted)"
        } else {
            return "settled up"
        }
    }

    private var balanceTextView: Text {
        let formatted = CurrencyFormatter.formatAbsolute(balance)

        if balance > 0.01 {
            return Text("you're owed ") + Text(formatted).fontWeight(.bold)
        } else if balance < -0.01 {
            return Text("you owe ") + Text(formatted).fontWeight(.bold)
        } else {
            return Text("settled up")
        }
    }

    private var balanceColor: Color {
        if balance > 0.01 {
            return AppColors.positive
        } else if balance < -0.01 {
            return AppColors.negative
        } else {
            return AppColors.neutral
        }
    }

    private var memberCount: Int {
        group.members?.count ?? 0
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color(hex: group.colorHex ?? AppColors.defaultAvatarColorHex).opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(AppTypography.headingMedium())
                        .foregroundColor(Color(hex: group.colorHex ?? AppColors.defaultAvatarColorHex))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(group.name ?? "Unknown Group")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Text("\(memberCount) members")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    Text("•")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    balanceTextView
                        .font(AppTypography.bodySmall())
                        .foregroundColor(balanceColor)
                }
                .lineLimit(1)
            }

            Spacer()

            if abs(balance) > 0.01 {
                Text(CurrencyFormatter.formatAbsolute(balance))
                    .font(AppTypography.financialDefault())
                    .foregroundColor(balanceColor)
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name ?? "Unknown Group"), \(memberCount) members, \(balanceText)")
        .contextMenu {
            Button {
                HapticManager.lightTap()
                showingGroupInfo = true
            } label: {
                Label("View Group Info", systemImage: "info.circle")
            }

            Button {
                HapticManager.lightTap()
                showingEditGroup = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                HapticManager.lightTap()
                showingAddExpense = true
            } label: {
                Label("Add Expense", systemImage: "plus.circle")
            }

            if balance > 0.01 {
                Button {
                    HapticManager.lightTap()
                    showingReminders = true
                } label: {
                    Label("Send Reminders", systemImage: "bell")
                }
            }

            Divider()

            Button(role: .destructive) {
                HapticManager.delete()
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingGroupInfo) {
            NavigationStack {
                GroupDetailView(group: group)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingGroupInfo = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingEditGroup) {
            NavigationStack {
                EditGroupView(group: group)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddTransactionPresenter(initialGroup: group)
        }
        .sheet(isPresented: $showingReminders) {
            GroupReminderSheetView(group: group)
        }
        .alert("Delete Group", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteGroup()
            }
        } message: {
            Text("Are you sure you want to delete \"\(group.name ?? "this group")\"? This will remove the group and its data.")
        }
        .task {
            balance = group.calculateBalance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            balance = group.calculateBalance()
        }
    }

    private func deleteGroup() {
        viewContext.delete(group)
        do {
            try viewContext.save()
            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            AppLogger.coreData.error("Failed to delete group: \(error.localizedDescription)")
        }
    }
}
