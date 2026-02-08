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

    // MARK: - Computed Properties

    private var isPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
    }

    private var splits: [TransactionSplit] {
        let splitSet = transaction.splits as? Set<TransactionSplit> ?? []
        return splitSet.sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }
    }

    private var splitMethod: SplitMethod? {
        guard let raw = transaction.splitMethod else { return nil }
        return SplitMethod(rawValue: raw)
    }

    private var isCurrentUserAPayer: Bool {
        transaction.effectivePayers.contains { CurrentUser.isCurrentUser($0.personId) }
    }

    private var payerName: String {
        let payers = transaction.effectivePayers
        if payers.count <= 1 {
            if let payer = transaction.payer, CurrentUser.isCurrentUser(payer.id) {
                return "You"
            }
            return transaction.payer?.displayName ?? "Unknown"
        }
        let isUserAPayer = payers.contains { CurrentUser.isCurrentUser($0.personId) }
        if isUserAPayer {
            return "You +\(payers.count - 1) others"
        }
        return "\(payers.count) people"
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

    private var userNetAmount: Double {
        let userPaid = transaction.effectivePayers
            .filter { CurrentUser.isCurrentUser($0.personId) }
            .reduce(0) { $0 + $1.amount }
        let userSplit = (transaction.splits as? Set<TransactionSplit> ?? [])
            .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
            .reduce(0) { $0 + $1.amount }
        return userPaid - userSplit
    }

    private var netAmountColor: Color {
        if userNetAmount > 0.01 {
            return AppColors.positive
        } else if userNetAmount < -0.01 {
            return AppColors.negative
        }
        return AppColors.neutral
    }

    private var netAmountText: String {
        let formatted = CurrencyFormatter.formatAbsolute(userNetAmount)
        if userNetAmount > 0.01 {
            return "You lent \(formatted)"
        } else if userNetAmount < -0.01 {
            return "You owe \(formatted)"
        }
        return "You paid your share"
    }

    private var netAmountBackgroundColor: Color {
        if userNetAmount > 0.01 {
            return AppColors.positive.opacity(0.12)
        } else if userNetAmount < -0.01 {
            return AppColors.negative.opacity(0.12)
        }
        return AppColors.backgroundTertiary
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
                if !splits.isEmpty {
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

            ForEach(splits, id: \.objectID) { split in
                HStack(spacing: Spacing.sm) {
                    if let person = split.owedBy {
                        Circle()
                            .fill(Color(hex: person.safeColorHex))
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
        guard let person = split.owedBy else { return "Unknown" }
        if CurrentUser.isCurrentUser(person.id) {
            return "You"
        }
        return person.displayName
    }

    private func splitAmountColor(for split: TransactionSplit) -> Color {
        guard let person = split.owedBy else { return AppColors.textPrimary }
        if CurrentUser.isCurrentUser(person.id) {
            return isCurrentUserAPayer ? AppColors.textSecondary : AppColors.negative
        } else {
            return isCurrentUserAPayer ? AppColors.positive : AppColors.textSecondary
        }
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

// MARK: - Expanded Detail Card Overlay (Carousel / Stack Animation)

/// Card modal overlay that appears when tapping a transaction row.
/// Uses a carousel/stack animation with dissolve and subtle slide transitions.
struct TransactionExpandedView: View {
    @ObservedObject var transaction: FinancialTransaction
    var animationNamespace: Namespace.ID
    @Binding var selectedTransaction: FinancialTransaction?

    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Staggered Animation States

    @State private var scrimVisible = false
    @State private var cardVisible = false
    @State private var headerVisible = false
    @State private var detailsVisible = false
    @State private var paymentVisible = false
    @State private var actionsVisible = false

    // MARK: - Computed Properties

    private var isPayer: Bool {
        CurrentUser.isCurrentUser(transaction.payer?.id)
    }

    private var splits: [TransactionSplit] {
        let splitSet = transaction.splits as? Set<TransactionSplit> ?? []
        return splitSet.sorted { ($0.owedBy?.displayName ?? "") < ($1.owedBy?.displayName ?? "") }
    }

    private var splitMethod: SplitMethod? {
        guard let raw = transaction.splitMethod else { return nil }
        return SplitMethod(rawValue: raw)
    }

    private var isCurrentUserAPayer: Bool {
        transaction.effectivePayers.contains { CurrentUser.isCurrentUser($0.personId) }
    }

    private var payerName: String {
        let payers = transaction.effectivePayers
        if payers.count <= 1 {
            if let payer = transaction.payer, CurrentUser.isCurrentUser(payer.id) {
                return "You"
            }
            return transaction.payer?.displayName ?? "Unknown"
        }
        let isUserAPayer = payers.contains { CurrentUser.isCurrentUser($0.personId) }
        if isUserAPayer {
            return "You +\(payers.count - 1) others"
        }
        return "\(payers.count) people"
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

    private var userNetAmount: Double {
        let userPaid = transaction.effectivePayers
            .filter { CurrentUser.isCurrentUser($0.personId) }
            .reduce(0) { $0 + $1.amount }
        let userSplit = (transaction.splits as? Set<TransactionSplit> ?? [])
            .filter { CurrentUser.isCurrentUser($0.owedBy?.id) }
            .reduce(0) { $0 + $1.amount }
        return userPaid - userSplit
    }

    private var netAmountColor: Color {
        if userNetAmount > 0.01 {
            return AppColors.positive
        } else if userNetAmount < -0.01 {
            return AppColors.negative
        }
        return AppColors.neutral
    }

    private var netAmountText: String {
        let formatted = CurrencyFormatter.formatAbsolute(userNetAmount)
        if userNetAmount > 0.01 {
            return "You lent \(formatted)"
        } else if userNetAmount < -0.01 {
            return "You owe \(formatted)"
        }
        return "You paid your share"
    }

    private var netAmountBackgroundColor: Color {
        if userNetAmount > 0.01 {
            return AppColors.positive.opacity(0.12)
        } else if userNetAmount < -0.01 {
            return AppColors.negative.opacity(0.12)
        }
        return AppColors.backgroundTertiary
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
        ZStack {
            // Dimmed scrim background
            Color.black.opacity(scrimVisible ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismissCard() }

            // Centered card
            detailCard
                .opacity(cardVisible ? 1 : 0)
                .offset(y: cardVisible ? 0 : 60)
                .scaleEffect(cardVisible ? 1 : 0.92)
        }
        .onAppear { animateIn() }
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

    // MARK: - Detail Card

    private var detailCard: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Section 1: Header (Icon, Name, Amount, Type)
                headerSection
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : 14)

                // Dotted separator
                dottedSeparator
                    .opacity(detailsVisible ? 1 : 0)

                // Section 2: Transaction Details (ID, Date, Time)
                detailsSection
                    .opacity(detailsVisible ? 1 : 0)
                    .offset(y: detailsVisible ? 0 : 14)

                // Dotted separator
                dottedSeparator
                    .opacity(paymentVisible ? 1 : 0)

                // Section 3: Payment & Split Info
                paymentSection
                    .opacity(paymentVisible ? 1 : 0)
                    .offset(y: paymentVisible ? 0 : 14)

                // Dotted separator (before net impact)
                dottedSeparator
                    .opacity(actionsVisible ? 1 : 0)

                // Section 4: Net Impact + Note + Actions
                bottomSection
                    .opacity(actionsVisible ? 1 : 0)
                    .offset(y: actionsVisible ? 0 : 14)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.lg)
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.72)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(AppColors.cardBackground)
                .shadow(color: Color.black.opacity(0.18), radius: 40, y: 16)
        )
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Top row: Icon + Close button
            HStack(alignment: .top) {
                // Transaction icon (dark rounded square)
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.textPrimary)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: directionIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppColors.cardBackground)
                    )

                Spacer()

                // Close button
                Button {
                    HapticManager.lightTap()
                    dismissCard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            AppColors.textTertiary,
                            AppColors.backgroundTertiary
                        )
                }
            }

            // Name + Amount row
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

            // Category / Split method label
            Text(splitMethod?.displayName ?? "Expense")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Details Section (ID, Date, Time)

    private var detailsSection: some View {
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
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Payment Section

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Paid by
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

            // Participants + Split method
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

            // Group info
            if let group = transaction.group {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: group.colorHex ?? "#808080"))
                    Text(group.name ?? "Unknown Group")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Bottom Section (Net Impact, Note, Actions)

    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Net impact badge
            Text(netAmountText)
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(netAmountColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(netAmountBackgroundColor)
                )
                .padding(.top, Spacing.sm)

            // Note (if present)
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

            // Action buttons
            HStack(spacing: Spacing.md) {
                Button {
                    HapticManager.tap()
                    showingEditSheet = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .medium))
                        Text("Edit")
                            .font(AppTypography.subheadlineMedium())
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.sm)
                    .background(AppColors.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                }

                Button {
                    HapticManager.tap()
                    showingDeleteAlert = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                        Text("Delete")
                            .font(AppTypography.subheadlineMedium())
                    }
                    .foregroundColor(AppColors.negative)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.sm)
                    .background(AppColors.negative.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                }
            }
        }
    }

    // MARK: - Dotted Separator

    private var dottedSeparator: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundColor(AppColors.separator)
            .frame(height: 1)
    }

    // MARK: - Animations

    private func animateIn() {
        // Card entrance: spring with slide + scale + fade
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            scrimVisible = true
            cardVisible = true
        }

        // Staggered element reveals for carousel/stack effect
        withAnimation(.easeOut(duration: 0.35).delay(0.08)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.18)) {
            detailsVisible = true
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.28)) {
            paymentVisible = true
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.38)) {
            actionsVisible = true
        }
    }

    private func dismissCard() {
        // Reverse stagger: actions fade out first, then others
        withAnimation(.easeIn(duration: 0.15)) {
            actionsVisible = false
            paymentVisible = false
        }
        withAnimation(.easeIn(duration: 0.18).delay(0.04)) {
            detailsVisible = false
            headerVisible = false
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85).delay(0.08)) {
            cardVisible = false
            scrimVisible = false
        }

        // Dismiss after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            selectedTransaction = nil
        }
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
