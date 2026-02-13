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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                // Hero amount
                sheetHeroSection

                // Transaction Info card
                sheetTransactionInfoCard

                // Paid By card
                sheetPaidByCard

                // Split Between card
                if !snap.sortedSplits.isEmpty {
                    sheetSplitBetweenCard
                }

                // Your Summary card
                sheetYourSummaryCard

                // Action buttons
                sheetActionsSection
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.section)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CornerRadius.xl)
        .presentationBackground(AppColors.backgroundSecondary)
        .onAppear {
            recompute()
            HapticManager.lightTap()
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

    // MARK: - Hero Section

    private var sheetHeroSection: some View {
        VStack(spacing: Spacing.xs) {
            Text(CurrencyFormatter.format(snap.totalAmount))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .tracking(-0.5)
                .foregroundColor(AppColors.textPrimary)

            Text("Total Amount")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Transaction Info Card

    private var sheetTransactionInfoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Transaction Info")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, Spacing.lg)

            sheetInfoRow(icon: "tag.fill", label: "Title", value: snap.title)
            sheetCardDivider
            sheetInfoRow(icon: "calendar", label: "Date", value: sheetFormattedShortDate)

            if let note = snap.note {
                sheetCardDivider
                sheetInfoRow(icon: "note.text", label: "Note", value: note)
            }

            if let group = snap.groupName {
                sheetCardDivider
                sheetInfoRow(icon: "person.2.fill", label: "Group", value: group)
            }

            sheetCardDivider
            sheetInfoRow(icon: "arrow.triangle.branch", label: "Split Method", value: "Split \(snap.splitMethodName)")
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 1)
        )
    }

    private var sheetFormattedShortDate: String {
        guard let date = transaction.date else { return "Unknown" }
        return DateFormatter.mediumDate.string(from: date)
    }

    private func sheetInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.accent)
            }

            Text(label)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, Spacing.sm)
    }

    private var sheetCardDivider: some View {
        Rectangle()
            .fill(AppColors.divider)
            .frame(height: 0.5)
    }

    // MARK: - Paid By Card

    private var sheetPaidByCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Paid By")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)

            if snap.isMultiPayer {
                ForEach(Array(snap.sortedPayers.enumerated()), id: \.offset) { _, payer in
                    sheetPayerRow(name: payer.name, amount: payer.amount, isUser: payer.isUser)
                }
            } else {
                sheetPayerRow(name: snap.payerName, amount: snap.totalAmount, isUser: snap.payerName == "You")
            }
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 1)
        )
    }

    private func sheetPayerRow(name: String, amount: Double, isUser: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(AppColors.accent.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(isUser ? "Y" : String(name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                )

            Text(name)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(CurrencyFormatter.format(amount))
                .font(AppTypography.labelDefault())
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.accent.opacity(0.12))
                )
        }
    }

    // MARK: - Split Between Card

    private var sheetSplitBetweenCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Split Between")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)

            ForEach(Array(snap.sortedSplits.enumerated()), id: \.element.objectID) { index, split in
                if index > 0 {
                    sheetCardDivider
                }
                sheetSplitPersonRow(split)
            }
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 1)
        )
    }

    private func sheetSplitPersonRow(_ split: (objectID: NSManagedObjectID, name: String, initials: String, colorHex: String, amount: Double, isUser: Bool)) -> some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color(hex: split.colorHex).opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(split.isUser ? "Y" : String(split.initials.prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: split.colorHex))
                )

            Text(split.name)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(CurrencyFormatter.format(split.amount))
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Your Summary Card

    private var sheetYourSummaryCard: some View {
        let userPaid = snap.isMultiPayer
            ? snap.sortedPayers.filter { $0.isUser }.reduce(0) { $0 + $1.amount }
            : (snap.payerName == "You" ? snap.totalAmount : 0)
        let userShare = snap.sortedSplits.filter { $0.isUser }.reduce(0) { $0 + $1.amount }
        let netAmount = snap.userNetAmount

        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Your Summary")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)

            sheetSummaryRow(label: "You paid", value: CurrencyFormatter.format(userPaid), color: AppColors.textPrimary)
            sheetSummaryRow(label: "Your share", value: CurrencyFormatter.format(userShare), color: AppColors.textPrimary)

            sheetCardDivider

            if netAmount > 0.01 {
                sheetSummaryRow(label: "You are owed", value: CurrencyFormatter.format(netAmount), color: AppColors.positive)
            } else if netAmount < -0.01 {
                sheetSummaryRow(label: "You owe", value: CurrencyFormatter.format(abs(netAmount)), color: AppColors.negative)
            } else {
                sheetSummaryRow(label: "Settled up", value: CurrencyFormatter.format(0), color: AppColors.neutral)
            }
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 1)
        )
    }

    private func sheetSummaryRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.financialDefault())
                .foregroundColor(color)
        }
        .padding(.vertical, Spacing.xxs)
    }

    // MARK: - Actions Section

    private var sheetActionsSection: some View {
        VStack(spacing: Spacing.sm) {
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
        .padding(.top, Spacing.sm)
    }

    // MARK: - Actions

    private func performDelete() {
        HapticManager.delete()
        guard !transaction.isDeleted, let ctx = transaction.managedObjectContext else { return }

        if let splits = transaction.splits as? Set<TransactionSplit> {
            splits.forEach { ctx.delete($0) }
        }
        if let payerSet = transaction.payers as? Set<TransactionPayer> {
            payerSet.forEach { ctx.delete($0) }
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

// MARK: - NavigationLink Detail (Card-based design)

/// Full-screen transaction detail page with card-based layout.
/// Designed with separate white cards for each section: hero amount,
/// transaction info, paid by, split between, and your summary.
struct TransactionDetailView: View {
    @ObservedObject var transaction: FinancialTransaction
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var snap = TransactionSnapshot()
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                // Hero amount
                heroAmountSection

                // Transaction Info card
                transactionInfoCard

                // Paid By card
                paidByCard

                // Split Between card
                if !snap.sortedSplits.isEmpty {
                    splitBetweenCard
                }

                // Your Summary card
                yourSummaryCard
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.section)
        }
        .background(AppColors.backgroundSecondary)
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HapticManager.warning()
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.negative)
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
        }
        .onChange(of: transaction.amount) { recompute() }
        .onChange(of: transaction.title) { recompute() }
    }

    private func recompute() {
        guard !transaction.isDeleted, transaction.managedObjectContext != nil else { return }
        snap = TransactionSnapshot.build(from: transaction)
    }

    // MARK: - Hero Amount Section

    private var heroAmountSection: some View {
        VStack(spacing: Spacing.xs) {
            Text(CurrencyFormatter.format(snap.totalAmount))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .tracking(-0.5)
                .foregroundColor(AppColors.textPrimary)

            Text("Total Amount")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    // MARK: - Transaction Info Card

    private var transactionInfoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("Transaction Info")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, Spacing.lg)

            // Title row
            infoRow(icon: "tag.fill", label: "Title", value: snap.title)

            cardDivider

            // Date row
            infoRow(icon: "calendar", label: "Date", value: formattedShortDate)

            // Note row (if present)
            if let note = snap.note {
                cardDivider
                infoRow(icon: "note.text", label: "Note", value: note)
            }

            // Group row (if present)
            if let group = snap.groupName {
                cardDivider
                infoRow(icon: "person.2.fill", label: "Group", value: group)
            }

            cardDivider

            // Split method row
            infoRow(icon: "arrow.triangle.branch", label: "Split Method", value: "Split \(snap.splitMethodName)")
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 1)
        )
    }

    /// Formatted short date (e.g., "Jan 15, 2025")
    private var formattedShortDate: String {
        guard let date = transaction.date else { return "Unknown" }
        return DateFormatter.mediumDate.string(from: date)
    }

    /// A single info row with an icon in an orange-tinted circle, a label, and a value
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Spacing.md) {
            // Orange-tinted circle background for icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.accent)
            }

            Text(label)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, Spacing.sm)
    }

    /// Thin divider used within cards
    private var cardDivider: some View {
        Rectangle()
            .fill(AppColors.divider)
            .frame(height: 0.5)
    }

    // MARK: - Paid By Card

    private var paidByCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Paid By")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)

            if snap.isMultiPayer {
                ForEach(Array(snap.sortedPayers.enumerated()), id: \.offset) { _, payer in
                    payerRow(name: payer.name, amount: payer.amount, isUser: payer.isUser)
                }
            } else {
                payerRow(name: snap.payerName, amount: snap.totalAmount, isUser: snap.payerName == "You")
            }
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 1)
        )
    }

    /// A payer row with avatar circle and orange amount badge
    private func payerRow(name: String, amount: Double, isUser: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            Circle()
                .fill(AppColors.accent.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(isUser ? "Y" : String(name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                )

            Text(name)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            // Orange amount badge
            Text(CurrencyFormatter.format(amount))
                .font(AppTypography.labelDefault())
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.accent.opacity(0.12))
                )
        }
    }

    // MARK: - Split Between Card

    private var splitBetweenCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Split Between")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)

            ForEach(Array(snap.sortedSplits.enumerated()), id: \.element.objectID) { index, split in
                if index > 0 {
                    cardDivider
                }
                splitPersonRow(split)
            }
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 1)
        )
    }

    /// A split person row with colored avatar and amount
    private func splitPersonRow(_ split: (objectID: NSManagedObjectID, name: String, initials: String, colorHex: String, amount: Double, isUser: Bool)) -> some View {
        HStack(spacing: Spacing.md) {
            // Avatar circle
            Circle()
                .fill(Color(hex: split.colorHex).opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(split.isUser ? "Y" : String(split.initials.prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: split.colorHex))
                )

            Text(split.name)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(CurrencyFormatter.format(split.amount))
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Your Summary Card

    private var yourSummaryCard: some View {
        let userPaid = snap.isMultiPayer
            ? snap.sortedPayers.filter { $0.isUser }.reduce(0) { $0 + $1.amount }
            : (snap.payerName == "You" ? snap.totalAmount : 0)
        let userShare = snap.sortedSplits.filter { $0.isUser }.reduce(0) { $0 + $1.amount }
        let netAmount = snap.userNetAmount

        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Your Summary")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)

            // You paid
            summaryRow(label: "You paid", value: CurrencyFormatter.format(userPaid), color: AppColors.textPrimary)

            // Your share
            summaryRow(label: "Your share", value: CurrencyFormatter.format(userShare), color: AppColors.textPrimary)

            cardDivider

            // Net result
            if netAmount > 0.01 {
                summaryRow(label: "You are owed", value: CurrencyFormatter.format(netAmount), color: AppColors.positive)
            } else if netAmount < -0.01 {
                summaryRow(label: "You owe", value: CurrencyFormatter.format(abs(netAmount)), color: AppColors.negative)
            } else {
                summaryRow(label: "Settled up", value: CurrencyFormatter.format(0), color: AppColors.neutral)
            }
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 1)
        )
    }

    /// A summary row with label on the left and colored value on the right
    private func summaryRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppTypography.financialDefault())
                .foregroundColor(color)
        }
        .padding(.vertical, Spacing.xxs)
    }

    // MARK: - Actions

    private func performDelete() {
        HapticManager.delete()
        guard !transaction.isDeleted, let ctx = transaction.managedObjectContext else { return }
        if let splits = transaction.splits as? Set<TransactionSplit> {
            splits.forEach { ctx.delete($0) }
        }
        if let payerSet = transaction.payers as? Set<TransactionPayer> {
            payerSet.forEach { ctx.delete($0) }
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

