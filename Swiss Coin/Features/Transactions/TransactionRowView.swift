import CoreData
import os
import SwiftUI

struct TransactionRowView: View {
    let transaction: FinancialTransaction
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    // Hero animation support — optional so the row stays reusable in HomeView / SearchView
    var animationNamespace: Namespace.ID? = nil
    @Binding var selectedTransaction: FinancialTransaction?

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    // MARK: - Initializers

    /// Full initializer with hero animation support (used in TransactionHistoryView)
    init(
        transaction: FinancialTransaction,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        animationNamespace: Namespace.ID? = nil,
        selectedTransaction: Binding<FinancialTransaction?> = .constant(nil)
    ) {
        self.transaction = transaction
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.animationNamespace = animationNamespace
        self._selectedTransaction = selectedTransaction
    }

    var body: some View {
        if animationNamespace != nil {
            heroContent
        } else {
            navigationLinkContent
        }
    }

    // MARK: - Hero Animation Content (TransactionHistoryView)

    private var heroContent: some View {
        Button {
            HapticManager.lightTap()
            withAnimation(AppAnimation.spring) {
                selectedTransaction = transaction
            }
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .applyMatchedGeometry(id: "bg-\(stableId)", namespace: animationNamespace)
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

    // MARK: - NavigationLink Content (HomeView / SearchView fallback)

    private var navigationLinkContent: some View {
        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
            rowContent
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

    // MARK: - Shared Row Content

    private var rowContent: some View {
        HStack(spacing: Spacing.md) {
            // Category Icon
            iconView

            // Main Content
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                titleView

                HStack(spacing: Spacing.xxs) {
                    Text(dateString)
                    Text("·")
                    Text("By \(creatorName)")
                        .lineLimit(1)
                }
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer(minLength: Spacing.sm)

            // Amount and Details
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                amountView

                Text(splitDetails)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Stable Identifier

    private var stableId: String {
        transaction.id?.uuidString ?? transaction.objectID.uriRepresentation().absoluteString
    }

    // MARK: - Shared Element Views

    var iconView: some View {
        RoundedRectangle(cornerRadius: CornerRadius.sm)
            .fill(amountColor.opacity(0.1))
            .frame(width: AvatarSize.md, height: AvatarSize.md)
            .overlay(
                Image(systemName: isPayer ? "arrow.up.right" : "arrow.down.left")
                    .font(.system(size: IconSize.md, weight: .medium))
                    .foregroundColor(amountColor)
            )
            .applyMatchedGeometry(id: "icon-\(stableId)", namespace: animationNamespace)
    }

    var titleView: some View {
        Text(transaction.title ?? "Unknown")
            .font(AppTypography.body())
            .foregroundColor(AppColors.textPrimary)
            .lineLimit(1)
            .applyMatchedGeometry(id: "title-\(stableId)", namespace: animationNamespace)
    }

    var amountView: some View {
        Text(amountPrefix + CurrencyFormatter.format(amountToShow))
            .font(AppTypography.amount())
            .foregroundColor(amountColor)
            .applyMatchedGeometry(id: "amount-\(stableId)", namespace: animationNamespace)
    }

    // MARK: - Helpers

    private var dateString: String {
        guard let date = transaction.date else { return "" }
        return DateFormatter.mediumDate.string(from: date)
    }

    var creatorName: String {
        // Use createdBy if available, otherwise fall back to payer for backward compatibility
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

    /// User's net position: paid - owed. Positive = others owe you.
    var userNetPosition: Double {
        let userPaid = transaction.effectivePayers
            .filter { CurrentUser.isCurrentUser($0.personId) }
            .reduce(0) { $0 + $1.amount }
        let userSplit = (transaction.splits as? Set<TransactionSplit> ?? [])
            .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
            .reduce(0) { $0 + $1.amount }
        return userPaid - userSplit
    }

    var isPayer: Bool {
        userNetPosition > 0
    }

    /// Amount others owe you (if positive net) or you owe (if negative net)
    var amountToShow: Double {
        abs(userNetPosition)
    }

    var amountPrefix: String {
        let amount = amountToShow
        if amount < 0.01 {
            return ""
        }
        return isPayer ? "+" : "-"
    }

    var amountColor: Color {
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

    var splitCount: Int {
        let splits = transaction.splits as? Set<TransactionSplit> ?? []

        // Count unique participants (payers + those who owe)
        var participants = Set<UUID>()
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

    var splitDetails: String {
        let formattedTotal = CurrencyFormatter.format(transaction.amount)
        let count = splitCount
        let peopleText = count == 1 ? "1 person" : "\(count) people"
        return "\(formattedTotal) · \(peopleText)"
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

// MARK: - Matched Geometry Helper

extension View {
    @ViewBuilder
    func applyMatchedGeometry(id: String, namespace: Namespace.ID?) -> some View {
        if let namespace = namespace {
            self.matchedGeometryEffect(id: id, in: namespace)
        } else {
            self
        }
    }
}
