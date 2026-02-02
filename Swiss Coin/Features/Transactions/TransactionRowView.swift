import CoreData
import os
import SwiftUI

struct TransactionRowView: View {
    let transaction: FinancialTransaction
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var isPressed = false
    @State private var showingDetail = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
            HStack(alignment: .center, spacing: Spacing.md) {
                // Main Content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(transaction.title ?? "Unknown")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: Spacing.xxs) {
                        Text(dateString)
                        Text("|")
                        Text("Created by \(creatorName)")
                    }
                    .font(AppTypography.footnote())
                    .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Amount and Details
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text(CurrencyFormatter.format(amountToShow))
                        .font(AppTypography.amount())
                        .foregroundColor(amountColor)

                    Text(splitDetails)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.lg)
        }
        .buttonStyle(.plain)
        .background(AppColors.backgroundSecondary)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(AppAnimation.quick, value: isPressed)
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
                HapticManager.tap()
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
                HapticManager.tap()
                showingDetail = true
            } label: {
                Label("View Details", systemImage: "info.circle")
            }

            Button {
                HapticManager.tap()
                if let onEdit = onEdit {
                    onEdit()
                } else {
                    showingEditSheet = true
                }
            } label: {
                Label("Edit Transaction", systemImage: "pencil")
            }

            Button {
                HapticManager.tap()
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
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            withAnimation(AppAnimation.quick) {
                isPressed = pressing
            }
            if pressing {
                HapticManager.tap()
            }
        }, perform: {})
        .sheet(isPresented: $showingEditSheet) {
            TransactionEditView(transaction: transaction)
        }
        .navigationDestination(isPresented: $showingDetail) {
            TransactionDetailView(transaction: transaction)
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

    // MARK: - Helpers

    private var dateString: String {
        guard let date = transaction.date else { return "" }
        return DateFormatter.mediumDate.string(from: date)
    }

    private var creatorName: String {
        if let payerId = transaction.payer?.id {
            if CurrentUser.isCurrentUser(payerId) {
                return "You"
            }
            return transaction.payer?.name ?? "Unknown"
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
            // You paid - show what others owe you (total minus your share)
            let lentToOthers = transaction.amount - myShare
            return max(lentToOthers, 0)
        } else {
            // Someone else paid - show what you owe them
            return myShare
        }
    }

    private var amountColor: Color {
        let amount = amountToShow

        if amount < 0.01 {
            // Zero or negligible - use neutral color
            return AppColors.textSecondary
        }

        if isPayer {
            // You paid and are owed money - positive (green)
            return AppColors.positive
        } else {
            // You owe money - negative (red)
            return AppColors.negative
        }
    }

    private var splitCount: Int {
        let splits = transaction.splits as? Set<TransactionSplit> ?? []

        // Count unique participants (payer + those who owe)
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

    private var splitDetails: String {
        let formattedTotal = CurrencyFormatter.format(transaction.amount)
        let count = splitCount
        let peopleText = count == 1 ? "1 Person" : "\(count) People"
        return "\(formattedTotal) / \(peopleText)"
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
