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

    // Content is shown immediately — no stagger animation

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

    private var shortTransactionId: String {
        guard let uuid = transaction.id else { return "N/A" }
        let hash = abs(uuid.hashValue) % 100000
        return "#\(String(format: "%05d", hash))"
    }

    private var formattedMonthDay: String {
        guard let date = transaction.date else { return "Unknown date" }
        return DateFormatter.monthDay.string(from: date)
    }

    private var formattedTime: String {
        guard let date = transaction.date else { return "" }
        return DateFormatter.timeOnly.string(from: date)
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

    private var netAmountText: String {
        TransactionDetailHelpers.netAmountText(for: userNetAmount)
    }

    private var netAmountBackgroundColor: Color {
        TransactionDetailHelpers.netAmountBackgroundColor(for: userNetAmount)
    }

    private var directionIcon: String {
        userNetAmount > 0 ? "arrow.up.right" : "arrow.down.left"
    }

    private var directionColor: Color {
        if abs(userNetAmount) < 0.01 { return AppColors.textSecondary }
        return userNetAmount > 0 ? AppColors.positive : AppColors.negative
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header: Icon + Name + Amount + Type
                detailHeaderSection
                    .padding(.bottom, Spacing.lg)

                detailDottedSeparator

                // Transaction details: ID, Date, Time
                detailInfoSection
                    .padding(.vertical, Spacing.lg)

                detailDottedSeparator

                // Payment & Split info
                detailPaymentSection
                    .padding(.vertical, Spacing.lg)

                detailDottedSeparator

                // Net impact + Note
                detailNetImpactSection
                    .padding(.vertical, Spacing.lg)

                // Split breakdown
                if !cachedSplits.isEmpty {
                    detailDottedSeparator
                    detailSplitBreakdown
                        .padding(.vertical, Spacing.lg)
                }

                // Group info
                if transaction.group != nil {
                    detailDottedSeparator
                    detailGroupSection
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

    // MARK: - Header Section

    private var detailHeaderSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Icon
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.textPrimary)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: directionIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(AppColors.cardBackground)
                )

            // Name + Amount
            HStack(alignment: .firstTextBaseline) {
                Text(transaction.title ?? "Unknown")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: Spacing.md)

                Text(CurrencyFormatter.format(transaction.amount))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }

            // Category / Split method
            Text(splitMethod?.displayName ?? "Expense")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Info Section

    private var detailInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(shortTransactionId)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)

            Text(formattedMonthDay)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)

            if !formattedTime.isEmpty {
                Text(formattedTime)
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // MARK: - Payment Section

    private var detailPaymentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if transaction.isMultiPayer, let payerSet = transaction.payers as? Set<TransactionPayer> {
                let sortedPayers = payerSet.sorted { tp1, tp2 in
                    if CurrentUser.isCurrentUser(tp1.paidBy?.id) { return true }
                    if CurrentUser.isCurrentUser(tp2.paidBy?.id) { return false }
                    return (tp1.paidBy?.displayName ?? "") < (tp2.paidBy?.displayName ?? "")
                }
                Text("Paid by multiple")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)

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
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    Text("Paid by")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                    Text(payerName)
                        .font(AppTypography.bodyBold())
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            HStack(spacing: Spacing.xxs) {
                Text("\(participantCount) people")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
                Text("·")
                    .foregroundColor(AppColors.textTertiary)
                if let method = splitMethod {
                    Image(systemName: method.systemImage)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                Text(splitMethod?.displayName ?? "Equal")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // MARK: - Net Impact Section

    private var detailNetImpactSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(netAmountText)
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(netAmountColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(netAmountBackgroundColor)
                )

            if let note = transaction.note, !note.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Note")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                    Text(note)
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Split Breakdown

    private var detailSplitBreakdown: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SPLIT BREAKDOWN")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)

            ForEach(cachedSplits, id: \.objectID) { split in
                HStack(spacing: Spacing.sm) {
                    if let person = split.owedBy {
                        Circle()
                            .fill(person.displayColor)
                            .frame(width: AvatarSize.xs, height: AvatarSize.xs)
                            .overlay(
                                Text(CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }

                    Text(personDisplayName(for: split))
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Text(CurrencyFormatter.format(split.amount))
                        .font(AppTypography.amountSmall())
                        .foregroundColor(splitAmountColor(for: split))
                }
            }
        }
    }

    // MARK: - Group Section

    private var detailGroupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let group = transaction.group {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: group.colorHex ?? "#808080"))
                    Text(group.name ?? "Unknown Group")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    let memberCount = (group.members as? Set<Person>)?.count ?? 0
                    Text("\(memberCount) members")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
            }
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

    private var shortTransactionId: String {
        guard let uuid = transaction.id else { return "N/A" }
        let hash = abs(uuid.hashValue) % 100000
        return "#\(String(format: "%05d", hash))"
    }

    private var formattedDate: String {
        guard let date = transaction.date else { return "Unknown date" }
        return DateFormatter.longDate.string(from: date)
    }

    private var formattedTime: String {
        guard let date = transaction.date else { return "" }
        return DateFormatter.timeOnly.string(from: date)
    }

    private var creatorName: String {
        let creator = transaction.createdBy ?? transaction.payer
        if let creatorId = creator?.id, CurrentUser.isCurrentUser(creatorId) {
            return "You"
        }
        return creator?.displayName ?? "Unknown"
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

    private var netAmountText: String {
        TransactionDetailHelpers.netAmountText(for: userNetAmount)
    }

    private var netAmountBackgroundColor: Color {
        TransactionDetailHelpers.netAmountBackgroundColor(for: userNetAmount)
    }

    private var directionIcon: String {
        userNetAmount > 0 ? "arrow.up.right" : "arrow.down.left"
    }

    private var amountColor: Color {
        if abs(userNetAmount) < 0.01 { return AppColors.textSecondary }
        return userNetAmount > 0 ? AppColors.positive : AppColors.negative
    }

    private var userAmountPrefix: String {
        if abs(userNetAmount) < 0.01 { return "" }
        return userNetAmount > 0 ? "+" : "-"
    }

    // Drag progress for interactive dismiss (0 = no drag, 1 = fully dragged)
    private var dragProgress: CGFloat {
        let threshold: CGFloat = 300
        return min(max(dragOffset / threshold, 0), 1)
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
                    ScrollView(showsIndicators: false) {
                        sheetContentView
                            .background(
                                GeometryReader { contentGeo in
                                    Color.clear.preference(
                                        key: SheetContentHeightKey.self,
                                        value: contentGeo.size.height
                                    )
                                }
                            )
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(height: resolvedContentHeight)

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
                .gesture(dismissDragGesture)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onPreferenceChange(SheetContentHeightKey.self) { height in
            contentHeight = height
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
                if translation > 0 {
                    dragOffset = translation * 0.7
                } else {
                    dragOffset = translation * 0.1
                }
            }
            .onEnded { value in
                guard !isDismissing else { return }
                let velocity = value.predictedEndTranslation.height
                if dragOffset > 100 || velocity > 400 {
                    dismissCard()
                } else {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Sheet Content

    private var sheetContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag indicator pill
            dragIndicator

            // SECTION: Header (icon + title + amount)
            heroHeaderSection

            // SECTION: Net impact badge
            netImpactBadge

            expandedDottedSeparator
                .padding(.top, Spacing.lg)

            // SECTION: Transaction details (date, time, ID, created by)
            detailsInfoSection

            expandedDottedSeparator

            // SECTION: Payment info (paid by, participants, split method, group)
            paymentInfoSection

            // SECTION: Split breakdown
            if !cachedSplits.isEmpty {
                expandedDottedSeparator

                splitBreakdownSection
            }

            // SECTION: Note
            if let note = transaction.note, !note.isEmpty {
                expandedDottedSeparator

                noteSection(note: note)
            }

            // SECTION: Action buttons
            actionButtonsSection
                .padding(.top, Spacing.xl)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.section)
    }

    // MARK: - Drag Indicator

    private var dragIndicator: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 3)
                .fill(AppColors.separator)
                .frame(width: 36, height: 5)
            Spacer()
        }
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Header Section

    private var heroHeaderSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Top: Icon row with close button
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(amountColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: directionIcon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(amountColor)
                    )

                Spacer()

                // Close button
                Button {
                    guard !isDismissing else { return }
                    HapticManager.lightTap()
                    dismissCard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(
                            AppColors.textTertiary,
                            AppColors.backgroundTertiary
                        )
                }
            }

            // Title
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(transaction.title ?? "Unknown")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(3)

                Text(splitMethod?.displayName ?? "Expense")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
            }

            // Total amount
            HStack(alignment: .firstTextBaseline) {
                Text(CurrencyFormatter.format(transaction.amount))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                // User net amount
                Text(userAmountPrefix + CurrencyFormatter.format(abs(userNetAmount)))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(amountColor)
            }
        }
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Net Impact Badge

    private var netImpactBadge: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: directionIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(netAmountColor)

            Text(netAmountText)
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(netAmountColor)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(netAmountBackgroundColor)
        )
        .padding(.bottom, Spacing.xs)
    }

    // MARK: - Details Info Section

    private var detailsInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("DETAILS")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)
                .padding(.top, Spacing.md)

            detailInfoRow(label: "Date", value: formattedDate)

            if !formattedTime.isEmpty {
                detailInfoRow(label: "Time", value: formattedTime)
            }

            detailInfoRow(label: "Transaction ID", value: shortTransactionId)

            detailInfoRow(label: "Created by", value: creatorName)
        }
        .padding(.bottom, Spacing.lg)
    }

    private func detailInfoRow(label: String, value: String) -> some View {
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

    // MARK: - Payment Info Section

    private var paymentInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("PAYMENT")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)
                .padding(.top, Spacing.md)

            // Paid by
            if transaction.isMultiPayer, let payerSet = transaction.payers as? Set<TransactionPayer> {
                let sortedPayers = payerSet.sorted { tp1, tp2 in
                    if CurrentUser.isCurrentUser(tp1.paidBy?.id) { return true }
                    if CurrentUser.isCurrentUser(tp2.paidBy?.id) { return false }
                    return (tp1.paidBy?.displayName ?? "") < (tp2.paidBy?.displayName ?? "")
                }

                Text("Paid by")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)

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
                }
            } else {
                detailInfoRow(label: "Paid by", value: payerName)
            }

            // Participants + Split method
            detailInfoRow(label: "Participants", value: "\(participantCount) people")

            HStack {
                Text("Split method")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                HStack(spacing: Spacing.xxs) {
                    if let method = splitMethod {
                        Image(systemName: method.systemImage)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Text(splitMethod?.displayName ?? "Equal")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            // Group info
            if let group = transaction.group {
                HStack(spacing: Spacing.sm) {
                    Text("Group")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: group.colorHex ?? "#808080"))
                        Text(group.name ?? "Unknown Group")
                            .font(AppTypography.subheadlineMedium())
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
        }
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Split Breakdown Section

    private var splitBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("SPLIT BREAKDOWN")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textTertiary)
                .padding(.top, Spacing.md)

            ForEach(cachedSplits, id: \.objectID) { split in
                HStack(spacing: Spacing.sm) {
                    if let person = split.owedBy {
                        Circle()
                            .fill(person.displayColor)
                            .frame(width: AvatarSize.xs, height: AvatarSize.xs)
                            .overlay(
                                Text(CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }

                    Text(personDisplayName(for: split))
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Text(CurrencyFormatter.format(split.amount))
                        .font(AppTypography.amountSmall())
                        .foregroundColor(splitAmountColor(for: split))
                }
            }
        }
        .padding(.bottom, Spacing.lg)
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            selectedTransaction = nil
        }
    }

    // MARK: - Helpers

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

    static func netAmountText(for netAmount: Double) -> String {
        let formatted = CurrencyFormatter.formatAbsolute(netAmount)
        if netAmount > 0.01 { return "You lent \(formatted)" }
        if netAmount < -0.01 { return "You owe \(formatted)" }
        return "You paid your share"
    }

    static func netAmountBackgroundColor(for netAmount: Double) -> Color {
        if netAmount > 0.01 { return AppColors.positive.opacity(0.12) }
        if netAmount < -0.01 { return AppColors.negative.opacity(0.12) }
        return AppColors.backgroundTertiary
    }
}
