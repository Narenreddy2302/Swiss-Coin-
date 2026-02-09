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

    // MARK: - Computed Properties (Cached)

    /// Cached effectivePayers to avoid repeated NSSet→Array conversions during animation render passes
    private var cachedEffectivePayers: [(personId: UUID?, amount: Double)] {
        transaction.effectivePayers
    }

    /// Cached and sorted splits to avoid re-sorting on every render pass
    private var cachedSplits: [TransactionSplit] {
        let splitSet = transaction.splits as? Set<TransactionSplit> ?? []
        return splitSet.sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }
    }

    private var isPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
    }

    private var splitMethod: SplitMethod? {
        guard let raw = transaction.splitMethod else { return nil }
        return SplitMethod(rawValue: raw)
    }

    private var isCurrentUserAPayer: Bool {
        cachedEffectivePayers.contains { CurrentUser.isCurrentUser($0.personId) }
    }

    private var payerName: String {
        TransactionDetailHelpers.payerName(effectivePayers: cachedEffectivePayers, payer: transaction.payer)
    }

    private var participantCount: Int {
        TransactionDetailHelpers.participantCount(effectivePayers: cachedEffectivePayers, splits: cachedSplits)
    }

    private var userNetAmount: Double {
        TransactionDetailHelpers.userNetAmount(effectivePayers: cachedEffectivePayers, splits: cachedSplits)
    }

    private var netAmountColor: Color {
        TransactionDetailHelpers.netAmountColor(for: userNetAmount)
    }

    private var formattedReceiptDate: String {
        transaction.date?.receiptFormatted ?? "Unknown date"
    }

    private var headerSubtitle: String {
        "\(CurrencyFormatter.format(transaction.amount)) / \(participantCount) People"
    }

    private var creatorName: String {
        TransactionDetailHelpers.creatorName(transaction: transaction)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                receiptHeaderSection
                    .padding(.bottom, Spacing.lg)

                detailDottedSeparator

                receiptPaymentSection
                    .padding(.vertical, Spacing.lg)

                if !cachedSplits.isEmpty {
                    detailDottedSeparator
                    receiptSplitBreakdown
                        .padding(.vertical, Spacing.lg)
                }

                if let note = transaction.note, !note.isEmpty {
                    detailDottedSeparator
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("NOTE")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textTertiary)
                        Text(note)
                            .font(AppTypography.subheadline())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.vertical, Spacing.lg)
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(AppColors.cardBackground)
            )
            .compositingGroup()
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

    // MARK: - Receipt Header

    private var receiptHeaderSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(transaction.title ?? "Unknown")
                    .font(AppTypography.headingLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: Spacing.md)

                Text(CurrencyFormatter.formatAbsolute(userNetAmount))
                    .font(AppTypography.financialLarge())
                    .foregroundColor(netAmountColor)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(formattedReceiptDate)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)

                Spacer(minLength: Spacing.md)

                Text(headerSubtitle)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // MARK: - Receipt Payment Section

    private var receiptPaymentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("PAYMENT")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)

            if transaction.isMultiPayer, let payerSet = transaction.payers as? Set<TransactionPayer> {
                let sortedPayers = payerSet.sorted { tp1, tp2 in
                    if CurrentUser.isCurrentUser(tp1.paidBy?.id) { return true }
                    if CurrentUser.isCurrentUser(tp2.paidBy?.id) { return false }
                    return (tp1.paidBy?.displayName ?? "") < (tp2.paidBy?.displayName ?? "")
                }
                ForEach(sortedPayers, id: \.objectID) { tp in
                    receiptKeyValueRow(
                        label: "Paid by",
                        value: CurrentUser.isCurrentUser(tp.paidBy?.id)
                            ? "You" : (tp.paidBy?.displayName ?? "Unknown")
                    )
                }
            } else {
                receiptKeyValueRow(label: "Paid by", value: payerName)
            }

            receiptKeyValueRow(label: "Created by", value: creatorName)
            receiptKeyValueRow(label: "Participants", value: "\(participantCount) People")

            HStack {
                Text("Split method")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                HStack(spacing: Spacing.xs) {
                    if let method = splitMethod {
                        Text(method.icon)
                            .font(AppTypography.subheadlineMedium())
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Text(splitMethod?.displayName ?? "Equally")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            if let group = transaction.group {
                receiptKeyValueRow(label: "Group", value: group.name ?? "Unknown Group")
            }
        }
    }

    // MARK: - Receipt Split Breakdown

    private var receiptSplitBreakdown: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("SPLIT BREAKDOWN")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)

            ForEach(cachedSplits, id: \.objectID) { split in
                HStack {
                    Text(personDisplayName(for: split))
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    HStack(spacing: Spacing.xs) {
                        Text(CurrencyFormatter.currencySymbol)
                            .font(AppTypography.subheadline())
                            .foregroundColor(AppColors.textSecondary)
                        Text(CurrencyFormatter.formatDecimal(split.amount))
                            .font(AppTypography.financialDefault())
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }

            detailDottedSeparator

            HStack {
                Text("Total Balance")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.currencySymbol)
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                    Text(CurrencyFormatter.formatDecimal(transaction.amount))
                        .font(AppTypography.financialDefault())
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            detailDottedSeparator
        }
    }

    // MARK: - Dotted Separator

    private var detailDottedSeparator: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundColor(AppColors.separator)
            .frame(height: 1)
    }

    // MARK: - Helpers

    private func receiptKeyValueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(AppColors.textPrimary)
        }
    }

    private func personDisplayName(for split: TransactionSplit) -> String {
        TransactionDetailHelpers.personDisplayName(for: split)
    }

    private func splitAmountColor(for split: TransactionSplit) -> Color {
        TransactionDetailHelpers.splitAmountColor(for: split, isCurrentUserAPayer: isCurrentUserAPayer)
    }

    // MARK: - Delete Action

    private func deleteTransaction() {
        HapticManager.delete()

        if let splits = transaction.splits as? Set<TransactionSplit> {
            splits.forEach { viewContext.delete($0) }
        }

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

// MARK: - Sheet Content Height Preference Key

private struct SheetContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Bottom Sheet Transaction Detail View

/// Bottom sheet detail view that slides up from the bottom when a transaction row is tapped.
/// Sizes itself dynamically based on content, only scrolling when content exceeds available space.
struct TransactionExpandedView: View {
    @ObservedObject var transaction: FinancialTransaction
    var animationNamespace: Namespace.ID? = nil
    @Binding var selectedTransaction: FinancialTransaction?

    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - View State

    @State private var isDismissing = false
    @State private var isVisible = false
    @State private var contentHeight: CGFloat = 0

    // Drag-to-dismiss
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    @State private var isAtTop = true

    // MARK: - Computed Properties (Cached)

    /// Cached effectivePayers to avoid repeated NSSet→Array conversions during animation render passes
    private var cachedEffectivePayers: [(personId: UUID?, amount: Double)] {
        transaction.effectivePayers
    }

    /// Cached and sorted splits to avoid re-sorting on every render pass
    private var cachedSplits: [TransactionSplit] {
        let splitSet = transaction.splits as? Set<TransactionSplit> ?? []
        return splitSet.sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }
    }

    private var splitMethod: SplitMethod? {
        guard let raw = transaction.splitMethod else { return nil }
        return SplitMethod(rawValue: raw)
    }

    private var isCurrentUserAPayer: Bool {
        cachedEffectivePayers.contains { CurrentUser.isCurrentUser($0.personId) }
    }

    private var payerName: String {
        TransactionDetailHelpers.payerName(effectivePayers: cachedEffectivePayers, payer: transaction.payer)
    }

    private var creatorName: String {
        TransactionDetailHelpers.creatorName(transaction: transaction)
    }

    private var participantCount: Int {
        TransactionDetailHelpers.participantCount(effectivePayers: cachedEffectivePayers, splits: cachedSplits)
    }

    private var userNetAmount: Double {
        TransactionDetailHelpers.userNetAmount(effectivePayers: cachedEffectivePayers, splits: cachedSplits)
    }

    private var netAmountColor: Color {
        TransactionDetailHelpers.netAmountColor(for: userNetAmount)
    }

    private var formattedReceiptDate: String {
        transaction.date?.receiptFormatted ?? "Unknown date"
    }

    private var headerSubtitle: String {
        "\(CurrencyFormatter.format(transaction.amount)) / \(participantCount) People"
    }

    // Drag progress for interactive dismiss (0 = no drag, 1 = fully dragged)
    private var dragProgress: CGFloat {
        let threshold: CGFloat = 300
        return min(max(dragOffset / threshold, 0), 1)
    }

    /// Height of the drag indicator area when rendered outside ScrollView
    private var dragIndicatorAreaHeight: CGFloat {
        Spacing.md + Spacing.sm + 5 + Spacing.lg
    }

    private var bottomSafeAreaInset: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else { return 0 }
        return window.safeAreaInsets.bottom
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let safeBottom = bottomSafeAreaInset
            let maxContentHeight = geometry.size.height - Spacing.section - safeBottom
            let resolvedContentHeight = contentHeight > 0
                ? min(contentHeight, maxContentHeight)
                : maxContentHeight
            let totalSheetHeight = resolvedContentHeight + safeBottom

            ZStack(alignment: .bottom) {
                // Dimmed scrim
                AppColors.scrim
                    .opacity(isVisible ? AppColors.scrimOpacity * (1 - dragProgress) : 0)
                    .ignoresSafeArea()
                    .onTapGesture {
                        guard !isDismissing else { return }
                        dismissCard()
                    }
                    .animation(.easeOut(duration: 0.25), value: isVisible)

                // Bottom sheet
                VStack(spacing: 0) {
                    // Drag indicator outside ScrollView for reliable gesture response
                    dragIndicator

                    ScrollView(showsIndicators: false) {
                        sheetScrollContent
                            .background(
                                GeometryReader { contentGeo in
                                    Color.clear.preference(
                                        key: SheetContentHeightKey.self,
                                        value: contentGeo.size.height
                                    )
                                }
                            )
                            .background(
                                GeometryReader { scrollGeo in
                                    Color.clear.preference(
                                        key: ScrollOffsetKey.self,
                                        value: scrollGeo.frame(in: .named("sheetScroll")).minY
                                    )
                                }
                            )
                    }
                    .coordinateSpace(name: "sheetScroll")
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDisabled(dragOffset > 0)
                    .frame(height: max(resolvedContentHeight - dragIndicatorAreaHeight, 0))

                    // Bottom safe area fill
                    Color.clear
                        .frame(height: safeBottom)
                }
                .frame(maxWidth: .infinity)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: CornerRadius.xl,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: CornerRadius.xl
                    )
                    .fill(AppColors.cardBackground)
                    .shadow(color: AppColors.scrim.opacity(0.15), radius: 20, y: -4)
                )
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: CornerRadius.xl,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: CornerRadius.xl
                    )
                )
                .offset(y: isVisible ? dragOffset : totalSheetHeight + safeBottom)
                .scaleEffect(1 - dragProgress * 0.04, anchor: .top)
                .simultaneousGesture(dismissDragGesture)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onPreferenceChange(SheetContentHeightKey.self) { height in
            contentHeight = height + dragIndicatorAreaHeight
        }
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            isAtTop = offset >= -1
        }
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                    isVisible = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TransactionEditView(transaction: transaction)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteTransaction() }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { HapticManager.tap() }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Drag-to-Dismiss Gesture

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                guard !isDismissing else { return }
                let translation = value.translation.height

                // Only engage dismiss when scroll is at top or already dragging
                guard isAtTop || dragOffset > 0 else { return }

                if translation > 0 {
                    // Rubber-band effect: diminishing returns as drag increases
                    let newOffset = pow(translation, 0.78)

                    // Haptic when crossing dismiss threshold
                    if dragOffset <= 80 && newOffset > 80 {
                        HapticManager.lightTap()
                    }

                    dragOffset = newOffset
                } else if dragOffset > 0 {
                    // Pulling back up while in dismiss drag
                    dragOffset = max(pow(max(translation, 0), 0.78), 0)
                }
            }
            .onEnded { value in
                guard !isDismissing else { return }
                let velocity = value.velocity.height

                // Dismiss if dragged far enough or flicked down fast
                if dragOffset > 80 || (velocity > 600 && dragOffset > 10) {
                    dismissCard()
                } else if dragOffset > 0 {
                    // Snap back with spring
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Sheet Content

    private var sheetScrollContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            receiptHeroHeader

            expandedDottedSeparator

            receiptPaymentSection
                .padding(.vertical, Spacing.lg)

            if !cachedSplits.isEmpty {
                expandedDottedSeparator
                receiptSplitBreakdown
                    .padding(.vertical, Spacing.lg)
            }

            if let note = transaction.note, !note.isEmpty {
                expandedDottedSeparator
                noteSection(note: note)
            }

            actionButtonsSection
                .padding(.top, Spacing.xl)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.section)
    }

    // MARK: - Drag Indicator

    private var dragIndicator: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 3)
                .fill(AppColors.textTertiary.opacity(0.5))
                .frame(width: 40, height: 5)
            Spacer()
        }
        .padding(.top, Spacing.md + Spacing.sm)
        .padding(.bottom, Spacing.lg)
        .padding(.horizontal, Spacing.xl)
        .contentShape(Rectangle())
    }

    // MARK: - Receipt Hero Header

    private var receiptHeroHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Row 1: Title + Net Amount
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(transaction.title ?? "Unknown")
                        .font(AppTypography.headingLarge())
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(3)

                    Spacer(minLength: Spacing.md)

                    Text(CurrencyFormatter.formatAbsolute(userNetAmount))
                        .font(AppTypography.financialLarge())
                        .foregroundColor(netAmountColor)
                }

                // Row 2: Date + Total / People
                HStack(alignment: .firstTextBaseline) {
                    Text(formattedReceiptDate)
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)

                    Spacer(minLength: Spacing.md)

                    Text(headerSubtitle)
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Receipt Payment Section

    private var receiptPaymentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("PAYMENT")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)

            if transaction.isMultiPayer, let payerSet = transaction.payers as? Set<TransactionPayer> {
                let sortedPayers = payerSet.sorted { tp1, tp2 in
                    if CurrentUser.isCurrentUser(tp1.paidBy?.id) { return true }
                    if CurrentUser.isCurrentUser(tp2.paidBy?.id) { return false }
                    return (tp1.paidBy?.displayName ?? "") < (tp2.paidBy?.displayName ?? "")
                }
                ForEach(sortedPayers, id: \.objectID) { tp in
                    receiptKeyValueRow(
                        label: "Paid by",
                        value: CurrentUser.isCurrentUser(tp.paidBy?.id)
                            ? "You" : (tp.paidBy?.displayName ?? "Unknown")
                    )
                }
            } else {
                receiptKeyValueRow(label: "Paid by", value: payerName)
            }

            receiptKeyValueRow(label: "Created by", value: creatorName)
            receiptKeyValueRow(label: "Participants", value: "\(participantCount) People")

            HStack {
                Text("Split method")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                HStack(spacing: Spacing.xs) {
                    if let method = splitMethod {
                        Text(method.icon)
                            .font(AppTypography.subheadlineMedium())
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Text(splitMethod?.displayName ?? "Equally")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            if let group = transaction.group {
                receiptKeyValueRow(label: "Group", value: group.name ?? "Unknown Group")
            }
        }
    }

    // MARK: - Receipt Split Breakdown

    private var receiptSplitBreakdown: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("SPLIT BREAKDOWN")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)

            ForEach(cachedSplits, id: \.objectID) { split in
                HStack {
                    Text(personDisplayName(for: split))
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    HStack(spacing: Spacing.xs) {
                        Text(CurrencyFormatter.currencySymbol)
                            .font(AppTypography.subheadline())
                            .foregroundColor(AppColors.textSecondary)
                        Text(CurrencyFormatter.formatDecimal(split.amount))
                            .font(AppTypography.financialDefault())
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }

            expandedDottedSeparator

            HStack {
                Text("Total Balance")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.currencySymbol)
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                    Text(CurrencyFormatter.formatDecimal(transaction.amount))
                        .font(AppTypography.financialDefault())
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            expandedDottedSeparator
        }
    }

    // MARK: - Note Section

    private func noteSection(note: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("NOTE")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)
                .padding(.top, Spacing.md)

            Text(note)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                HapticManager.tap()
                showingEditSheet = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                    Text("Edit Transaction")
                        .font(AppTypography.bodyBold())
                }
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.md)
                .background(AppColors.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }

            Button {
                HapticManager.tap()
                showingDeleteAlert = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                    Text("Delete Transaction")
                        .font(AppTypography.bodyBold())
                }
                .foregroundColor(AppColors.negative)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.md)
                .background(AppColors.negative.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
        }
    }

    // MARK: - Dotted Separator

    private var expandedDottedSeparator: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundColor(AppColors.separator)
            .frame(height: 1)
    }

    // MARK: - Dismiss

    private func dismissCard() {
        guard !isDismissing else { return }
        isDismissing = true
        HapticManager.lightTap()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dragOffset = 0
            selectedTransaction = nil
        }
    }

    // MARK: - Helpers

    private func receiptKeyValueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(AppColors.textPrimary)
        }
    }

    private func personDisplayName(for split: TransactionSplit) -> String {
        TransactionDetailHelpers.personDisplayName(for: split)
    }

    private func splitAmountColor(for split: TransactionSplit) -> Color {
        TransactionDetailHelpers.splitAmountColor(for: split, isCurrentUserAPayer: isCurrentUserAPayer)
    }

    // MARK: - Delete Action

    private func deleteTransaction() {
        HapticManager.delete()

        if let splits = transaction.splits as? Set<TransactionSplit> {
            splits.forEach { viewContext.delete($0) }
        }
        viewContext.delete(transaction)

        do {
            try viewContext.save()
            HapticManager.success()
            dismissCard()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to delete transaction: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Line Shape for Dotted Separator

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Shared Transaction Detail Helpers

/// Shared helper functions used by both TransactionDetailView and TransactionExpandedView
/// to eliminate duplicated logic across the two views.
enum TransactionDetailHelpers {
    static func personDisplayName(for split: TransactionSplit) -> String {
        guard let person = split.owedBy else { return "Unknown" }
        if CurrentUser.isCurrentUser(person.id) { return "You" }
        return person.displayName
    }

    static func splitAmountColor(for split: TransactionSplit, isCurrentUserAPayer: Bool) -> Color {
        guard let person = split.owedBy else { return AppColors.textPrimary }
        if CurrentUser.isCurrentUser(person.id) {
            return isCurrentUserAPayer ? AppColors.textSecondary : AppColors.negative
        } else {
            return isCurrentUserAPayer ? AppColors.positive : AppColors.textSecondary
        }
    }

    static func payerName(effectivePayers: [(personId: UUID?, amount: Double)], payer: Person?) -> String {
        if effectivePayers.count <= 1 {
            if let payer = payer, CurrentUser.isCurrentUser(payer.id) {
                return "You"
            }
            return payer?.displayName ?? "Unknown"
        }
        let isUserAPayer = effectivePayers.contains { CurrentUser.isCurrentUser($0.personId) }
        if isUserAPayer {
            return "You +\(effectivePayers.count - 1) others"
        }
        return "\(effectivePayers.count) people"
    }

    static func participantCount(effectivePayers: [(personId: UUID?, amount: Double)], splits: [TransactionSplit]) -> Int {
        var participants = Set<UUID>()
        for payer in effectivePayers {
            if let id = payer.personId { participants.insert(id) }
        }
        for split in splits {
            if let owedById = split.owedBy?.id { participants.insert(owedById) }
        }
        return max(participants.count, 1)
    }

    static func userNetAmount(effectivePayers: [(personId: UUID?, amount: Double)], splits: [TransactionSplit]) -> Double {
        let userPaid = effectivePayers
            .filter { CurrentUser.isCurrentUser($0.personId) }
            .reduce(0) { $0 + $1.amount }
        let userSplit = splits
            .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
            .reduce(0) { $0 + $1.amount }
        return userPaid - userSplit
    }

    static func netAmountColor(for netAmount: Double) -> Color {
        if netAmount > 0.01 { return AppColors.positive }
        if netAmount < -0.01 { return AppColors.negative }
        return AppColors.neutral
    }

    static func creatorName(transaction: FinancialTransaction) -> String {
        let creator = transaction.createdBy ?? transaction.payer
        if let creatorId = creator?.id, CurrentUser.isCurrentUser(creatorId) {
            return "You"
        }
        return creator?.displayName ?? "Unknown"
    }
}
