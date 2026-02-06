//
//  Step2SplitConfigView.swift
//  Swiss Coin
//
//  Step 2: Configure split options and participants.
//

import SwiftUI
import UIKit

struct Step2SplitConfigView: View {

    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {

            // MARK: Personal or Split Toggle
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Who is this for?")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)

                VStack(spacing: 0) {
                    SplitOptionRow(
                        icon: "person.fill",
                        title: "Personal",
                        subtitle: "Just for you",
                        isSelected: !viewModel.isSplit
                    ) {
                        HapticManager.selectionChanged()
                        withAnimation { viewModel.isSplit = false }
                    }

                    Divider()
                        .padding(.leading, Spacing.xxl + Spacing.xl)

                    SplitOptionRow(
                        icon: "person.2.fill",
                        title: "Split",
                        subtitle: "Share with friends or groups",
                        isSelected: viewModel.isSplit
                    ) {
                        HapticManager.selectionChanged()
                        withAnimation { viewModel.isSplit = true }
                    }
                }
            }

            // MARK: Split Configuration (only shown when splitting)
            if viewModel.isSplit {

                // MARK: Paid By Section
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Paid by")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textSecondary)

                    if viewModel.isPaidBySearchFocused {
                        PaidBySearchView(viewModel: viewModel)
                    } else {
                        SelectedPayerCard(viewModel: viewModel)
                    }
                }

                // MARK: Split With Section
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Split with (\(viewModel.participantIds.count))")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textSecondary)

                    SearchBarView(
                        placeholder: "Search contacts or groups...",
                        text: $viewModel.splitWithSearchText,
                        onFocus: {
                            withAnimation {
                                viewModel.isSplitWithSearchFocused = true
                            }
                        }
                    )

                    if viewModel.isSplitWithSearchFocused && !viewModel.splitWithSearchText.isEmpty {
                        SplitWithSearchResultsView(viewModel: viewModel)
                    } else {
                        if let group = viewModel.selectedGroup {
                            SelectedGroupBadge(group: group) {
                                viewModel.clearSelectedGroup()
                            }
                        }

                        ParticipantsListView(viewModel: viewModel)
                    }
                }
            }

            // MARK: Navigation Buttons
            HStack(spacing: Spacing.md) {
                Button {
                    HapticManager.tap()
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .font(AppTypography.bodyBold())
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, Spacing.xl)
                        .frame(height: ButtonHeight.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.backgroundTertiary)
                        )
                }

                Button {
                    HapticManager.tap()
                    if !viewModel.isSplit {
                        viewModel.saveTransaction()
                    } else if viewModel.canProceedStep2 {
                        viewModel.nextStep()
                    }
                } label: {
                    Text(viewModel.isSplit ? "Continue" : "Save")
                        .font(AppTypography.bodyBold())
                        .foregroundColor(AppColors.buttonForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: ButtonHeight.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(viewModel.canProceedStep2 ? AppColors.buttonBackground : AppColors.disabled)
                        )
                }
                .disabled(!viewModel.canProceedStep2)
            }
        }
    }
}

// MARK: - Subviews

struct SelectedPayerCard: View {
    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        let isMe = viewModel.paidByPerson == nil
        let initials = isMe ? "ME" : (viewModel.paidByPerson?.initials ?? "?")

        HStack(spacing: Spacing.md) {
            PersonAvatar(
                initials: initials,
                isCurrentUser: isMe,
                isSelected: true,
                size: 44
            )

            Text(viewModel.paidByName)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            Button {
                HapticManager.tap()
                withAnimation {
                    viewModel.isPaidBySearchFocused = true
                }
            } label: {
                Text("Change")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}

struct PaidBySearchView: View {
    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SearchBarView(
                placeholder: "Search contacts...",
                text: $viewModel.paidBySearchText
            )

            VStack(spacing: 0) {
                Button {
                    HapticManager.selectionChanged()
                    viewModel.selectPayer(nil)
                } label: {
                    HStack(spacing: Spacing.md) {
                        PersonAvatar(
                            initials: "ME", isCurrentUser: true,
                            isSelected: viewModel.paidByPerson == nil, size: 44)
                        Text("You")
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        if viewModel.paidByPerson == nil {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.vertical, Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(viewModel.filteredPaidByContacts, id: \.objectID) { person in
                    Divider()
                        .padding(.leading, Spacing.xxl + Spacing.xl)

                    Button {
                        HapticManager.selectionChanged()
                        viewModel.selectPayer(person)
                    } label: {
                        HStack(spacing: Spacing.md) {
                            PersonAvatar(
                                initials: person.initials,
                                isCurrentUser: false,
                                isSelected: viewModel.paidByPerson == person,
                                size: 44
                            )
                            Text(person.displayName)
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if viewModel.paidByPerson == person {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(.vertical, Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                HapticManager.tap()
                withAnimation {
                    viewModel.isPaidBySearchFocused = false
                    viewModel.paidBySearchText = ""
                }
            } label: {
                Text("Cancel")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct SplitWithSearchResultsView: View {
    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.filteredSplitWithGroups.isEmpty {
                Text("Groups")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, Spacing.sm)

                ForEach(viewModel.filteredSplitWithGroups, id: \.self) { group in
                    Button {
                        HapticManager.selectionChanged()
                        viewModel.selectGroup(group)
                    } label: {
                        HStack(spacing: Spacing.md) {
                            Text("👥")
                                .font(.system(size: 20))
                                .frame(width: 44, height: 44)
                                .background(AppColors.backgroundTertiary)
                                .cornerRadius(CornerRadius.sm)
                            Text(group.name ?? "Unnamed Group")
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if viewModel.selectedGroup == group {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(.vertical, Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if !viewModel.filteredSplitWithContacts.isEmpty {
                Text("Contacts")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, Spacing.sm)

                ForEach(viewModel.filteredSplitWithContacts, id: \.self) { person in
                    Button {
                        HapticManager.selectionChanged()
                        viewModel.addParticipantFromSearch(person)
                    } label: {
                        HStack(spacing: Spacing.md) {
                            PersonAvatar(
                                initials: person.initials,
                                isCurrentUser: false,
                                isSelected: viewModel.participantIds.contains(person.id ?? UUID()),
                                size: 44
                            )
                            Text(person.displayName)
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if viewModel.participantIds.contains(person.id ?? UUID()) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(.vertical, Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.filteredSplitWithGroups.isEmpty
                && viewModel.filteredSplitWithContacts.isEmpty
            {
                Text("No results found")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, Spacing.xxl)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct ParticipantsListView: View {
    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        VStack(spacing: 0) {
            // "You" row
            let meSelected = viewModel.participantIds.contains(viewModel.currentUserUUID)

            Button {
                HapticManager.selectionChanged()
                viewModel.toggleParticipant(viewModel.currentUserUUID)
            } label: {
                participantRow(
                    avatar: AnyView(PersonAvatar(initials: "ME", isCurrentUser: true, isSelected: meSelected, size: 44)),
                    name: "You",
                    isSelected: meSelected
                )
            }
            .buttonStyle(.plain)

            // Other people
            ForEach(Array(viewModel.allPeople.prefix(50).enumerated()), id: \.element.objectID) {
                index, person in
                let personId = person.id ?? UUID()
                let isSelected = viewModel.participantIds.contains(personId)

                Divider()
                    .padding(.leading, Spacing.xxl + Spacing.xl)

                Button {
                    HapticManager.selectionChanged()
                    viewModel.toggleParticipant(personId)
                } label: {
                    participantRow(
                        avatar: AnyView(PersonAvatar(initials: person.initials, isCurrentUser: false, isSelected: isSelected, size: 44)),
                        name: person.name ?? "Unknown",
                        isSelected: isSelected
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func participantRow(avatar: AnyView, name: String, isSelected: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            avatar

            Text(name)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            ZStack {
                Circle()
                    .strokeBorder(
                        isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.4),
                        lineWidth: 2
                    )
                Circle()
                    .fill(isSelected ? AppColors.accent : Color.clear)
                    .padding(2)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.buttonForeground)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(width: 24, height: 24)
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }
}
