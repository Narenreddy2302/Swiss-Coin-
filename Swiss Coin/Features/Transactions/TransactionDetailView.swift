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

    // MARK: - Computed Properties

    private var splits: [TransactionSplit] {
        let splitSet = transaction.splits as? Set<TransactionSplit> ?? []
        return splitSet.sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }
    }

    private var splitMethod: SplitMethod? {
        guard let raw = transaction.splitMethod else { return nil }
        return SplitMethod(rawValue: raw)
    }

    private var isCurrentUserAPayer: Bool {
        transaction.effectivePayers.contains { CurrentUser.isCurrentUser($0.personId) }
    }

    private var payerName: String {
        let payers = transaction.effectivePayers
        if payers.count <= 1 {
            if let payer = transaction.payer, CurrentUser.isCurrentUser(payer.id) {
                return "You"
            }
            return transaction.payer?.displayName ?? "Unknown"
        }
        // Multi-payer summary
        let isUserAPayer = payers.contains { CurrentUser.isCurrentUser($0.personId) }
        if isUserAPayer {
            return "You +\(payers.count - 1) others"
        }
        return "\(payers.count) people"
    }

    private var formattedDate: String {
        guard let date = transaction.date else { return "Unknown date" }
        return DateFormatter.longDate.string(from: date)
    }

    private var participantCount: Int {
        var participants = Set<UUID>()
        // Include all payers (multi-payer support)
        for payer in transaction.effectivePayers {
            if let id = payer.personId {
                participants.insert(id)
            }
        }
        for split in splits {
            if let owedById = split.owedBy?.id {
                participants.insert(owedById)
            }
        }
        return max(participants.count, 1)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header Section
                headerSection

                // Transaction Info Card
                infoCard

                // Splits Card
                splitsCard

                // Group Card
                if transaction.group != nil {
                    groupCard
                }

                // Actions Card
                actionsCard
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.section)
        }
        .background(AppColors.backgroundSecondary)
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        HapticManager.tap()
                        showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        HapticManager.tap()
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: IconSize.md, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                }
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

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.lg) {
            // Icon
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(AppColors.backgroundTertiary)
                .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                .overlay(
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                )

            // Title
            Text(transaction.title ?? "Unknown")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            // Amount
            Text(CurrencyFormatter.format(transaction.amount))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)

            // Date pill
            Text(formattedDate)
                .font(AppTypography.footnote())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.backgroundTertiary)
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
        .padding(.horizontal, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(AppColors.cardBackground)
        )
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(spacing: 0) {
            // Paid by
            if transaction.isMultiPayer, let payerSet = transaction.payers as? Set<TransactionPayer> {
                // Multi-payer: show each payer with amount
                VStack(alignment: .leading, spacing: 0) {
                    Text("Paid by")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.sm)

                    let sortedPayers = payerSet.sorted { tp1, tp2 in
                        if CurrentUser.isCurrentUser(tp1.paidBy?.id) { return true }
                        if CurrentUser.isCurrentUser(tp2.paidBy?.id) { return false }
                        return (tp1.paidBy?.displayName ?? "") < (tp2.paidBy?.displayName ?? "")
                    }

                    ForEach(sortedPayers, id: \.objectID) { tp in
                        HStack(spacing: Spacing.sm) {
                            if let person = tp.paidBy {
                                Circle()
                                    .fill(person.avatarBackgroundColor)
                                    .frame(width: AvatarSize.xs, height: AvatarSize.xs)
                                    .overlay(
                                        Text(CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(person.avatarTextColor)
                                    )
                            }

                            Text(CurrentUser.isCurrentUser(tp.paidBy?.id) ? "You" : (tp.paidBy?.displayName ?? "Unknown"))
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            Text(CurrencyFormatter.format(tp.amount))
                                .font(AppTypography.bodyBold())
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.xs)
                    }
                }
                .padding(.bottom, Spacing.sm)
            } else {
                // Single payer
                HStack(spacing: Spacing.md) {
                    Text("Paid by")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    HStack(spacing: Spacing.sm) {
                        if let payer = transaction.payer {
                            Circle()
                                .fill(payer.avatarBackgroundColor)
                                .frame(width: AvatarSize.xs, height: AvatarSize.xs)
                                .overlay(
                                    Text(CurrentUser.isCurrentUser(payer.id) ? CurrentUser.initials : payer.initials)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(payer.avatarTextColor)
                                )
                        }
                        Text(payerName)
                            .font(AppTypography.bodyBold())
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }

            Divider()
                .padding(.leading, Spacing.lg)

            // Split Method
            HStack {
                Text("Split Method")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                HStack(spacing: Spacing.xs) {
                    if let method = splitMethod {
                        Image(systemName: method.systemImage)
                            .font(.system(size: IconSize.sm))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Text(splitMethod?.displayName ?? "Equal")
                        .font(AppTypography.bodyBold())
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            Divider()
                .padding(.leading, Spacing.lg)

            // Participants
            HStack {
                Text("Participants")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("\(participantCount) people")
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            // Note (if present)
            if let note = transaction.note, !note.isEmpty {
                Divider()
                    .padding(.leading, Spacing.lg)

                HStack(alignment: .top) {
                    Text("Note")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(note)
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }

    // MARK: - Splits Card

    private var splitsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("Split Breakdown")
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)

            Divider()
                .padding(.leading, Spacing.lg)

            if splits.isEmpty {
                HStack {
                    Spacer()
                    Text("No split details available")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .padding(.vertical, Spacing.xxl)
            } else {
                ForEach(splits, id: \.objectID) { split in
                    splitRow(split)

                    if split != splits.last {
                        Divider()
                            .padding(.leading, Spacing.lg + AvatarSize.sm + Spacing.md)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }

    private func splitRow(_ split: TransactionSplit) -> some View {
        HStack(spacing: Spacing.md) {
            // Person avatar
            if let person = split.owedBy {
                Circle()
                    .fill(person.avatarBackgroundColor)
                    .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                    .overlay(
                        Text(CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(person.avatarTextColor)
                    )
            } else {
                Circle()
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                    .overlay(
                        Text("?")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    )
            }

            // Person name and percentage
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(personDisplayName(for: split))
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)

                if transaction.amount > 0 {
                    let percentage = (split.amount / transaction.amount) * 100
                    Text(String(format: "%.1f%% of total", percentage))
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            // Amount owed
            Text(CurrencyFormatter.format(split.amount))
                .font(AppTypography.amount())
                .foregroundColor(splitAmountColor(for: split))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
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
            return isCurrentUserAPayer ? AppColors.textSecondary : AppColors.negative
        } else {
            return isCurrentUserAPayer ? AppColors.positive : AppColors.textSecondary
        }
    }

    // MARK: - Group Card

    private var groupCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Group")
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)

            Divider()
                .padding(.leading, Spacing.lg)

            if let group = transaction.group {
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color(hex: group.colorHex ?? "#808080").opacity(0.2))
                        .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: group.colorHex ?? "#808080"))
                        )

                    Text(group.name ?? "Unknown Group")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    let memberCount = (group.members as? Set<Person>)?.count ?? 0
                    Text("\(memberCount) members")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: 0) {
            Button {
                HapticManager.tap()
                showingEditSheet = true
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "pencil")
                        .font(.system(size: IconSize.md, weight: .medium))
                        .foregroundColor(AppColors.accent)
                        .frame(width: IconSize.lg)

                    Text("Edit Transaction")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: IconSize.xs, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, Spacing.lg + IconSize.lg + Spacing.md)

            Button {
                HapticManager.tap()
                showingDeleteAlert = true
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "trash")
                        .font(.system(size: IconSize.md, weight: .medium))
                        .foregroundColor(AppColors.negative)
                        .frame(width: IconSize.lg)

                    Text("Delete Transaction")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.negative)

                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
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
