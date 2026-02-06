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
                .font(AppTypography.title2())
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
    }

    // MARK: - Paid By

    private var paidBySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Paid By:")
                .font(AppTypography.title3())
                .foregroundColor(AppColors.textPrimary)

            contactSearchField(
                text: $viewModel.paidBySearchText,
                focus: .paidBy
            )

            if !viewModel.paidBySearchText.isEmpty {
                paidBySearchResults
            } else {
                payerChip
            }
        }
    }

    private var payerChip: some View {
        HStack {
            chipLabel(viewModel.paidByName)
            Spacer()
        }
    }

    private var paidBySearchResults: some View {
        VStack(spacing: 0) {
            // "You" option
            Button {
                HapticManager.selectionChanged()
                viewModel.selectPayer(nil)
                focusedField = nil
            } label: {
                searchResultRow(
                    name: "You",
                    isSelected: viewModel.paidByPerson == nil
                )
            }
            .buttonStyle(.plain)

            ForEach(viewModel.filteredPaidByContacts, id: \.objectID) { person in
                Divider().padding(.horizontal, Spacing.lg)

                Button {
                    HapticManager.selectionChanged()
                    viewModel.selectPayer(person)
                    focusedField = nil
                } label: {
                    searchResultRow(
                        name: person.displayName,
                        isSelected: viewModel.paidByPerson == person
                    )
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
                .font(AppTypography.title3())
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

            // Contacts
            let validContacts = viewModel.filteredSplitWithContacts.filter { $0.id != nil }

            ForEach(Array(validContacts.enumerated()), id: \.element.objectID) { index, person in
                let personId = person.id!

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

                if index < validContacts.count - 1 {
                    Divider().padding(.horizontal, Spacing.lg)
                }
            }

            if validContacts.isEmpty && viewModel.filteredSplitWithGroups.isEmpty {
                Text("No results found")
                    .font(AppTypography.subheadline())
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
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: focus)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }

            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
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
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }

    private func chipLabel(_ name: String) -> some View {
        Text(name)
            .font(AppTypography.subheadline())
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

    private func removableChip(name: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.tap()
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(name)
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textPrimary)

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
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
                viewModel.goToMoreOptions()
            } label: {
                Text("More Options")
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.xl)
                    .background(AppColors.cardBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
            }

            Button {
                HapticManager.tap()
                viewModel.splitEqualAndSave()
            } label: {
                Text("Split Equal")
                    .font(AppTypography.bodyBold())
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
