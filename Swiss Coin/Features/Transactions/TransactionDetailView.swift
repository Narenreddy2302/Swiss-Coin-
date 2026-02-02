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

    private var payerName: String {
        if let payer = transaction.payer, CurrentUser.isCurrentUser(payer.id) {
            return "You"
        }
        return transaction.payer?.displayName ?? "Unknown"
    }

    private var formattedDate: String {
        guard let date = transaction.date else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
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

    // MARK: - Body

    var body: some View {
        List {
            // Header Section
            headerSection

            // Transaction Info Section
            infoSection

            // Splits Section
            splitsSection

            // Group Section
            if transaction.group != nil {
                groupSection
            }

            // Actions Section
            actionsSection
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(spacing: Spacing.lg) {
                // Icon
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                    .overlay(
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.accent)
                    )

                // Title
                Text(transaction.title ?? "Unknown")
                    .font(AppTypography.title1())
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                // Amount
                Text(CurrencyFormatter.format(transaction.amount))
                    .font(AppTypography.amountLarge())
                    .foregroundColor(AppColors.textPrimary)

                // Date
                Text(formattedDate)
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
        }
        .listRowBackground(Color.clear)
    }

    private var infoSection: some View {
        Section {
            LabeledContent("Paid by") {
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
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            LabeledContent("Split Method") {
                Text(splitMethod?.displayName ?? "Equal")
                    .foregroundColor(AppColors.textSecondary)
            }

            LabeledContent("Participants") {
                Text("\(participantCount) people")
                    .foregroundColor(AppColors.textSecondary)
            }
        } header: {
            Text("Details")
                .font(AppTypography.subheadlineMedium())
        }
    }

    private var splitsSection: some View {
        Section {
            if splits.isEmpty {
                Text("No split details available")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(splits, id: \.objectID) { split in
                    splitRow(split)
                }
            }
        } header: {
            Text("Split Breakdown")
                .font(AppTypography.subheadlineMedium())
        }
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
                    .fill(AppColors.cardBackground)
                    .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                    .overlay(
                        Text("?")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    )
            }

            // Person name
            VStack(alignment: .leading, spacing: 2) {
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
                .font(AppTypography.amountSmall())
                .foregroundColor(splitAmountColor(for: split))
        }
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

    private var groupSection: some View {
        Section {
            if let group = transaction.group {
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color(hex: group.colorHex ?? "#808080").opacity(0.3))
                        .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: group.colorHex ?? "#808080"))
                        )

                    Text(group.name ?? "Unknown Group")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        } header: {
            Text("Group")
                .font(AppTypography.subheadlineMedium())
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                HapticManager.tap()
                showingEditSheet = true
            } label: {
                Label("Edit Transaction", systemImage: "pencil")
            }

            Button(role: .destructive) {
                HapticManager.tap()
                showingDeleteAlert = true
            } label: {
                Label("Delete Transaction", systemImage: "trash")
            }
        }
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
