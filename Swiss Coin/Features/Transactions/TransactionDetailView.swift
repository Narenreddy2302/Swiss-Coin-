//
//  TransactionDetailView.swift
//  Swiss Coin
//
//  Detail view for viewing, editing, and deleting a transaction.
//

import CoreData
import SwiftUI

struct TransactionDetailView: View {
    @ObservedObject var transaction: FinancialTransaction
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showContent = false

    // MARK: - Computed Properties

    private var splits: [TransactionSplit] {
        let splitSet = transaction.splits as? Set<TransactionSplit> ?? []
        return splitSet.sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }
    }

    private var splitMethod: SplitMethod? {
        guard let raw = transaction.splitMethod else { return nil }
        return SplitMethod(rawValue: raw)
    }

    private var payerName: String {
        if let payer = transaction.payer, CurrentUser.isCurrentUser(payer.id) {
            return "You"
        }
        return transaction.payer?.displayName ?? "Unknown"
    }

    private var formattedDate: String {
        guard let date = transaction.date else { return "Unknown date" }
        return DateFormatter.longDate.string(from: date)
    }

    private var relativeDate: String {
        guard let date = transaction.date else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        return ""
    }

    private var participantCount: Int {
        var participants = Set<UUID>()
        if let payerId = transaction.payer?.id {
            participants.insert(payerId)
        }
        for split in splits {
            if let owedById = split.owedBy?.id {
                participants.insert(owedById)
            }
        }
        return max(participants.count, 1)
    }

    private var isPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
    }

    private var myShare: Double {
        splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) })?.amount ?? 0
    }

    private var netAmount: Double {
        if isPayer {
            return max(transaction.amount - myShare, 0)
        } else {
            return myShare
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero header
                heroHeader
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)

                // Content sections
                VStack(spacing: Spacing.lg) {
                    // Quick info pills
                    quickInfoRow
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 8)

                    // Payer card
                    payerCard
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 8)

                    // Split breakdown
                    splitBreakdownCard
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 8)

                    // Group section
                    if transaction.group != nil {
                        groupCard
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 8)
                    }

                    // Action buttons
                    actionButtons
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 8)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.section)
            }
        }
        .background(AppColors.backgroundSecondary)
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                showContent = true
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TransactionEditView(transaction: transaction)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTransaction()
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                HapticManager.tap()
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: Spacing.lg) {
            // Amount hero
            VStack(spacing: Spacing.sm) {
                Text(CurrencyFormatter.format(transaction.amount))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)

                Text(transaction.title ?? "Unknown")
                    .font(AppTypography.title3())
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            // Date
            HStack(spacing: Spacing.xs) {
                Image(systemName: "calendar")
                    .font(.system(size: IconSize.xs))
                    .foregroundColor(AppColors.textTertiary)

                if !relativeDate.isEmpty {
                    Text(relativeDate)
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textSecondary)
                    Text("\u{00B7}")
                        .foregroundColor(AppColors.textTertiary)
                }

                Text(formattedDate)
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textTertiary)
            }

            // Net balance indicator
            if netAmount > 0.01 {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: isPayer ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                        .font(.system(size: IconSize.sm))
                    Text(isPayer ? "You lent \(CurrencyFormatter.format(netAmount))" : "You owe \(CurrencyFormatter.format(netAmount))")
                        .font(AppTypography.subheadlineMedium())
                }
                .foregroundColor(isPayer ? AppColors.positive : AppColors.negative)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill((isPayer ? AppColors.positive : AppColors.negative).opacity(0.1))
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Quick Info Row

    private var quickInfoRow: some View {
        HStack(spacing: Spacing.md) {
            // Split method pill
            HStack(spacing: Spacing.xs) {
                if let method = splitMethod {
                    Image(systemName: method.systemImage)
                        .font(.system(size: IconSize.xs))
                }
                Text(splitMethod?.displayName ?? "Equal")
                    .font(AppTypography.caption())
            }
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(AppColors.surface)
            .cornerRadius(CornerRadius.full)

            // Participants pill
            HStack(spacing: Spacing.xs) {
                Image(systemName: "person.2")
                    .font(.system(size: IconSize.xs))
                Text("\(participantCount) people")
                    .font(AppTypography.caption())
            }
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(AppColors.surface)
            .cornerRadius(CornerRadius.full)

            Spacer()
        }
    }

    // MARK: - Payer Card

    private var payerCard: some View {
        HStack(spacing: Spacing.md) {
            // Payer avatar
            if let payer = transaction.payer {
                Circle()
                    .fill(payer.avatarBackgroundColor)
                    .frame(width: AvatarSize.md, height: AvatarSize.md)
                    .overlay(
                        Text(CurrentUser.isCurrentUser(payer.id) ? CurrentUser.initials : payer.initials)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(payer.avatarTextColor)
                    )
            } else {
                Circle()
                    .fill(AppColors.surface)
                    .frame(width: AvatarSize.md, height: AvatarSize.md)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textTertiary)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Paid by")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
                Text(payerName)
                    .font(AppTypography.headline())
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer()

            Text(CurrencyFormatter.format(transaction.amount))
                .font(AppTypography.amount())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.md)
    }

    // MARK: - Split Breakdown Card

    private var splitBreakdownCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            HStack {
                Text("Split Breakdown")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(CurrencyFormatter.format(transaction.amount))
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }

            if splits.isEmpty {
                HStack {
                    Spacer()
                    Text("No split details available")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                }
                .padding(.vertical, Spacing.lg)
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(splits, id: \.objectID) { split in
                        splitRow(split)

                        if split.objectID != splits.last?.objectID {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.md)
    }

    private func splitRow(_ split: TransactionSplit) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                // Person avatar
                if let person = split.owedBy {
                    Circle()
                        .fill(person.avatarBackgroundColor)
                        .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                        .overlay(
                            Text(CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(person.avatarTextColor)
                        )
                } else {
                    Circle()
                        .fill(AppColors.surface)
                        .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                        .overlay(
                            Text("?")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        )
                }

                // Person name and percentage
                VStack(alignment: .leading, spacing: 1) {
                    Text(personDisplayName(for: split))
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    if transaction.amount > 0 {
                        let percentage = (split.amount / transaction.amount) * 100
                        Text(String(format: "%.0f%%", percentage))
                            .font(AppTypography.caption2())
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Spacer()

                // Amount
                Text(CurrencyFormatter.format(split.amount))
                    .font(AppTypography.amountSmall())
                    .foregroundColor(splitAmountColor(for: split))
            }

            // Progress bar showing proportion
            if transaction.amount > 0 {
                GeometryReader { geometry in
                    let fraction = min(split.amount / transaction.amount, 1.0)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.separator)
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(splitAmountColor(for: split).opacity(0.6))
                            .frame(width: geometry.size.width * fraction, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private func personDisplayName(for split: TransactionSplit) -> String {
        guard let person = split.owedBy else { return "Unknown" }
        if CurrentUser.isCurrentUser(person.id) {
            return "You"
        }
        return person.displayName
    }

    private func splitAmountColor(for split: TransactionSplit) -> Color {
        guard let person = split.owedBy else { return AppColors.textPrimary }
        if CurrentUser.isCurrentUser(person.id) {
            // This is my share
            return CurrentUser.isCurrentUser(transaction.payer?.id) ? AppColors.textSecondary : AppColors.negative
        } else {
            // Someone else's share
            return CurrentUser.isCurrentUser(transaction.payer?.id) ? AppColors.positive : AppColors.textSecondary
        }
    }

    // MARK: - Group Card

    private var groupCard: some View {
        HStack(spacing: Spacing.md) {
            if let group = transaction.group {
                Circle()
                    .fill(Color(hex: group.colorHex ?? "#808080").opacity(0.2))
                    .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                    .overlay(
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: group.colorHex ?? "#808080"))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("Group")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                    Text(group.name ?? "Unknown Group")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: IconSize.xs, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.md)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            // Edit button
            Button {
                HapticManager.tap()
                showingEditSheet = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "pencil")
                        .font(.system(size: IconSize.sm))
                    Text("Edit Transaction")
                        .font(AppTypography.bodyBold())
                }
                .foregroundColor(AppColors.buttonForeground)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.lg)
                .background(AppColors.buttonBackground)
                .cornerRadius(CornerRadius.md)
            }
            .buttonStyle(AppButtonStyle(haptic: .none))

            // Delete button
            Button {
                HapticManager.tap()
                showingDeleteAlert = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "trash")
                        .font(.system(size: IconSize.sm))
                    Text("Delete Transaction")
                        .font(AppTypography.bodyBold())
                }
                .foregroundColor(AppColors.negative)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.lg)
                .background(AppColors.negative.opacity(0.1))
                .cornerRadius(CornerRadius.md)
            }
            .buttonStyle(AppButtonStyle(haptic: .none))
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Actions

    private func deleteTransaction() {
        HapticManager.delete()

        // Delete associated splits first
        if let splits = transaction.splits as? Set<TransactionSplit> {
            splits.forEach { viewContext.delete($0) }
        }

        // Delete the transaction
        viewContext.delete(transaction)

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to delete transaction: \(error.localizedDescription)"
            showingError = true
        }
    }
}
