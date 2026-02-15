import CoreData
import os
import SwiftUI

struct TransactionRowView: View {
    @ObservedObject var transaction: FinancialTransaction
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    /// When true, tapping the row sets selectedTransaction to show the full-screen overlay.
    /// When false, tapping the row pushes a NavigationLink.
    var usesOverlayDetail: Bool = false
    @Binding var selectedTransaction: FinancialTransaction?

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

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
                Button {
                    HapticManager.lightTap()
                    selectedTransaction = transaction
                } label: {
                    rowContent
                }
                .buttonStyle(AppButtonStyle(haptic: .none))
            } else {
                NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                    rowContent
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .transactionRowActions(
            onEdit: { handleEdit() },
            onDelete: { handleDelete() }
        )
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

    // MARK: - Row Content

    private var rowContent: some View {
        HStack(spacing: Spacing.md) {
            iconView

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(transaction.title ?? "Unknown")
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.sm) {
                    Text(dateString)
                    Text("|")
                    Text("Paid by \(payerDisplayName)")
                        .lineLimit(1)
                }
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text(formattedAmount)
                    .font(AppTypography.financialDefault())
                    .foregroundColor(amountColor)

                Text(splitDetails)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())
    }

    // MARK: - Icon

    private var iconView: some View {
        let fillOpacity: Double = amountToShow < 0.01 ? 0.2 : 0.25
        let strokeOpacity: Double = amountToShow < 0.01 ? 0.3 : 0.4

        return RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(amountColor.opacity(fillOpacity))
            .frame(width: AvatarSize.md, height: AvatarSize.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(amountColor.opacity(strokeOpacity), lineWidth: 1)
            )
            .overlay(
                Group {
                    if amountToShow >= 0.01 {
                        Image(systemName: isPayer ? "arrow.down.left" : "arrow.up.right")
                            .font(.system(size: IconSize.md, weight: .semibold))
                            .foregroundColor(amountColor)
                    }
                }
            )
    }

    // MARK: - Amount Logic

    private var netPosition: Double {
        let userPaid = transaction.effectivePayers
            .filter { CurrentUser.isCurrentUser($0.personId) }
            .reduce(0) { $0 + $1.amount }
        let userSplit = (transaction.splits as? Set<TransactionSplit> ?? [])
            .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
            .reduce(0) { $0 + $1.amount }
        return userPaid - userSplit
    }

    private var splitDetails: String {
        let splits = transaction.splits as? Set<TransactionSplit> ?? []
        var participants = Set<UUID>()
        for payer in transaction.effectivePayers {
            if let id = payer.personId { participants.insert(id) }
        }
        for split in splits {
            if let owedById = split.owedBy?.id { participants.insert(owedById) }
        }
        let count = max(participants.count, 1)
        let formattedTotal = FinancialFormatter.currency(transaction.amount, currencyCode: transaction.effectiveCurrency)
        let peopleText = count == 1 ? "1 Person" : "\(count) People"
        return "\(formattedTotal) / \(peopleText)"
    }

    private var dateString: String {
        guard let date = transaction.date else { return "" }
        return Self.shortDateFormatter.string(from: date)
    }

    private var payerDisplayName: String {
        let payerSet = transaction.payers as? Set<TransactionPayer> ?? []

        if !payerSet.isEmpty {
            let payerPersons = payerSet.compactMap { $0.paidBy }
            let currentUserIsPayer = payerPersons.contains { CurrentUser.isCurrentUser($0.id) }

            if payerPersons.count == 1 {
                let person = payerPersons.first!
                return CurrentUser.isCurrentUser(person.id) ? "You" : person.firstName
            } else if currentUserIsPayer {
                return "You +\(payerPersons.count - 1)"
            } else {
                return "\(payerPersons.count) people"
            }
        }

        // Legacy fallback
        if let legacyPayer = transaction.payer {
            return CurrentUser.isCurrentUser(legacyPayer.id) ? "You" : legacyPayer.firstName
        }
        return "Unknown"
    }

    private var isPayer: Bool { netPosition > 0 }

    private var amountToShow: Double { abs(netPosition) }

    private var formattedAmount: String {
        FinancialFormatter.currency(amountToShow, currencyCode: transaction.effectiveCurrency)
    }

    private var amountColor: Color {
        if amountToShow < 0.01 { return AppColors.textSecondary }
        return isPayer ? AppColors.positive : AppColors.negative
    }

    // MARK: - Actions

    private func handleEdit() {
        HapticManager.lightTap()
        if let onEdit = onEdit {
            onEdit()
        } else {
            showingEditSheet = true
        }
    }

    private func handleDelete() {
        HapticManager.delete()
        if let onDelete = onDelete {
            onDelete()
        } else {
            showingDeleteAlert = true
        }
    }

    private func shareTransaction() {
        let shareText = """
        \(transaction.title ?? "Transaction")
        Amount: \(FinancialFormatter.currency(transaction.amount, currencyCode: transaction.effectiveCurrency))
        Date: \(dateString)
        \(splitDetails)
        """

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        let activityController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)

        if let popoverController = activityController.popoverPresentationController {
            popoverController.sourceView = rootViewController.view
            popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        rootViewController.present(activityController, animated: true)
    }

    private func deleteTransaction() {
        guard let context = transaction.managedObjectContext else { return }

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

// MARK: - Transaction Row Actions Modifier

private struct TransactionRowActionsModifier: ViewModifier {
    let onEdit: () -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(AppColors.accent)
            }
            .contextMenu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit Transaction", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Transaction", systemImage: "trash")
                }
            }
    }
}

extension View {
    fileprivate func transactionRowActions(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        modifier(TransactionRowActionsModifier(onEdit: onEdit, onDelete: onDelete))
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
