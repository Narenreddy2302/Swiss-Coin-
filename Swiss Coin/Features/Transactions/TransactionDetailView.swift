//
//  TransactionDetailView.swift
//  Swiss Coin
//
//  Transaction detail page matching the reference design: hero card,
//  unified split details list, comments section, and action buttons.
//

import CoreData
import SwiftUI

// MARK: - Transaction Detail View

struct TransactionDetailView: View {
    @ObservedObject var transaction: FinancialTransaction
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var newCommentText = ""
    @State private var sortedComments: [ChatMessage] = []

    private var snapshot: TransactionSnapshot {
        TransactionSnapshot.build(from: transaction)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroHeader
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.lg)

                if !snapshot.sortedPayers.isEmpty || !snapshot.sortedSplits.isEmpty {
                    splitDetailsSection
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, Spacing.xl)
                }

                commentsSection
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.xl)

                actionButtons
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.xxl)
            }
        }
        .background(AppColors.groupedBackground)
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Transaction", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Transaction", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .onAppear {
            refreshComments()
        }
        .onChange(of: transaction.comments) {
            refreshComments()
        }
        .sheet(isPresented: $showEditSheet) {
            TransactionEditView(transaction: transaction)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Transaction", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTransaction()
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 0) {
            // Icon + Title + Date cluster
            Circle()
                .fill(AppColors.accentMuted)
                .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                .overlay(
                    Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .font(.system(size: IconSize.md))
                        .foregroundColor(AppColors.accent)
                )
                .padding(.bottom, Spacing.md)

            Text(snapshot.title)
                .font(AppTypography.headingMedium())
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xs)

            Text(snapshot.formattedDate)
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textTertiary)

            // Amount hero zone
            Text(FinancialFormatter.signedCurrency(snapshot.userNetAmount))
                .financialHeroStyle()
                .foregroundColor(snapshot.netAmountColor)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xs)

            Text(snapshot.paymentSummaryText)
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, Spacing.xxxl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(AppColors.cardBackground)
                .shadow(
                    color: AppShadow.card(for: colorScheme).color,
                    radius: AppShadow.card(for: colorScheme).radius,
                    x: AppShadow.card(for: colorScheme).x,
                    y: AppShadow.card(for: colorScheme).y
                )
        )
    }

    // MARK: - Split Details Section

    private var splitDetailsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SPLIT DETAILS")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(spacing: 0) {
                let participants = snapshot.unifiedParticipants
                ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                    UnifiedParticipantRow(participant: participant)

                    if index < participants.count - 1 {
                        CardDivider()
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("COMMENTS")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textTertiary)

            VStack(alignment: .leading, spacing: Spacing.md) {
                if sortedComments.isEmpty {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: IconSize.lg))
                            .foregroundColor(AppColors.textTertiary)

                        Text("No comments yet")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                } else {
                    VStack(spacing: Spacing.sm) {
                        ForEach(sortedComments) { comment in
                            CommentRow(comment: comment)
                        }
                    }
                }

                HStack(spacing: Spacing.sm) {
                    ConversationAvatarView(
                        initials: CurrentUser.initials,
                        colorHex: CurrentUser.defaultColorHex,
                        size: AvatarSize.xs
                    )

                    HStack(spacing: Spacing.sm) {
                        TextField("Add a comment...", text: $newCommentText)
                            .font(AppTypography.bodySmall())

                        if !newCommentText.isEmpty {
                            Button {
                                HapticManager.tap()
                                sendComment()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: IconSize.lg))
                                    .foregroundColor(AppColors.accent)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(AppColors.surface)
                    .cornerRadius(CornerRadius.button)
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                HapticManager.tap()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: IconSize.sm))
                    Text("Send Reminder")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                HapticManager.tap()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: IconSize.sm))
                    Text("Mark as Settled")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: - Logic Functions

    private func refreshComments() {
        if let comments = transaction.comments as? Set<ChatMessage> {
            sortedComments = comments.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        } else {
            sortedComments = []
        }
    }

    private func sendComment() {
        guard !newCommentText.isEmpty else { return }

        let comment = ChatMessage(context: viewContext)
        comment.id = UUID()
        comment.content = newCommentText
        comment.timestamp = Date()
        comment.isFromUser = true
        comment.onTransaction = transaction

        do {
            try viewContext.save()
            newCommentText = ""
            refreshComments()
        } catch {
            print("Error saving comment: \(error)")
        }
    }

    private func deleteTransaction() {
        viewContext.delete(transaction)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
        }
    }
}

// MARK: - Supporting View Components

/// Unified participant row for the split details card
struct UnifiedParticipantRow: View {
    let participant: TransactionSnapshot.UnifiedParticipant

    var body: some View {
        HStack(spacing: Spacing.md) {
            ConversationAvatarView(
                initials: participant.initials,
                colorHex: participant.colorHex,
                size: AvatarSize.sm
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(participant.name)
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                Text(participant.subtitle)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(FinancialFormatter.currency(participant.displayAmount))
                    .font(AppTypography.financialSmall())
                    .foregroundColor(AppColors.textPrimary)

                if participant.isPaid {
                    HStack(spacing: Spacing.xxs) {
                        Text("Paid")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.positive)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: IconSize.xs))
                            .foregroundColor(AppColors.positive)
                    }
                } else {
                    Text(participant.statusText)
                        .font(AppTypography.caption())
                        .foregroundColor(participant.statusColor)
                }
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}

/// Comment row in activity feed
private struct CommentRow: View {
    let comment: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ConversationAvatarView(
                initials: comment.isFromUser
                    ? CurrentUser.initials
                    : (comment.withPerson?.initials ?? "?"),
                colorHex: comment.isFromUser
                    ? CurrentUser.defaultColorHex
                    : (comment.withPerson?.colorHex ?? AppColors.defaultAvatarColorHex),
                size: AvatarSize.xs
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.isFromUser ? "You" : (comment.withPerson?.displayName ?? "Unknown"))
                        .font(AppTypography.labelDefault())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    if let date = comment.timestamp {
                        Text(date.relativeShort)
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Text(comment.content ?? "")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

/// Card divider
struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.divider.opacity(0.6))
            .frame(height: 0.5)
    }
}

// MARK: - Transaction Snapshot

/// Immutable snapshot of transaction data for view rendering
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
    var sortedPayers: [(name: String, initials: String, colorHex: String, amount: Double, isUser: Bool)] = []
    var sortedSplits: [(objectID: NSManagedObjectID, name: String, initials: String, colorHex: String, amount: Double, isUser: Bool)] = []

    var netAmountColor: Color {
        if userNetAmount > 0.01 { return AppColors.positive }
        if userNetAmount < -0.01 { return AppColors.negative }
        return AppColors.neutral
    }

    var directionIcon: String {
        userNetAmount > 0.01 ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill"
    }

    var statusText: String {
        if userNetAmount > 0.01 { return "You are owed" }
        if userNetAmount < -0.01 { return "You owe" }
        return "Settled"
    }

    var paymentSummaryText: String {
        if userNetAmount < -0.01 {
            let nonUserPayers = sortedPayers.filter { !$0.isUser }
            if nonUserPayers.count == 1 {
                return "You paid \(nonUserPayers[0].name)"
            }
            return "You owe"
        } else if userNetAmount > 0.01 {
            let nonUserSplits = sortedSplits.filter { !$0.isUser }
            if nonUserSplits.count == 1 {
                return "\(nonUserSplits[0].name) owes you"
            }
            return "You are owed"
        }
        return "Settled up"
    }

    // MARK: - Unified Participant

    struct UnifiedParticipant: Identifiable {
        let id: String
        let name: String
        let initials: String
        let colorHex: String
        let displayAmount: Double
        let subtitle: String
        let statusText: String
        let statusColor: Color
        let isPaid: Bool
        let isUser: Bool
    }

    var unifiedParticipants: [UnifiedParticipant] {
        var result: [UnifiedParticipant] = []
        let primaryPayerName = sortedPayers.first?.name ?? "payer"
        var addedNames = Set<String>()

        for (index, payer) in sortedPayers.enumerated() {
            let splitAmount = sortedSplits.first(where: { $0.name == payer.name })?.amount ?? 0
            result.append(UnifiedParticipant(
                id: "payer-\(index)",
                name: payer.name,
                initials: payer.initials,
                colorHex: payer.colorHex,
                displayAmount: splitAmount > 0 ? splitAmount : payer.amount,
                subtitle: "Paid \(FinancialFormatter.currency(payer.amount))",
                statusText: "Your share",
                statusColor: AppColors.textTertiary,
                isPaid: false,
                isUser: payer.isUser
            ))
            addedNames.insert(payer.name)
        }

        for (index, split) in sortedSplits.enumerated() {
            if addedNames.contains(split.name) { continue }

            result.append(UnifiedParticipant(
                id: "split-\(index)",
                name: split.name,
                initials: split.initials,
                colorHex: split.colorHex,
                displayAmount: split.amount,
                subtitle: "Owes \(primaryPayerName)",
                statusText: "Pending",
                statusColor: AppColors.warning,
                isPaid: false,
                isUser: split.isUser
            ))
        }

        return result
    }

    static func build(from tx: FinancialTransaction) -> TransactionSnapshot {
        var s = TransactionSnapshot()
        s.title = tx.title ?? "Unknown Transaction"
        s.totalAmount = tx.amount

        if let date = tx.date {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                s.formattedDate = "Today, \(DateFormatter.timeOnly.string(from: date))"
            } else if calendar.isDateInYesterday(date) {
                s.formattedDate = "Yesterday, \(DateFormatter.timeOnly.string(from: date))"
            } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
                let dayOfWeek = DateFormatter.dayOfWeek.string(from: date)
                s.formattedDate = "\(dayOfWeek), \(DateFormatter.timeOnly.string(from: date))"
            } else {
                s.formattedDate = DateFormatter.mediumDate.string(from: date)
            }
            s.formattedTime = DateFormatter.timeOnly.string(from: date)
        } else {
            s.formattedDate = "Unknown date"
            s.formattedTime = ""
        }

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
                            initials: isUser ? "ME" : (tp.paidBy?.initials ?? "?"),
                            colorHex: isUser ? AppColors.defaultAvatarColorHex : (tp.paidBy?.colorHex ?? AppColors.defaultAvatarColorHex),
                            amount: tp.amount,
                            isUser: isUser)
                }
        } else if let payer = tx.payer {
            let isUser = CurrentUser.isCurrentUser(payer.id)
            s.sortedPayers = [(name: isUser ? "You" : payer.displayName,
                              initials: isUser ? "ME" : payer.initials,
                              colorHex: isUser ? AppColors.defaultAvatarColorHex : (payer.colorHex ?? AppColors.defaultAvatarColorHex),
                              amount: tx.amount,
                              isUser: isUser)]
        }

        s.payerName = TransactionDetailHelpers.payerName(effectivePayers: effectivePayers, payer: tx.payer)
        s.creatorName = TransactionDetailHelpers.creatorName(transaction: tx)

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

        if let raw = tx.splitMethod, let method = SplitMethod(rawValue: raw) {
            s.splitMethodName = method.displayName
            s.splitMethodIcon = method.icon
        }

        s.groupName = tx.group?.name

        if let note = tx.note, !note.isEmpty {
            s.note = note
        }

        return s
    }
}

// MARK: - Transaction Detail Helpers

/// Helper utilities for transaction detail calculations
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
