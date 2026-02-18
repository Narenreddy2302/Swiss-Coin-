//
//  GroupReminderSheetView.swift
//  Swiss Coin
//
//  Reminder sheet for sending reminders to group members who owe you.
//

import CoreData
import SwiftUI

struct GroupReminderSheetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let group: UserGroup

    @State private var selectedMembers: Set<UUID> = []
    @State private var message: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    private var membersWhoOweYou: [(member: Person, balance: CurrencyBalance)] {
        group.getMembersWhoOweYou()
    }

    private var selectedCount: Int {
        selectedMembers.count
    }

    private var totalSelectedAmount: Double {
        membersWhoOweYou
            .filter { selectedMembers.contains($0.member.id ?? UUID()) }
            .reduce(0) { $0 + $1.balance.primaryAmount }
    }

    private var formattedTotalAmount: String {
        CurrencyFormatter.format(totalSelectedAmount)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xxl) {
                // Header
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: IconSize.xxl))
                        .foregroundColor(AppColors.warning)

                    Text("Send Reminders")
                        .font(AppTypography.displayMedium())

                    Text("Select members to remind in \(group.name ?? "the group")")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.section)

                if membersWhoOweYou.isEmpty {
                    // No one owes you
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: IconSize.xxl))
                            .foregroundColor(AppColors.positive)

                        Text("No reminders needed")
                            .font(AppTypography.headingMedium())
                            .foregroundColor(AppColors.textPrimary)

                        Text("No one in this group owes you money.")
                            .font(AppTypography.bodyLarge())
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xxl)
                    }
                    .padding(.vertical, Spacing.section)
                } else {
                    // Member Selection
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            Text("Members who owe you")
                                .font(AppTypography.labelLarge())
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            Button {
                                HapticManager.tap()
                                if selectedMembers.count == membersWhoOweYou.count {
                                    selectedMembers.removeAll()
                                } else {
                                    selectedMembers = Set(membersWhoOweYou.compactMap { $0.member.id })
                                }
                            } label: {
                                Text(selectedMembers.count == membersWhoOweYou.count ? "Deselect All" : "Select All")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(.horizontal, Spacing.xxl)

                        ScrollView {
                            VStack(spacing: Spacing.sm) {
                                ForEach(membersWhoOweYou, id: \.member.id) { item in
                                    MemberReminderRow(
                                        member: item.member,
                                        amount: item.balance.primaryAmount,
                                        isSelected: selectedMembers.contains(item.member.id ?? UUID()),
                                        onToggle: {
                                            HapticManager.selectionChanged()
                                            if let id = item.member.id {
                                                if selectedMembers.contains(id) {
                                                    selectedMembers.remove(id)
                                                } else {
                                                    selectedMembers.insert(id)
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, Spacing.xxl)
                        }
                        .frame(maxHeight: 200)
                    }

                    // Summary
                    if selectedCount > 0 {
                        VStack(spacing: Spacing.xs) {
                            Text("\(selectedCount) member\(selectedCount == 1 ? "" : "s") selected")
                                .font(AppTypography.bodyDefault())
                                .foregroundColor(AppColors.textSecondary)

                            Text("Total: \(formattedTotalAmount)")
                                .font(AppTypography.headingMedium())
                                .foregroundColor(AppColors.positive)
                        }
                        .padding(.vertical, Spacing.md)
                    }

                    // Message Field
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Message (optional)")
                            .font(AppTypography.labelLarge())
                            .foregroundColor(AppColors.textSecondary)

                        TextField("Add a friendly reminder message...", text: $message, axis: .vertical)
                            .limitTextLength(to: ValidationLimits.maxMessageLength, text: $message)
                            .font(AppTypography.bodyLarge())
                            .lineLimit(3...6)
                            .padding(Spacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(AppColors.backgroundTertiary)
                            )
                    }
                    .padding(.horizontal, Spacing.xxl)
                }

                Spacer()

                // Send Button
                if !membersWhoOweYou.isEmpty {
                    Button {
                        HapticManager.primaryAction()
                        sendReminders()
                    } label: {
                        HStack {
                            Image(systemName: "bell.fill")
                                .font(.system(size: IconSize.sm))
                            Text(selectedCount == 1 ? "Send Reminder" : "Send \(selectedCount) Reminders")
                                .font(AppTypography.buttonDefault())
                        }
                        .foregroundColor(AppColors.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: ButtonHeight.lg)
                        .background(selectedCount > 0 ? AppColors.warning : AppColors.disabled)
                        .cornerRadius(CornerRadius.md)
                    }
                    .buttonStyle(AppButtonStyle(haptic: .none))
                    .disabled(selectedCount == 0)
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .background(AppColors.backgroundSecondary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.cancel()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    HapticManager.tap()
                }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                HapticManager.prepare()
                // Auto-select all members
                selectedMembers = Set(membersWhoOweYou.compactMap { $0.member.id })
            }
        }
    }

    // MARK: - Actions

    private func sendReminders() {
        guard selectedCount > 0 else {
            HapticManager.error()
            errorMessage = "Please select at least one member"
            showingError = true
            return
        }

        var successCount = 0

        for item in membersWhoOweYou {
            guard let memberId = item.member.id, selectedMembers.contains(memberId) else { continue }

            let reminder = Reminder(context: viewContext)
            reminder.id = UUID()
            reminder.createdDate = Date()
            reminder.amount = item.balance.primaryAmount
            reminder.message = message.isEmpty ? nil : message
            reminder.isRead = true
            reminder.isCleared = false
            reminder.toPerson = item.member

            successCount += 1
        }

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to send reminders: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Member Reminder Row

private struct MemberReminderRow: View {
    let member: Person
    let amount: Double
    let isSelected: Bool
    let onToggle: () -> Void

    private var formattedAmount: String {
        CurrencyFormatter.format(amount)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.md) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: IconSize.lg))
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)

                // Avatar
                Circle()
                    .fill(Color(hex: member.colorHex ?? CurrentUser.defaultColorHex).opacity(0.3))
                    .frame(width: AvatarSize.xs, height: AvatarSize.xs)
                    .overlay(
                        Text(member.initials)
                            .font(AppTypography.labelSmall())
                            .foregroundColor(Color(hex: member.colorHex ?? CurrentUser.defaultColorHex))
                    )

                // Name
                Text(member.name ?? "Unknown")
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                // Amount
                Text("owes \(formattedAmount)")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.positive)
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(isSelected ? AppColors.cardBackground : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
