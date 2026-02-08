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

    // MARK: - Entrance Animation States

    @State private var hasAnimated = false
    @State private var headerVisible = false
    @State private var infoVisible = false
    @State private var paymentVisible = false
    @State private var impactVisible = false
    @State private var breakdownVisible = false
    @State private var groupVisible = false

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
                let base = AppAnimation.staggerBaseDelay
                let stagger = AppAnimation.staggerInterval

                // Header: Icon + Name + Amount + Type
                detailHeaderSection
                    .padding(.bottom, Spacing.lg)
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : 10)
                    .animation(AppAnimation.contentReveal.delay(base), value: headerVisible)

                detailDottedSeparator
                    .opacity(infoVisible ? 1 : 0)
                    .animation(AppAnimation.contentReveal.delay(base + stagger), value: infoVisible)

                // Transaction details: ID, Date, Time
                detailInfoSection
                    .padding(.vertical, Spacing.lg)
                    .opacity(infoVisible ? 1 : 0)
                    .offset(y: infoVisible ? 0 : 10)
                    .animation(AppAnimation.contentReveal.delay(base + stagger), value: infoVisible)

                detailDottedSeparator
                    .opacity(paymentVisible ? 1 : 0)
                    .animation(AppAnimation.contentReveal.delay(base + stagger * 2), value: paymentVisible)

                // Payment & Split info
                detailPaymentSection
                    .padding(.vertical, Spacing.lg)
                    .opacity(paymentVisible ? 1 : 0)
                    .offset(y: paymentVisible ? 0 : 10)
                    .animation(AppAnimation.contentReveal.delay(base + stagger * 2), value: paymentVisible)

                detailDottedSeparator
                    .opacity(impactVisible ? 1 : 0)
                    .animation(AppAnimation.contentReveal.delay(base + stagger * 3), value: impactVisible)

                // Net impact + Note
                detailNetImpactSection
                    .padding(.vertical, Spacing.lg)
                    .opacity(impactVisible ? 1 : 0)
                    .offset(y: impactVisible ? 0 : 10)
                    .animation(AppAnimation.contentReveal.delay(base + stagger * 3), value: impactVisible)

                // Split breakdown
                if !cachedSplits.isEmpty {
                    detailDottedSeparator
                        .opacity(breakdownVisible ? 1 : 0)
                        .animation(AppAnimation.contentReveal.delay(base + stagger * 4), value: breakdownVisible)
                    detailSplitBreakdown
                        .padding(.vertical, Spacing.lg)
                        .opacity(breakdownVisible ? 1 : 0)
                        .offset(y: breakdownVisible ? 0 : 10)
                        .animation(AppAnimation.contentReveal.delay(base + stagger * 4), value: breakdownVisible)
                }

                // Group info
                if transaction.group != nil {
                    detailDottedSeparator
                        .opacity(groupVisible ? 1 : 0)
                        .animation(AppAnimation.contentReveal.delay(base + stagger * 5), value: groupVisible)
                    detailGroupSection
                        .padding(.vertical, Spacing.lg)
                        .opacity(groupVisible ? 1 : 0)
                        .offset(y: groupVisible ? 0 : 10)
                        .animation(AppAnimation.contentReveal.delay(base + stagger * 5), value: groupVisible)
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
        .onAppear { animateSectionsIn() }
        .onDisappear { resetAnimationState() }
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

    // MARK: - Entrance Animation

    private func animateSectionsIn() {
        guard !hasAnimated else { return }
        hasAnimated = true

        // Batch all visibility changes into a single withAnimation transaction.
        // Per-section stagger delays are applied via .animation() modifiers in body.
        withAnimation(AppAnimation.contentReveal) {
            headerVisible = true
            infoVisible = true
            paymentVisible = true
            impactVisible = true
            breakdownVisible = true
            groupVisible = true
        }
    }

    private func resetAnimationState() {
        hasAnimated = false
        headerVisible = false
        infoVisible = false
        paymentVisible = false
        impactVisible = false
        breakdownVisible = false
        groupVisible = false
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

// MARK: - Expanded Detail View (Hero Morphing Animation)

/// Full-screen detail overlay that morphs fluidly from the tapped transaction row.
/// Uses matchedGeometryEffect for continuous card-to-detail morphing — no cuts or fades.
struct TransactionExpandedView: View {
    @ObservedObject var transaction: FinancialTransaction
    var animationNamespace: Namespace.ID
    @Binding var selectedTransaction: FinancialTransaction?

    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Morphing Animation States

    @State private var scrimVisible = false
    @State private var contentRevealed = false
    @State private var dragIndicatorVisible = false
    @State private var section1Visible = false
    @State private var section2Visible = false
    @State private var section3Visible = false
    @State private var section4Visible = false
    @State private var section5Visible = false
    @State private var closeButtonVisible = false
    @State private var isDismissing = false

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

    private var stableId: String {
        transaction.id?.uuidString ?? transaction.objectID.uriRepresentation().absoluteString
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
    // Uses 35% of screen height for consistent feel across device sizes
    private var dragProgress: CGFloat {
        let threshold = UIScreen.main.bounds.height * 0.35
        return min(max(dragOffset / threshold, 0), 1)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dimmed scrim — fades in, interactive with drag (matched to card scale curve)
            Color.black
                .opacity(Double((scrimVisible ? 0.5 : 0) * (1 - dragProgress)))
                .ignoresSafeArea()
                .onTapGesture {
                    guard !isDismissing else { return }
                    dismissCard()
                }

            // Morphing detail card
            morphingDetailCard
                .offset(y: dragOffset)
                .scaleEffect(1 - dragProgress * 0.05, anchor: .top)
                .gesture(dismissDragGesture)
        }
        .onAppear { animateIn() }
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
                    // Natural rubber-band resistance — diminishing return on long drags
                    dragOffset = translation * 0.55
                } else {
                    // Very resistant upward drag (prevents over-scrolling the card up)
                    dragOffset = translation * 0.12
                }
            }
            .onEnded { value in
                guard !isDismissing else { return }
                let velocity = value.predictedEndTranslation.height
                // Dismiss if dragged far enough OR if velocity is high (flick gesture)
                if dragOffset > 100 || velocity > 400 {
                    dismissCard()
                } else {
                    // Snap back with a lively spring
                    withAnimation(AppAnimation.interactiveSpring) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Morphing Detail Card

    private var morphingDetailCard: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                let base = AppAnimation.staggerBaseDelay
                let stagger = AppAnimation.staggerInterval

                // Drag indicator pill
                dragIndicator
                    .opacity(dragIndicatorVisible ? 1 : 0)
                    .scaleEffect(x: dragIndicatorVisible ? 1 : 0.5, y: 1)
                    .animation(AppAnimation.cardMorph.delay(0.12), value: dragIndicatorVisible)

                // SECTION: Hero header (icon + title + amount — these morph from the row)
                heroHeaderSection

                // SECTION: Net impact badge
                netImpactBadge
                    .opacity(section1Visible ? 1 : 0)
                    .offset(y: section1Visible ? 0 : 12)
                    .animation(AppAnimation.contentReveal.delay(base), value: section1Visible)

                expandedDottedSeparator
                    .opacity(section2Visible ? 1 : 0)
                    .padding(.top, Spacing.lg)
                    .animation(AppAnimation.contentReveal.delay(base + stagger), value: section2Visible)

                // SECTION: Transaction details (date, time, ID, created by)
                detailsInfoSection
                    .opacity(section2Visible ? 1 : 0)
                    .offset(y: section2Visible ? 0 : 12)
                    .animation(AppAnimation.contentReveal.delay(base + stagger), value: section2Visible)

                expandedDottedSeparator
                    .opacity(section3Visible ? 1 : 0)
                    .animation(AppAnimation.contentReveal.delay(base + stagger * 2), value: section3Visible)

                // SECTION: Payment info (paid by, participants, split method, group)
                paymentInfoSection
                    .opacity(section3Visible ? 1 : 0)
                    .offset(y: section3Visible ? 0 : 12)
                    .animation(AppAnimation.contentReveal.delay(base + stagger * 2), value: section3Visible)

                // SECTION: Split breakdown
                if !cachedSplits.isEmpty {
                    expandedDottedSeparator
                        .opacity(section4Visible ? 1 : 0)
                        .animation(AppAnimation.contentReveal.delay(base + stagger * 3), value: section4Visible)

                    splitBreakdownSection
                        .opacity(section4Visible ? 1 : 0)
                        .offset(y: section4Visible ? 0 : 12)
                        .animation(AppAnimation.contentReveal.delay(base + stagger * 3), value: section4Visible)
                }

                // SECTION: Note
                if let note = transaction.note, !note.isEmpty {
                    expandedDottedSeparator
                        .opacity(section4Visible ? 1 : 0)
                        .animation(AppAnimation.contentReveal.delay(base + stagger * 3), value: section4Visible)

                    noteSection(note: note)
                        .opacity(section4Visible ? 1 : 0)
                        .offset(y: section4Visible ? 0 : 12)
                        .animation(AppAnimation.contentReveal.delay(base + stagger * 3), value: section4Visible)
                }

                // SECTION: Action buttons
                actionButtonsSection
                    .opacity(section5Visible ? 1 : 0)
                    .offset(y: section5Visible ? 0 : 12)
                    .padding(.top, Spacing.xl)
                    .animation(AppAnimation.contentReveal.delay(base + stagger * 4), value: section5Visible)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.section)
        }
        .background(
            RoundedRectangle(cornerRadius: contentRevealed ? CornerRadius.xl : CornerRadius.md)
                .fill(AppColors.cardBackground)
                .matchedGeometryEffect(id: "bg-\(stableId)", in: animationNamespace)
                .shadow(
                    color: Color.black.opacity(scrimVisible ? 0.18 * (1 - dragProgress * 0.4) : 0),
                    radius: contentRevealed ? 6 + 18 * (1 - dragProgress * 0.4) : 6,
                    y: contentRevealed ? 2 + 6 * (1 - dragProgress * 0.4) : 2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: contentRevealed ? CornerRadius.xl : CornerRadius.md))
        .compositingGroup()
        .scrollDisabled(!contentRevealed)
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.section + Spacing.xl)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.88)
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

    // MARK: - Hero Header (Matched Geometry)

    private var heroHeaderSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Top: Icon row with close button
            HStack(alignment: .top) {
                // Morphing icon — matches the row icon
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(amountColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: directionIcon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(amountColor)
                    )
                    .matchedGeometryEffect(id: "icon-\(stableId)", in: animationNamespace)

                Spacer()

                // Close button — fades in after morph
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
                .opacity(closeButtonVisible ? 1 : 0)
                .scaleEffect(closeButtonVisible ? 1 : 0.5)
                .animation(AppAnimation.cardMorph.delay(0.18), value: closeButtonVisible)
            }

            // Title — morphs from row position to detail position
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(transaction.title ?? "Unknown")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(3)
                    .matchedGeometryEffect(id: "title-\(stableId)", in: animationNamespace)

                // Split method label — appears after morph
                Text(splitMethod?.displayName ?? "Expense")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
                    .opacity(contentRevealed ? 1 : 0)
            }

            // Total amount — morphs from row position
            HStack(alignment: .firstTextBaseline) {
                Text(CurrencyFormatter.format(transaction.amount))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .matchedGeometryEffect(id: "amount-\(stableId)", in: animationNamespace)

                Spacer()

                // User net amount (secondary)
                Text(userAmountPrefix + CurrencyFormatter.format(abs(userNetAmount)))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(amountColor)
                    .opacity(contentRevealed ? 1 : 0)
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

    // MARK: - Animations

    private func animateIn() {
        // Phase 1: Card morph + scrim — matched geometry drives the spatial transition
        withAnimation(AppAnimation.cardMorph) {
            scrimVisible = true
            contentRevealed = true
        }

        // Phase 2: Drag indicator + close button — batched into single transaction
        // Per-element stagger applied via .animation() modifiers in the view hierarchy
        withAnimation(AppAnimation.cardMorph) {
            dragIndicatorVisible = true
            closeButtonVisible = true
        }

        // Phase 3: All staggered content sections — single transaction, per-section delays via .animation() modifiers
        withAnimation(AppAnimation.contentReveal) {
            section1Visible = true
            section2Visible = true
            section3Visible = true
            section4Visible = true
            section5Visible = true
        }
    }

    private func dismissCard() {
        guard !isDismissing else { return }
        isDismissing = true
        HapticManager.lightTap()

        // Phase 1: All inner content collapses simultaneously with fast spring
        withAnimation(AppAnimation.dismiss) {
            section5Visible = false
            section4Visible = false
            section3Visible = false
            section2Visible = false
            section1Visible = false
            closeButtonVisible = false
            dragIndicatorVisible = false
        }

        // Phase 2: Card morphs back to row position + scrim fades (slight delay for content to clear)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88).delay(0.08)) {
            contentRevealed = false
            scrimVisible = false
            dragOffset = 0
        }

        // Phase 3: Remove from view hierarchy after morph settles (0.6s provides safe margin over 480ms morph)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
