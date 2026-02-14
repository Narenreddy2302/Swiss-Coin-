//
//  Step2SplitConfigView.swift
//  Swiss Coin
//
//  Step 2: Configure who paid and who to split with.
//

import SwiftUI

struct Step2SplitConfigView: View {

    @ObservedObject var viewModel: QuickActionViewModel
    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case paidBy
        case splitWith
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Title
            Text("Split Options")
                .font(AppTypography.displayMedium())
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)

            // MARK: - Paid By Section
            paidBySection
                .padding(.top, Spacing.xl)

            // MARK: - Split With Section
            splitWithSection
                .padding(.top, Spacing.xl)

            Spacer()

            // MARK: - Action Buttons
            actionButtons
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .font(AppTypography.headingMedium())
            }
        }
    }

    // MARK: - Paid By (Multi-Select)

    private var paidBySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Paid By:")
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textPrimary)

            contactSearchField(
                text: $viewModel.paidBySearchText,
                focus: .paidBy
            )

            if !viewModel.paidBySearchText.isEmpty {
                paidBySearchResults
            } else {
                payerChips
            }
        }
    }

    private var payerChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                if viewModel.paidByPersons.isEmpty {
                    // Default: "You" chip
                    chipLabel("You")
                } else {
                    // "You" chip if current user is a payer
                    if viewModel.paidByPersons.contains(where: { CurrentUser.isCurrentUser($0.id) }) {
                        removableChip(name: "You") {
                            viewModel.togglePayer(nil)
                        }
                    }

                    // Other payers sorted by name
                    let otherPayers = Array(viewModel.paidByPersons)
                        .filter { !CurrentUser.isCurrentUser($0.id) }
                        .sorted { ($0.name ?? "") < ($1.name ?? "") }

                    ForEach(otherPayers, id: \.self) { person in
                        removableChip(name: person.firstName) {
                            viewModel.togglePayer(person)
                        }
                    }
                }
            }
        }
    }

    private var paidBySearchResults: some View {
        VStack(spacing: 0) {
            // "You" option
            Button {
                HapticManager.selectionChanged()
                viewModel.togglePayer(nil)
                focusedField = nil
            } label: {
                searchResultRow(
                    name: "You",
                    isSelected: viewModel.paidByPersons.contains { CurrentUser.isCurrentUser($0.id) }
                )
            }
            .buttonStyle(.plain)

            ForEach(viewModel.filteredPaidByContacts, id: \.objectID) { person in
                Divider().padding(.horizontal, Spacing.lg)

                Button {
                    HapticManager.selectionChanged()
                    viewModel.togglePayer(person)
                    focusedField = nil
                } label: {
                    searchResultRow(
                        name: person.displayName,
                        isSelected: viewModel.paidByPersons.contains(person)
                    )
                }
                .buttonStyle(.plain)
            }

            // Phone contacts (not yet in app)
            ForEach(viewModel.filteredPaidByPhoneContacts) { contact in
                Divider().padding(.horizontal, Spacing.lg)

                Button {
                    HapticManager.selectionChanged()
                    viewModel.addPhoneContactAsPayer(contact)
                    focusedField = nil
                } label: {
                    phoneContactSearchRow(contact: contact)
                }
                .buttonStyle(.plain)
            }
        }
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.separator, lineWidth: 1)
        )
    }

    // MARK: - Split With

    private var splitWithSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Split with:")
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textPrimary)

            contactSearchField(
                text: $viewModel.splitWithSearchText,
                focus: .splitWith
            )

            if !viewModel.splitWithSearchText.isEmpty {
                splitWithSearchResults
            } else {
                participantChips
            }
        }
    }

    private var participantChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                // "You" chip first
                if viewModel.participantIds.contains(viewModel.currentUserUUID) {
                    removableChip(name: "You") {
                        viewModel.toggleParticipant(viewModel.currentUserUUID)
                    }
                }

                // Other participants sorted by name
                let otherIds = Array(viewModel.participantIds)
                    .filter { $0 != viewModel.currentUserUUID }
                    .sorted { viewModel.getName(for: $0) < viewModel.getName(for: $1) }

                ForEach(otherIds, id: \.self) { userId in
                    removableChip(name: viewModel.getName(for: userId)) {
                        viewModel.toggleParticipant(userId)
                    }
                }
            }
        }
    }

    private var splitWithSearchResults: some View {
        VStack(spacing: 0) {
            // Groups
            ForEach(viewModel.filteredSplitWithGroups, id: \.objectID) { group in
                Button {
                    HapticManager.selectionChanged()
                    viewModel.selectGroup(group)
                    focusedField = nil
                } label: {
                    searchResultRow(
                        name: group.name ?? "Unnamed Group",
                        isSelected: viewModel.selectedGroup == group
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.horizontal, Spacing.lg)
            }

            // Existing contacts (Person entities)
            let validContacts = viewModel.filteredSplitWithContacts.filter { $0.id != nil }

            ForEach(Array(validContacts.enumerated()), id: \.element.objectID) { index, person in
                if let personId = person.id {
                Button {
                    HapticManager.selectionChanged()
                    viewModel.toggleParticipant(personId)
                    viewModel.splitWithSearchText = ""
                    focusedField = nil
                } label: {
                    searchResultRow(
                        name: person.displayName,
                        isSelected: viewModel.participantIds.contains(personId)
                    )
                }
                .buttonStyle(.plain)

                if index < validContacts.count - 1 || !viewModel.filteredSplitWithPhoneContacts.isEmpty {
                    Divider().padding(.horizontal, Spacing.lg)
                }
                }
            }

            // Phone contacts (not yet in app)
            ForEach(Array(viewModel.filteredSplitWithPhoneContacts.enumerated()), id: \.element.id) { index, contact in
                Button {
                    HapticManager.selectionChanged()
                    viewModel.addPhoneContactAsParticipant(contact)
                    focusedField = nil
                } label: {
                    phoneContactSearchRow(contact: contact)
                }
                .buttonStyle(.plain)

                if index < viewModel.filteredSplitWithPhoneContacts.count - 1 {
                    Divider().padding(.horizontal, Spacing.lg)
                }
            }

            if validContacts.isEmpty && viewModel.filteredSplitWithGroups.isEmpty
                && viewModel.filteredSplitWithPhoneContacts.isEmpty {
                Text("No results found")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, Spacing.md)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.separator, lineWidth: 1)
        )
    }

    // MARK: - Reusable Components

    private func contactSearchField(
        text: Binding<String>,
        focus: FocusField
    ) -> some View {
        HStack {
            TextField("Search Contact...", text: text)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: focus)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }

            Image(systemName: "magnifyingglass")
                .font(.system(size: IconSize.md, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.separator, lineWidth: 1)
        )
    }

    private func searchResultRow(name: String, isSelected: Bool) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }

    private func chipLabel(_ name: String) -> some View {
        Text(name)
            .font(AppTypography.bodyDefault())
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
    }

    private func chipButton(name: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.tap()
            action()
        } label: {
            chipLabel(name)
        }
        .buttonStyle(.plain)
    }

    private func phoneContactSearchRow(contact: ContactsManager.PhoneContact) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(contact.fullName)
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                if let phone = contact.phoneNumbers.first {
                    Text(phone)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "person.badge.plus")
                .font(.system(size: IconSize.sm))
                .foregroundColor(AppColors.accent)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }

    private func removableChip(name: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.tap()
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(name)
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textPrimary)

                Image(systemName: "xmark")
                    .font(AppTypography.labelSmall())
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.leading, Spacing.lg)
            .padding(.trailing, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: Spacing.md) {
            Button {
                HapticManager.tap()
                focusedField = nil
                viewModel.goToMoreOptions()
            } label: {
                Text("More Options")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.xl)
                    .background(AppColors.cardBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
            }

            Button {
                HapticManager.tap()
                focusedField = nil
                viewModel.splitEqualAndSave()
            } label: {
                Text("Split Equal")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.xl)
                    .background(AppColors.cardBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
            }
        }
    }
}
