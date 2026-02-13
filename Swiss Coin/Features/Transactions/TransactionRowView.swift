import CoreData
import os
import SwiftUI

struct TransactionRowView: View {
    let transaction: FinancialTransaction
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    /// When true, tapping the row sets selectedTransaction to show the full-screen overlay.
    /// When false, tapping the row pushes a NavigationLink.
    var usesOverlayDetail: Bool = false
    @Binding var selectedTransaction: FinancialTransaction?

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    // MARK: - Cached Values (computed once, not every render)
    @State private var cachedNetPosition: Double = 0
    @State private var cachedSplitDetails: String = ""
    @State private var cachedDateString: String = ""
    @State private var cachedCreatorName: String = ""

    // MARK: - Initializers

    /// Overlay detail initializer (used in TransactionHistoryView, HomeView, SearchView)
    init(
        transaction: FinancialTransaction,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        selectedTransaction: Binding<FinancialTransaction?>
    ) {
        self.transaction = transaction
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.usesOverlayDetail = true
        self._selectedTransaction = selectedTransaction
    }

    /// NavigationLink initializer (used when no overlay is needed)
    init(
        transaction: FinancialTransaction,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.transaction = transaction
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.usesOverlayDetail = false
        self._selectedTransaction = .constant(nil)
    }

    var body: some View {
        Group {
            if usesOverlayDetail {
                heroContent
            } else {
                navigationLinkContent
            }
        }
        .onAppear { recomputeCache() }
        .onChange(of: transaction.amount) { recomputeCache() }
    }

    private func recomputeCache() {
        let userPaid = transaction.effectivePayers
            .filter { CurrentUser.isCurrentUser($0.personId) }
            .reduce(0) { $0 + $1.amount }
        let userSplit = (transaction.splits as? Set<TransactionSplit> ?? [])
            .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
            .reduce(0) { $0 + $1.amount }
        cachedNetPosition = userPaid - userSplit

        // Split count
        let splits = transaction.splits as? Set<TransactionSplit> ?? []
        var participants = Set<UUID>()
        for payer in transaction.effectivePayers {
            if let id = payer.personId { participants.insert(id) }
        }
        for split in splits {
            if let owedById = split.owedBy?.id { participants.insert(owedById) }
        }
        let count = max(participants.count, 1)
        let formattedTotal = CurrencyFormatter.format(transaction.amount)
        let peopleText = count == 1 ? "1 person" : "\(count) people"
        cachedSplitDetails = "\(formattedTotal) · \(peopleText)"

        // Date string
        if let date = transaction.date {
            cachedDateString = DateFormatter.mediumDate.string(from: date)
        } else {
            cachedDateString = ""
        }

        // Creator name
        let creator = transaction.createdBy ?? transaction.payer
        if let creatorId = creator?.id {
            cachedCreatorName = CurrentUser.isCurrentUser(creatorId) ? "You" : (creator?.firstName ?? "Unknown")
        } else {
            cachedCreatorName = "Unknown"
        }
    }

    // MARK: - Hero Animation Content (TransactionHistoryView)

    private var heroContent: some View {
        Button {
            HapticManager.lightTap()
            selectedTransaction = transaction
        } label: {
            rowContent
        }
        .buttonStyle(AppButtonStyle(haptic: .none))
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
                    Text(cachedDateString)
                    Text("·")
                    Text("By \(cachedCreatorName)")
                        .lineLimit(1)
                }
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer(minLength: Spacing.sm)

            // Amount and Details
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                amountView

                Text(cachedSplitDetails)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
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
    }

    var titleView: some View {
        Text(transaction.title ?? "Unknown")
            .font(AppTypography.headingMedium())
            .foregroundColor(AppColors.textPrimary)
            .lineLimit(1)
    }

    var amountView: some View {
        Text(amountPrefix + CurrencyFormatter.format(amountToShow))
            .font(AppTypography.financialDefault())
            .foregroundColor(amountColor)
    }

    // MARK: - Amount Logic (derived from cached net position)

    var isPayer: Bool {
        cachedNetPosition > 0
    }

    var amountToShow: Double {
        abs(cachedNetPosition)
    }

    var amountPrefix: String {
        if amountToShow < 0.01 { return "" }
        return isPayer ? "+" : "-"
    }

    var amountColor: Color {
        if amountToShow < 0.01 { return AppColors.textSecondary }
        return isPayer ? AppColors.positive : AppColors.negative
    }

    // MARK: - Actions

    private func shareTransaction() {
        let shareText = """
        \(transaction.title ?? "Transaction")
        Amount: \(CurrencyFormatter.format(transaction.amount))
        Date: \(cachedDateString)
        \(cachedSplitDetails)
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
    func applyMatchedGeometry(id: String, namespace: Namespace.ID?, isSource: Bool = true) -> some View {
        if let namespace = namespace {
            self.matchedGeometryEffect(id: id, in: namespace, isSource: isSource)
        } else {
            self
        }
    }
}
