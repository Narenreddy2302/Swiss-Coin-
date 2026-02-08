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

    private var isPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
    }

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

    /// The user's net impact: positive = others owe you, negative = you owe.
    private var userNetAmount: Double {
        if isPayer {
            let myShare = splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) })?.amount ?? 0
            return transaction.amount - myShare
        } else {
            let myShare = splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) })?.amount ?? 0
            return myShare > 0 ? -myShare : 0
        }
    }

    private var netAmountColor: Color {
        if userNetAmount > 0.01 {
            return AppColors.positive
        } else if userNetAmount < -0.01 {
            return AppColors.negative
        }
        return AppColors.neutral
    }

    private var netAmountText: String {
        let formatted = CurrencyFormatter.formatAbsolute(userNetAmount)
        if userNetAmount > 0.01 {
            return "You lent \(formatted)"
        } else if userNetAmount < -0.01 {
            return "You owe \(formatted)"
        }
        return "You paid your share"
    }

    private var netAmountBackgroundColor: Color {
        if userNetAmount > 0.01 {
            return AppColors.positive.opacity(0.1)
        } else if userNetAmount < -0.01 {
            return AppColors.negative.opacity(0.1)
        }
        return AppColors.backgroundTertiary
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection

                infoCard

                splitsCard

                if transaction.group != nil {
                    groupCard
                }

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
        VStack(spacing: Spacing.md) {
            // Direction-aware icon
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(netAmountColor.opacity(0.1))
                .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                .overlay(
                    Image(systemName: isPayer ? "arrow.up.right" : "arrow.down.left")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(netAmountColor)
                )

            // Title
            Text(transaction.title ?? "Unknown")
                .font(AppTypography.title3())
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            // Total amount
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

            // Net impact pill
            Text(netAmountText)
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(netAmountColor)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(netAmountBackgroundColor)
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
            infoRow(label: "Split Method") {
                HStack(spacing: Spacing.xs) {
                    if let method = splitMethod {
                        Image(systemName: method.systemImage)
                            .font(.system(size: IconSize.sm))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Text(splitMethod?.displayName ?? "Equal")
                        .font(AppTypography.body().weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            Divider()
                .padding(.leading, Spacing.lg)

            // Participants
            infoRow(label: "Participants") {
                Text("\(participantCount) people")
                    .font(AppTypography.body().weight(.bold))
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

    private func infoRow<Content: View>(label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            value()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Splits Card

    private var splitsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SPLIT BREAKDOWN")
                .font(AppTypography.footnote())
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: 0) {
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

                        if split.objectID != splits.last?.objectID {
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
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
    }

    private func splitRow(_ split: TransactionSplit) -> some View {
        HStack(spacing: Spacing.md) {
            // Person avatar — solid fill with white initials
            if let person = split.owedBy {
                Circle()
                    .fill(Color(hex: person.safeColorHex))
                    .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                    .overlay(
                        Text(CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    )
            } else {
                Circle()
                    .fill(AppColors.backgroundTertiary)
                    .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                    .overlay(
                        Text("?")
                            .font(.system(size: 12, weight: .semibold))
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
                .font(AppTypography.amountSmall())
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

    /// Color logic for split amounts:
    /// - If I paid: others' shares are green (they owe me), my own share is neutral
    /// - If someone else paid: my share is red (I owe them), others' shares are neutral
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("GROUP")
                .font(AppTypography.footnote())
                .foregroundColor(AppColors.textSecondary)

            if let group = transaction.group {
                HStack(spacing: Spacing.md) {
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
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
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(AppColors.cardBackground)
                )
            }
        }
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: Spacing.md) {
            Button {
                HapticManager.tap()
                showingEditSheet = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "pencil")
                        .font(.system(size: IconSize.sm))
                    Text("Edit Transaction")
                        .font(AppTypography.subheadlineMedium())
                }
                .foregroundColor(AppColors.textPrimary)
                .frame(height: ButtonHeight.md)
                .frame(maxWidth: .infinity)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(AppColors.separator, lineWidth: 1)
                )
            }

            Button {
                HapticManager.tap()
                showingDeleteAlert = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "trash")
                        .font(.system(size: IconSize.sm))
                    Text("Delete Transaction")
                        .font(AppTypography.subheadlineMedium())
                }
                .foregroundColor(AppColors.negative)
                .frame(height: ButtonHeight.md)
                .frame(maxWidth: .infinity)
                .background(AppColors.negative.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
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
