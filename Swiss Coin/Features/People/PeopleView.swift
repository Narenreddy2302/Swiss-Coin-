import CoreData
import os
import SwiftUI

struct PeopleView: View {
    @State private var selectedSegment = 0
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingNewMessage = false

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

                if selectedSegment == 0 {
                    PersonListView()
                } else {
                    GroupListView()
                }
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if selectedSegment == 0 {
                            Button {
                                HapticManager.tap()
                                showingNewMessage = true
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }
                            NavigationLink(destination: AddPersonView()) {
                                Image(systemName: "plus")
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.tap()
                            })
                        } else {
                            NavigationLink(destination: AddGroupView()) {
                                Image(systemName: "plus")
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                HapticManager.tap()
                            })
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewMessage) {
                NewTransactionContactView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .onAppear {
                HapticManager.prepare()
            }
        }
    }
}

struct PersonListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        predicate: {
            if let userId = CurrentUser.currentUserId {
                return NSPredicate(
                    format: "id != %@ AND (toTransactions.@count > 0 OR owedSplits.@count > 0 OR sentSettlements.@count > 0 OR receivedSettlements.@count > 0 OR chatMessages.@count > 0)",
                    userId as CVarArg
                )
            } else {
                // No current user ID — show all people with transactions
                return NSPredicate(
                    format: "toTransactions.@count > 0 OR owedSplits.@count > 0 OR sentSettlements.@count > 0 OR receivedSettlements.@count > 0 OR chatMessages.@count > 0"
                )
            }
        }(),
        animation: .default)
    private var people: FetchedResults<Person>

    var body: some View {
        Group {
            if people.isEmpty {
                PersonEmptyStateView()
            } else {
                List {
                    ForEach(people) { person in
                        NavigationLink(destination: PersonConversationView(person: person)) {
                            PersonListRowView(person: person)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(AppColors.backgroundSecondary)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppColors.backgroundSecondary)
            }
        }
    }
}

struct PersonEmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "person.2.slash")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary)
                .accessibilityHidden(true)

            Text("No People Yet")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)

            Text("Add an expense with someone to start tracking balances")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }
}

struct PersonListRowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var person: Person
    @State private var isPressed = false
    @State private var showingProfile = false
    @State private var showingAddExpense = false
    @State private var showingReminder = false
    @State private var showingEditPerson = false
    @State private var showingDeleteConfirmation = false

    private var balance: Double {
        person.calculateBalance()
    }

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
                        .font(AppTypography.title3())
                        .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(person.name ?? "Unknown")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)

                Text(balanceText)
                    .font(AppTypography.subheadline())
                    .foregroundColor(balanceColor)
            }

            Spacer()

            if abs(balance) > 0.01 {
                Text(CurrencyFormatter.formatAbsolute(balance))
                    .font(AppTypography.amountSmall())
                    .foregroundColor(balanceColor)
            }
        }
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.lg)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(AppAnimation.quick, value: isPressed)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(person.name ?? "Unknown"), \(balanceText)")
        .contextMenu {
            Button {
                HapticManager.tap()
                showingProfile = true
            } label: {
                Label("View Profile", systemImage: "person.circle")
            }

            Button {
                HapticManager.tap()
                showingEditPerson = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                HapticManager.tap()
                showingAddExpense = true
            } label: {
                Label("Add Expense", systemImage: "plus.circle")
            }

            if balance > 0.01 {
                Button {
                    HapticManager.tap()
                    showingReminder = true
                } label: {
                    Label("Send Reminder", systemImage: "bell")
                }
            }

            Divider()

            Button(role: .destructive) {
                HapticManager.tap()
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
            QuickActionSheetPresenter(initialPerson: person)
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
            Text("Are you sure you want to delete \(person.name ?? "this person")? This will remove all associated data.")
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

struct GroupListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \UserGroup.name, ascending: true)],
        animation: .default)
    private var groups: FetchedResults<UserGroup>

    var body: some View {
        Group {
            if groups.isEmpty {
                GroupEmptyStateView()
            } else {
                List {
                    ForEach(groups) { group in
                        NavigationLink(destination: GroupConversationView(group: group)) {
                            GroupListRowView(group: group)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(AppColors.backgroundSecondary)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppColors.backgroundSecondary)
            }
        }
    }
}

struct GroupEmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "person.3.slash")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary)
                .accessibilityHidden(true)

            Text("No Groups Yet")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)

            Text("Create a group to split expenses with multiple people")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }
}

struct GroupListRowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var group: UserGroup
    @State private var isPressed = false
    @State private var showingGroupInfo = false
    @State private var showingAddExpense = false
    @State private var showingReminders = false
    @State private var showingEditGroup = false
    @State private var showingDeleteConfirmation = false

    private var balance: Double {
        group.calculateBalance()
    }

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
                .fill(Color(hex: group.colorHex ?? "#007AFF").opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(AppTypography.headline())
                        .foregroundColor(Color(hex: group.colorHex ?? "#007AFF"))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(group.name ?? "Unknown Group")
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: Spacing.xs) {
                    Text("\(memberCount) members")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    Text("•")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    Text(balanceText)
                        .font(AppTypography.subheadline())
                        .foregroundColor(balanceColor)
                }
            }

            Spacer()

            if abs(balance) > 0.01 {
                Text(CurrencyFormatter.formatAbsolute(balance))
                    .font(AppTypography.amountSmall())
                    .foregroundColor(balanceColor)
            }
        }
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.lg)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(AppAnimation.quick, value: isPressed)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name ?? "Unknown Group"), \(memberCount) members, \(balanceText)")
        .contextMenu {
            Button {
                HapticManager.tap()
                showingGroupInfo = true
            } label: {
                Label("View Group Info", systemImage: "info.circle")
            }

            Button {
                HapticManager.tap()
                showingEditGroup = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                HapticManager.tap()
                showingAddExpense = true
            } label: {
                Label("Add Expense", systemImage: "plus.circle")
            }

            if balance > 0.01 {
                Button {
                    HapticManager.tap()
                    showingReminders = true
                } label: {
                    Label("Send Reminders", systemImage: "bell")
                }
            }

            Divider()

            Button(role: .destructive) {
                HapticManager.tap()
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
            QuickActionSheetPresenter(initialGroup: group)
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
