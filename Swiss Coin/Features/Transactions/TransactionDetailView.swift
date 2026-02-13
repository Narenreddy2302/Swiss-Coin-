//
//  TransactionDetailView.swift
//  Swiss Coin
//
//  Unified transaction detail — used as both a sheet (from row tap) and a
//  pushed NavigationLink destination. Modeled after Cash App / Revolut:
//  hero amount at top, status pill, avatar-based split breakdown, staggered
//  entrance animations, and share/copy actions.
//

import CoreData
import SwiftUI

// MARK: - Precomputed Transaction State

/// All expensive Core Data traversals happen once in `init` or `recompute()`.
/// The view body reads only value types — zero faulting during render.
struct TransactionSnapshot {
    var title: String = "Unknown"
    var totalAmount: Double = 0
    var userNetAmount: Double = 0
    var formattedDate: String = ""
    var formattedTime: String = ""
    var payerName: String = ""
    var creatorName: String = ""
    var participantCount: Int = 1
    var splitMethodName: String = "Equally"
    var splitMethodIcon: String = ""
    var groupName: String? = nil
    var note: String? = nil
    var isMultiPayer: Bool = false
    var sortedPayers: [(name: String, amount: Double, isUser: Bool)] = []
    var sortedSplits: [(objectID: NSManagedObjectID, name: String, initials: String, colorHex: String, amount: Double, isUser: Bool)] = []

    var netAmountColor: Color {
        if userNetAmount > 0.01 { return AppColors.positive }
        if userNetAmount < -0.01 { return AppColors.negative }
        return AppColors.neutral
    }

    var directionIcon: String {
        userNetAmount > 0.01 ? "arrow.up.right" : "arrow.down.left"
    }

    var statusText: String {
        if userNetAmount > 0.01 { return "You are owed" }
        if userNetAmount < -0.01 { return "You owe" }
        return "Settled"
    }

    static func build(from tx: FinancialTransaction) -> TransactionSnapshot {
        var s = TransactionSnapshot()
        s.title = tx.title ?? "Unknown"
        s.totalAmount = tx.amount

        // Date + time
        if let date = tx.date {
            s.formattedDate = date.receiptFormatted
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            s.formattedTime = tf.string(from: date)
        } else {
            s.formattedDate = "Unknown date"
        }

        // Payers
        let effectivePayers = tx.effectivePayers
        s.isMultiPayer = tx.isMultiPayer

        if tx.isMultiPayer, let payerSet = tx.payers as? Set<TransactionPayer> {
            s.sortedPayers = payerSet
                .sorted { tp1, tp2 in
                    if CurrentUser.isCurrentUser(tp1.paidBy?.id) { return true }
                    if CurrentUser.isCurrentUser(tp2.paidBy?.id) { return false }
                    return (tp1.paidBy?.displayName ?? "") < (tp2.paidBy?.displayName ?? "")
                }
                .map { tp in
                    let isUser = CurrentUser.isCurrentUser(tp.paidBy?.id)
                    return (name: isUser ? "You" : (tp.paidBy?.displayName ?? "Unknown"),
                            amount: tp.amount,
                            isUser: isUser)
                }
        }

        s.payerName = TransactionDetailHelpers.payerName(effectivePayers: effectivePayers, payer: tx.payer)
        s.creatorName = TransactionDetailHelpers.creatorName(transaction: tx)

        // Splits
        let splitSet = tx.splits as? Set<TransactionSplit> ?? []
        let sorted = splitSet.sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }
        s.sortedSplits = sorted.map { split in
            let person = split.owedBy
            let isUser = CurrentUser.isCurrentUser(person?.id)
            return (objectID: split.objectID,
                    name: isUser ? "You" : (person?.displayName ?? "Unknown"),
                    initials: isUser ? "ME" : (person?.initials ?? "?"),
                    colorHex: isUser ? AppColors.defaultAvatarColorHex : (person?.colorHex ?? AppColors.defaultAvatarColorHex),
                    amount: split.amount,
                    isUser: isUser)
        }

        s.participantCount = TransactionDetailHelpers.participantCount(effectivePayers: effectivePayers, splits: sorted)
        s.userNetAmount = TransactionDetailHelpers.userNetAmount(effectivePayers: effectivePayers, splits: sorted)

        // Split method
        if let raw = tx.splitMethod, let method = SplitMethod(rawValue: raw) {
            s.splitMethodName = method.displayName
            s.splitMethodIcon = method.icon
        }

        // Group
        s.groupName = tx.group?.name

        // Note
        if let note = tx.note, !note.isEmpty {
            s.note = note
        }

        return s
    }
}

// MARK: - Unified Transaction Detail Sheet

/// Replaces both the old TransactionDetailView and TransactionExpandedView.
/// Presented as a sheet from row taps everywhere in the app, with detents
/// for a premium half-sheet → full-screen swipe experience.
struct TransactionExpandedView: View {
    @ObservedObject var transaction: FinancialTransaction
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var snap = TransactionSnapshot()
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var copiedAmount = false

    // Staggered entrance animation
    @State private var heroVisible = false
    @State private var detailsVisible = false
    @State private var splitsVisible = false
    @State private var actionsVisible = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroSection
                detailsSection
                if !snap.sortedSplits.isEmpty {
                    splitBreakdownSection
                }
                if snap.note != nil {
                    noteSection
                }
                actionsSection
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.section)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CornerRadius.xl)
        .presentationBackground(AppColors.cardBackground)
        .onAppear {
            recompute()
            HapticManager.lightTap()
            triggerEntranceAnimations()
        }
        .onChange(of: transaction.amount) { recompute() }
        .onChange(of: transaction.title) { recompute() }
        .sheet(isPresented: $showingEditSheet) {
            TransactionEditView(transaction: transaction)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func recompute() {
        guard !transaction.isDeleted, transaction.managedObjectContext != nil else { return }
        snap = TransactionSnapshot.build(from: transaction)
    }

    // MARK: - Entrance Animations

    private func triggerEntranceAnimations() {
        let base = AppAnimation.staggerBaseDelay
        let interval = AppAnimation.staggerInterval

        withAnimation(AppAnimation.contentReveal.delay(base)) {
            heroVisible = true
        }
        withAnimation(AppAnimation.contentReveal.delay(base + interval)) {
            detailsVisible = true
        }
        withAnimation(AppAnimation.contentReveal.delay(base + interval * 2)) {
            splitsVisible = true
        }
        withAnimation(AppAnimation.contentReveal.delay(base + interval * 3)) {
            actionsVisible = true
        }
    }

    // MARK: - Hero Section (Cash App style)

    private var heroSection: some View {
        VStack(spacing: Spacing.md) {
            Spacer().frame(height: Spacing.lg)

            // Direction icon circle
            ZStack {
                Circle()
                    .fill(snap.netAmountColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: snap.directionIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(snap.netAmountColor)
            }

            // Hero amount (tap to copy)
            Button {
                copyAmount()
            } label: {
                VStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.formatAbsolute(snap.userNetAmount))
                        .font(AppTypography.financialHero())
                        .tracking(AppTypography.Tracking.financialHero)
                        .foregroundColor(snap.netAmountColor)

                    if copiedAmount {
                        Text("Copied!")
                            .font(AppTypography.labelSmall())
                            .foregroundColor(AppColors.accent)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Your share: \(CurrencyFormatter.formatAbsolute(snap.userNetAmount)). Tap to copy.")

            // Status pill
            Text(snap.statusText)
                .font(AppTypography.labelDefault())
                .foregroundColor(snap.netAmountColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(snap.netAmountColor.opacity(0.1))
                )

            // Title + date
            VStack(spacing: Spacing.xxs) {
                Text(snap.title)
                    .font(AppTypography.headingLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                HStack(spacing: Spacing.xs) {
                    Text(snap.formattedDate)
                    if !snap.formattedTime.isEmpty {
                        Text("·")
                        Text(snap.formattedTime)
                    }
                }
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer().frame(height: Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .opacity(heroVisible ? 1 : 0)
        .offset(y: heroVisible ? 0 : 12)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionDivider

            VStack(alignment: .leading, spacing: Spacing.md) {
                sectionHeader("Details")

                // Payer(s)
                if snap.isMultiPayer {
                    ForEach(Array(snap.sortedPayers.enumerated()), id: \.offset) { _, payer in
                        detailRow(
                            icon: "creditcard.fill",
                            label: "Paid by",
                            value: "\(payer.name) · \(CurrencyFormatter.format(payer.amount))"
                        )
                    }
                } else {
                    detailRow(icon: "creditcard.fill", label: "Paid by", value: snap.payerName)
                }

                detailRow(icon: "person.fill", label: "Created by", value: snap.creatorName)

                detailRow(
                    icon: "person.2.fill",
                    label: "Participants",
                    value: "\(snap.participantCount) \(snap.participantCount == 1 ? "person" : "people")"
                )

                detailRow(
                    icon: "arrow.triangle.branch",
                    label: "Split",
                    value: snap.splitMethodIcon.isEmpty ? snap.splitMethodName : "\(snap.splitMethodIcon) \(snap.splitMethodName)"
                )

                detailRow(
                    icon: "banknote.fill",
                    label: "Total",
                    value: CurrencyFormatter.format(snap.totalAmount)
                )

                if let group = snap.groupName {
                    detailRow(icon: "person.3.fill", label: "Group", value: group)
                }
            }
            .padding(.vertical, Spacing.lg)
        }
        .opacity(detailsVisible ? 1 : 0)
        .offset(y: detailsVisible ? 0 : 8)
    }

    // MARK: - Split Breakdown Section

    private var splitBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionDivider

            VStack(alignment: .leading, spacing: Spacing.md) {
                sectionHeader("Split Breakdown")

                ForEach(snap.sortedSplits, id: \.objectID) { split in
                    splitRow(split)
                }

                // Total row
                HStack {
                    Text("Total")
                        .font(AppTypography.headingSmall())
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(CurrencyFormatter.format(snap.totalAmount))
                        .font(AppTypography.financialDefault())
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.top, Spacing.xs)
            }
            .padding(.vertical, Spacing.lg)
        }
        .opacity(splitsVisible ? 1 : 0)
        .offset(y: splitsVisible ? 0 : 8)
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionDivider

            VStack(alignment: .leading, spacing: Spacing.sm) {
                sectionHeader("Note")

                Text(snap.note ?? "")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Spacing.lg)
        }
        .opacity(splitsVisible ? 1 : 0)
        .offset(y: splitsVisible ? 0 : 8)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: Spacing.sm) {
            sectionDivider

            Spacer().frame(height: Spacing.md)

            // Share button
            Button {
                HapticManager.tap()
                shareTransaction()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                    Text("Share")
                        .font(AppTypography.buttonDefault())
                }
                .foregroundColor(AppColors.accent)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.md)
                .background(AppColors.accentMuted)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
            }

            // Edit button
            Button {
                HapticManager.tap()
                showingEditSheet = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                    Text("Edit Transaction")
                        .font(AppTypography.buttonDefault())
                }
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.md)
                .background(AppColors.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
            }

            // Delete button
            Button {
                HapticManager.warning()
                showingDeleteAlert = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                    Text("Delete Transaction")
                        .font(AppTypography.buttonDefault())
                }
                .foregroundColor(AppColors.negative)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.md)
                .background(AppColors.negative.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
            }
        }
        .opacity(actionsVisible ? 1 : 0)
        .offset(y: actionsVisible ? 0 : 8)
    }

    // MARK: - Reusable Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.headingSmall())
            .foregroundColor(AppColors.textTertiary)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(AppColors.separator)
            .frame(height: 0.5)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 20, alignment: .center)

            Text(label)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
    }

    private func splitRow(_ split: (objectID: NSManagedObjectID, name: String, initials: String, colorHex: String, amount: Double, isUser: Bool)) -> some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            Circle()
                .fill(Color(hex: split.colorHex).opacity(split.isUser ? 0.15 : 0.12))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(split.initials)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: split.colorHex))
                )

            Text(split.name)
                .font(split.isUser ? AppTypography.headingSmall() : AppTypography.bodyDefault())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(CurrencyFormatter.format(split.amount))
                .font(AppTypography.financialDefault())
                .foregroundColor(split.isUser ? snap.netAmountColor : AppColors.textPrimary)
        }
        .padding(.vertical, Spacing.xxs)
        .background(
            split.isUser
                ? RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(snap.netAmountColor.opacity(0.04))
                    .padding(.horizontal, -Spacing.sm)
                : nil
        )
    }

    // MARK: - Actions

    private func copyAmount() {
        UIPasteboard.general.string = CurrencyFormatter.formatAbsolute(snap.userNetAmount)
        HapticManager.copyAction()
        withAnimation(AppAnimation.fast) { copiedAmount = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(AppAnimation.fast) { copiedAmount = false }
        }
    }

    private func shareTransaction() {
        let shareText = """
        \(snap.title)
        Amount: \(CurrencyFormatter.format(snap.totalAmount))
        Your share: \(CurrencyFormatter.formatAbsolute(snap.userNetAmount))
        Date: \(snap.formattedDate)
        Participants: \(snap.participantCount) people
        — Shared from Swiss Coin
        """

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }

        let ac = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let popover = ac.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        root.present(ac, animated: true)
    }

    private func performDelete() {
        HapticManager.delete()
        guard !transaction.isDeleted, let ctx = transaction.managedObjectContext else { return }

        if let splits = transaction.splits as? Set<TransactionSplit> {
            splits.forEach { ctx.delete($0) }
        }
        ctx.delete(transaction)

        do {
            try ctx.save()
            HapticManager.success()
            dismiss()
        } catch {
            ctx.rollback()
            HapticManager.error()
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - NavigationLink Detail (legacy push destination)

/// Thin wrapper that presents the same unified detail as a full-screen
/// navigation destination (used by TransactionRowView NavigationLink path).
struct TransactionDetailView: View {
    @ObservedObject var transaction: FinancialTransaction
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var snap = TransactionSnapshot()
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var copiedAmount = false

    @State private var heroVisible = false
    @State private var detailsVisible = false
    @State private var splitsVisible = false
    @State private var actionsVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroSection
                detailsSection
                if !snap.sortedSplits.isEmpty {
                    splitBreakdownSection
                }
                if snap.note != nil {
                    noteSection
                }
                actionsSection
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(AppColors.cardBackground)
            )
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
                        HapticManager.warning()
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
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            recompute()
            triggerEntranceAnimations()
        }
        .onChange(of: transaction.amount) { recompute() }
        .onChange(of: transaction.title) { recompute() }
    }

    private func recompute() {
        guard !transaction.isDeleted, transaction.managedObjectContext != nil else { return }
        snap = TransactionSnapshot.build(from: transaction)
    }

    private func triggerEntranceAnimations() {
        let base = AppAnimation.staggerBaseDelay
        let interval = AppAnimation.staggerInterval
        withAnimation(AppAnimation.contentReveal.delay(base)) { heroVisible = true }
        withAnimation(AppAnimation.contentReveal.delay(base + interval)) { detailsVisible = true }
        withAnimation(AppAnimation.contentReveal.delay(base + interval * 2)) { splitsVisible = true }
        withAnimation(AppAnimation.contentReveal.delay(base + interval * 3)) { actionsVisible = true }
    }

    // The sections below reuse the exact same layout as TransactionExpandedView.
    // They are inlined here to avoid passing 10+ bindings through a shared component,
    // which would actually be slower due to SwiftUI's dependency tracking overhead.

    private var heroSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(snap.netAmountColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: snap.directionIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(snap.netAmountColor)
            }

            Button {
                UIPasteboard.general.string = CurrencyFormatter.formatAbsolute(snap.userNetAmount)
                HapticManager.copyAction()
                withAnimation(AppAnimation.fast) { copiedAmount = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(AppAnimation.fast) { copiedAmount = false }
                }
            } label: {
                VStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.formatAbsolute(snap.userNetAmount))
                        .font(AppTypography.financialHero())
                        .tracking(AppTypography.Tracking.financialHero)
                        .foregroundColor(snap.netAmountColor)
                    if copiedAmount {
                        Text("Copied!")
                            .font(AppTypography.labelSmall())
                            .foregroundColor(AppColors.accent)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
            }
            .buttonStyle(.plain)

            Text(snap.statusText)
                .font(AppTypography.labelDefault())
                .foregroundColor(snap.netAmountColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Capsule().fill(snap.netAmountColor.opacity(0.1)))

            VStack(spacing: Spacing.xxs) {
                Text(snap.title)
                    .font(AppTypography.headingLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                HStack(spacing: Spacing.xs) {
                    Text(snap.formattedDate)
                    if !snap.formattedTime.isEmpty {
                        Text("·")
                        Text(snap.formattedTime)
                    }
                }
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer().frame(height: Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .opacity(heroVisible ? 1 : 0)
        .offset(y: heroVisible ? 0 : 12)
    }

    private var sectionDivider: some View {
        Rectangle().fill(AppColors.separator).frame(height: 0.5)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(AppTypography.headingSmall()).foregroundColor(AppColors.textTertiary)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 20, alignment: .center)
            Text(label).font(AppTypography.bodyDefault()).foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value).font(AppTypography.labelLarge()).foregroundColor(AppColors.textPrimary).lineLimit(1)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionDivider
            VStack(alignment: .leading, spacing: Spacing.md) {
                sectionHeader("Details")
                if snap.isMultiPayer {
                    ForEach(Array(snap.sortedPayers.enumerated()), id: \.offset) { _, payer in
                        detailRow(icon: "creditcard.fill", label: "Paid by", value: "\(payer.name) · \(CurrencyFormatter.format(payer.amount))")
                    }
                } else {
                    detailRow(icon: "creditcard.fill", label: "Paid by", value: snap.payerName)
                }
                detailRow(icon: "person.fill", label: "Created by", value: snap.creatorName)
                detailRow(icon: "person.2.fill", label: "Participants", value: "\(snap.participantCount) \(snap.participantCount == 1 ? "person" : "people")")
                detailRow(icon: "arrow.triangle.branch", label: "Split", value: snap.splitMethodIcon.isEmpty ? snap.splitMethodName : "\(snap.splitMethodIcon) \(snap.splitMethodName)")
                detailRow(icon: "banknote.fill", label: "Total", value: CurrencyFormatter.format(snap.totalAmount))
                if let group = snap.groupName {
                    detailRow(icon: "person.3.fill", label: "Group", value: group)
                }
            }
            .padding(.vertical, Spacing.lg)
        }
        .opacity(detailsVisible ? 1 : 0)
        .offset(y: detailsVisible ? 0 : 8)
    }

    private var splitBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionDivider
            VStack(alignment: .leading, spacing: Spacing.md) {
                sectionHeader("Split Breakdown")
                ForEach(snap.sortedSplits, id: \.objectID) { split in
                    HStack(spacing: Spacing.md) {
                        Circle()
                            .fill(Color(hex: split.colorHex).opacity(split.isUser ? 0.15 : 0.12))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(split.initials)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: split.colorHex))
                            )
                        Text(split.name)
                            .font(split.isUser ? AppTypography.headingSmall() : AppTypography.bodyDefault())
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Text(CurrencyFormatter.format(split.amount))
                            .font(AppTypography.financialDefault())
                            .foregroundColor(split.isUser ? snap.netAmountColor : AppColors.textPrimary)
                    }
                    .padding(.vertical, Spacing.xxs)
                }
                HStack {
                    Text("Total").font(AppTypography.headingSmall()).foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(CurrencyFormatter.format(snap.totalAmount)).font(AppTypography.financialDefault()).foregroundColor(AppColors.textPrimary)
                }
                .padding(.top, Spacing.xs)
            }
            .padding(.vertical, Spacing.lg)
        }
        .opacity(splitsVisible ? 1 : 0)
        .offset(y: splitsVisible ? 0 : 8)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionDivider
            VStack(alignment: .leading, spacing: Spacing.sm) {
                sectionHeader("Note")
                Text(snap.note ?? "")
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Spacing.lg)
        }
        .opacity(splitsVisible ? 1 : 0)
        .offset(y: splitsVisible ? 0 : 8)
    }

    private var actionsSection: some View {
        VStack(spacing: Spacing.sm) {
            sectionDivider
            Spacer().frame(height: Spacing.md)

            Button {
                HapticManager.tap()
                showingEditSheet = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "pencil").font(.system(size: 14, weight: .medium))
                    Text("Edit Transaction").font(AppTypography.buttonDefault())
                }
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity).frame(height: ButtonHeight.md)
                .background(AppColors.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
            }

            Button {
                HapticManager.warning()
                showingDeleteAlert = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "trash").font(.system(size: 14, weight: .medium))
                    Text("Delete Transaction").font(AppTypography.buttonDefault())
                }
                .foregroundColor(AppColors.negative)
                .frame(maxWidth: .infinity).frame(height: ButtonHeight.md)
                .background(AppColors.negative.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
            }
        }
        .opacity(actionsVisible ? 1 : 0)
        .offset(y: actionsVisible ? 0 : 8)
    }

    private func performDelete() {
        HapticManager.delete()
        guard !transaction.isDeleted, let ctx = transaction.managedObjectContext else { return }
        if let splits = transaction.splits as? Set<TransactionSplit> {
            splits.forEach { ctx.delete($0) }
        }
        ctx.delete(transaction)
        do {
            try ctx.save()
            HapticManager.success()
            dismiss()
        } catch {
            ctx.rollback()
            HapticManager.error()
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Line Shape for Dotted Separator (kept for backward compatibility with other files)

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Shared Transaction Detail Helpers

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

