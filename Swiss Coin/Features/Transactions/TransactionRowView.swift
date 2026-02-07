import CoreData
import os
import SwiftUI

struct TransactionRowView: View {
    let transaction: FinancialTransaction
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
            HStack(spacing: Spacing.md) {
                // Payer avatar
                payerAvatar

                // Main content
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(transaction.title ?? "Unknown")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: Spacing.xxs) {
                        // Payer indicator
                        Text(payerLabel)
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textTertiary)

                        Text("\u{00B7}")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textTertiary)

                        Text(dateString)
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textTertiary)

                        if splitCount > 1 {
                            Text("\u{00B7}")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textTertiary)

                            HStack(spacing: 2) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 9))
                                Text("\(splitCount)")
                                    .font(AppTypography.caption2())
                            }
                            .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }

                Spacer(minLength: Spacing.sm)

                // Amount column
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text(CurrencyFormatter.format(amountToShow))
                        .font(AppTypography.amount())
                        .foregroundColor(amountColor)

                    Text(balanceLabel)
                        .font(AppTypography.caption2())
                        .foregroundColor(amountColor.opacity(0.7))
                }
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.lg)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                HapticManager.delete()
                if let onDelete = onDelete {
                    onDelete()
                } else {
                    showingDeleteAlert = true
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                HapticManager.lightTap()
                if let onEdit = onEdit {
                    onEdit()
                } else {
                    showingEditSheet = true
                }
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(AppColors.accent)
        }
        .contextMenu {
            Button {
                HapticManager.lightTap()
                if let onEdit = onEdit {
                    onEdit()
                } else {
                    showingEditSheet = true
                }
            } label: {
                Label("Edit Transaction", systemImage: "pencil")
            }

            Button {
                HapticManager.lightTap()
                shareTransaction()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                HapticManager.delete()
                if let onDelete = onDelete {
                    onDelete()
                } else {
                    showingDeleteAlert = true
                }
            } label: {
                Label("Delete Transaction", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TransactionEditView(transaction: transaction)
        }
        .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTransaction()
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
    }

    // MARK: - Payer Avatar

    private var payerAvatar: some View {
        ZStack {
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

            // Direction indicator
            Circle()
                .fill(isPayer ? AppColors.positive : AppColors.negative)
                .frame(width: 14, height: 14)
                .overlay(
                    Image(systemName: isPayer ? "arrow.up.right" : "arrow.down.left")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white)
                )
                .offset(x: 14, y: 14)
        }
    }

    // MARK: - Helpers

    private var dateString: String {
        guard let date = transaction.date else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return DateFormatter.mediumDate.string(from: date)
        }
    }

    private var payerLabel: String {
        if isPayer {
            return "You paid"
        } else {
            let name = transaction.payer?.firstName ?? "Someone"
            return "\(name) paid"
        }
    }

    private var balanceLabel: String {
        if isPayer {
            let amount = amountToShow
            if amount < 0.01 {
                return "settled"
            }
            return "lent"
        } else {
            let amount = amountToShow
            if amount < 0.01 {
                return "settled"
            }
            return "you owe"
        }
    }

    private var creatorName: String {
        let creator = transaction.createdBy ?? transaction.payer
        if let creatorId = creator?.id {
            if CurrentUser.isCurrentUser(creatorId) {
                return "You"
            }
            return creator?.firstName ?? "Unknown"
        }
        return "Unknown"
    }

    // MARK: - Amount Logic

    private var isPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
    }

    private var myShare: Double {
        if let splits = transaction.splits?.allObjects as? [TransactionSplit] {
            if let mySplit = splits.first(where: { CurrentUser.isCurrentUser($0.owedBy?.id) }) {
                return mySplit.amount
            }
        }
        return 0.0
    }

    /// Amount others owe you (if you paid) or you owe (if someone else paid)
    private var amountToShow: Double {
        if isPayer {
            let lentToOthers = transaction.amount - myShare
            return max(lentToOthers, 0)
        } else {
            return myShare
        }
    }

    private var amountColor: Color {
        let amount = amountToShow

        if amount < 0.01 {
            return AppColors.textSecondary
        }

        if isPayer {
            return AppColors.positive
        } else {
            return AppColors.negative
        }
    }

    private var splitCount: Int {
        let splits = transaction.splits as? Set<TransactionSplit> ?? []

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

    // MARK: - Actions

    private func shareTransaction() {
        let shareText = """
        \(transaction.title ?? "Transaction")
        Amount: \(CurrencyFormatter.format(transaction.amount))
        Date: \(dateString)
        Split between \(splitCount) people
        """

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        let activityController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)

        // For iPad
        if let popoverController = activityController.popoverPresentationController {
            popoverController.sourceView = rootViewController.view
            popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        rootViewController.present(activityController, animated: true)
    }

    private func deleteTransaction() {
        guard let context = transaction.managedObjectContext else { return }

        // Delete associated splits first
        if let splits = transaction.splits as? Set<TransactionSplit> {
            splits.forEach { context.delete($0) }
        }

        // Delete the transaction
        context.delete(transaction)

        do {
            try context.save()
            HapticManager.success()
        } catch {
            context.rollback()
            HapticManager.error()
            AppLogger.transactions.error("Failed to delete transaction: \(error.localizedDescription)")
        }
    }
}
