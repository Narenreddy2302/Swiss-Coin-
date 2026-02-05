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
        VStack(spacing: Spacing.lg) {

            // MARK: Personal or Split Toggle
            VStack(spacing: 0) {
                // Personal option
                SplitOptionRow(
                    icon: "👤",
                    title: "Personal",
                    subtitle: "Just for you",
                    isSelected: !viewModel.isSplit
                ) {
                    HapticManager.selectionChanged()
                    withAnimation {
                        viewModel.isSplit = false
                    }
                }

                Divider()
                    .padding(.leading, 72)

                // Split option
                SplitOptionRow(
                    icon: "👥",
                    title: "Split",
                    subtitle: "Share with friends or groups",
                    isSelected: viewModel.isSplit
                ) {
                    HapticManager.selectionChanged()
                    withAnimation {
                        viewModel.isSplit = true
                    }
                }
            }
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.md)

            // MARK: Split Configuration (only shown when splitting)
            if viewModel.isSplit {

                // MARK: Paid By Section
                SectionHeader(title: "PAID BY")

                // Show selected payer or search interface
                if viewModel.isPaidBySearchFocused {
                    // Search mode
                    PaidBySearchView(viewModel: viewModel)
                } else {
                    // Display selected payer with change button
                    SelectedPayerCard(viewModel: viewModel)
                }

                // MARK: Split With Section
                SectionHeader(title: "SPLIT WITH (\(viewModel.participantIds.count))")

                // Search bar for adding participants
                SearchBarView(
                    placeholder: "Search contacts or groups...",
                    text: $viewModel.splitWithSearchText,
                    onFocus: {
                        withAnimation {
                            viewModel.isSplitWithSearchFocused = true
                        }
                    }
                )

                // Show search results or participant list
                if viewModel.isSplitWithSearchFocused && !viewModel.splitWithSearchText.isEmpty {
                    // Search results
                    SplitWithSearchResultsView(viewModel: viewModel)
                } else {
                    // Selected group badge (if any)
                    if let group = viewModel.selectedGroup {
                        SelectedGroupBadge(group: group) {
                            viewModel.clearSelectedGroup()
                        }
                    }

                    // Participants list
                    ParticipantsListView(viewModel: viewModel)
                }
            }

            // MARK: Navigation Buttons
            HStack(spacing: Spacing.md) {
                // Back button
                Button {
                    HapticManager.tap()
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .font(AppTypography.bodyBold())
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, Spacing.xl)
                        .frame(height: ButtonHeight.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                }

                // Continue/Save button
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
        HStack(spacing: 12) {
            // Avatar
            // Since PaidByPerson is optional (nil = Me), we check that.
            // But we already have a helper in ViewModel? No, only computed name.
            // Use logic here.

            let isMe = viewModel.paidByPerson == nil
            let initials = isMe ? "ME" : (viewModel.paidByPerson?.initials ?? "?")

            PersonAvatar(
                initials: initials,
                isCurrentUser: isMe,
                isSelected: true,
                size: 48
            )

            // Name
            Text(viewModel.paidByName)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            // Change button
            Button {
                HapticManager.tap()
                withAnimation {
                    viewModel.isPaidBySearchFocused = true
                }
            } label: {
                Text("Change")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(AppColors.accent.opacity(0.1))
                    .cornerRadius(CornerRadius.sm)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.md)
    }
}

struct PaidBySearchView: View {
    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            SearchBarView(
                placeholder: "Search contacts...",
                text: $viewModel.paidBySearchText
            )

            // Results list
            VStack(spacing: 0) {
                // "Me" option always at top if not searching or if "me" matches search?
                // Reference just filtered friends. "You" was a friend "u1".
                // Here "You" is implicit. Let's add "You" option explicitly.

                Button {
                    viewModel.selectPayer(nil)  // nil = Me
                } label: {
                    HStack(spacing: 12) {
                        PersonAvatar(
                            initials: "ME", isCurrentUser: true,
                            isSelected: viewModel.paidByPerson == nil, size: 44)
                        Text("You")
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        if viewModel.paidByPerson == nil {
                            Image(systemName: "checkmark").foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Divider().padding(.leading, 72)

                ForEach(
                    Array(viewModel.filteredPaidByContacts.enumerated()), id: \.element.objectID
                ) { index, person in
                    Button {
                        viewModel.selectPayer(person)
                    } label: {
                        ContactSearchRow(
                            person: person,
                            isSelected: viewModel.paidByPerson == person
                        )
                    }

                    if index < viewModel.filteredPaidByContacts.count - 1 {
                        Divider().padding(.leading, 72)
                    }
                }

                if viewModel.filteredPaidByContacts.isEmpty && !viewModel.paidBySearchText.isEmpty {
                    // Only show empty if searching and no match (ignoring Me)
                }
            }
            .background(AppColors.cardBackground)
            .cornerRadius(12)

            // Cancel button
            Button {
                withAnimation {
                    viewModel.isPaidBySearchFocused = false
                    viewModel.paidBySearchText = ""
                }
            } label: {
                Text("Cancel")
                    .font(.system(size: 17))
                    .foregroundColor(AppColors.accent)
            }
        }
    }
}

struct SplitWithSearchResultsView: View {
    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Groups section
            if !viewModel.filteredSplitWithGroups.isEmpty {
                HStack {
                    Text("GROUPS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.groupedBackground)

                ForEach(viewModel.filteredSplitWithGroups, id: \.self) { group in
                    Button {
                        viewModel.selectGroup(group)
                    } label: {
                        GroupSearchRow(
                            group: group,
                            isSelected: viewModel.selectedGroup == group
                        )
                    }
                }
            }

            // Contacts section
            if !viewModel.filteredSplitWithContacts.isEmpty {
                HStack {
                    Text("CONTACTS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.groupedBackground)

                ForEach(viewModel.filteredSplitWithContacts, id: \.self) { person in
                    Button {
                        viewModel.addParticipantFromSearch(person)
                    } label: {
                        ContactSearchRow(
                            person: person,
                            isSelected: viewModel.participantIds.contains(person.id ?? UUID())
                        )
                    }
                }
            }

            if viewModel.filteredSplitWithGroups.isEmpty
                && viewModel.filteredSplitWithContacts.isEmpty
            {
                Text("No results found")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }
}

struct ParticipantsListView: View {
    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 1. "You" (CurrentUser)
            // Always show "You" at top if you are a participant (which is default)
            let meSelected = viewModel.participantIds.contains(viewModel.currentUserUUID)

            Button {
                viewModel.toggleParticipant(viewModel.currentUserUUID)
            } label: {
                HStack(spacing: 12) {
                    PersonAvatar(
                        initials: "ME",
                        isCurrentUser: true,
                        isSelected: meSelected,
                        size: 40
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You")
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Spacer()

                    Circle()
                        .strokeBorder(
                            meSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.5), lineWidth: 2
                        )
                        .background(Circle().fill(meSelected ? AppColors.accent : Color.clear))
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(meSelected ? 1 : 0)
                        )
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider().padding(.leading, 68)

            // 2. Other People
            // We iterate over `allPeople` to show toggleable list?
            // Reference `SampleData.friends` was a small static list.
            // PROD: We might have hundreds of contacts. We shouldn't list them ALL here if not filtered?
            // "Participants List" in reference seems to show search results OR "selected group participants"?
            // Re-reading reference: "Participants List" shows `SampleData.friends`.
            // If I have 1000 contacts, this is bad.
            // BUT, usually "Split with" section shows ALREADY SELECTED participants + suggestions?
            // The reference implementation shows ALL friends in `ParticipantsListView`.
            // I will limit it to first 5-10 or just show selected participants + maybe recent?
            // For now, I'll show `allPeople` but maybe capped or assume list is small.
            // Or better: Show only SELECTED participants here + maybe allow search to add more?
            // Reference has a search bar above.
            // If search is empty, it shows `ParticipantsListView`.
            // Use `viewModel.allPeople.prefix(20)`?

            ForEach(Array(viewModel.allPeople.prefix(50).enumerated()), id: \.element.objectID) {
                index, person in
                let personId = person.id ?? UUID()
                let isSelected = viewModel.participantIds.contains(personId)
                // Check if from group? logic omitted for simplicity unless group members known

                Button {
                    viewModel.toggleParticipant(personId)
                } label: {
                    HStack(spacing: 12) {
                        PersonAvatar(
                            initials: person.initials,
                            isCurrentUser: false,
                            isSelected: isSelected,
                            size: 40
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name ?? "Unknown")
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textPrimary)
                        }

                        Spacer()

                        Circle()
                            .strokeBorder(
                                isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.5), lineWidth: 2
                            )
                            .background(Circle().fill(isSelected ? AppColors.accent : Color.clear))
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .opacity(isSelected ? 1 : 0)
                            )
                            .frame(width: 24, height: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                if index < min(viewModel.allPeople.count, 50) - 1 {
                    Divider().padding(.leading, 68)
                }
            }
        }
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }
}
