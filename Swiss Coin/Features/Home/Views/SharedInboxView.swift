//
//  SharedInboxView.swift
//  Swiss Coin
//
//  Inbox for pending shared transactions, settlements, and reminders
//  from other Swiss Coin users. Accept or reject items here.
//

import Combine
import CoreData
import Supabase
import SwiftUI

struct SharedInboxView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SharedInboxViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppColors.accent)
                } else if viewModel.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.md) {
                            if !viewModel.pendingTransactions.isEmpty {
                                sectionHeader("Pending Transactions")
                                ForEach(viewModel.pendingTransactions) { item in
                                    pendingTransactionCard(item)
                                }
                            }

                            if !viewModel.pendingSettlements.isEmpty {
                                sectionHeader("Pending Settlements")
                                ForEach(viewModel.pendingSettlements) { item in
                                    pendingSettlementCard(item)
                                }
                            }

                            if !viewModel.sharedReminders.isEmpty {
                                sectionHeader("Reminders")
                                ForEach(viewModel.sharedReminders) { item in
                                    sharedReminderCard(item)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.screenTopPad)
                    }
                }
            }
            .navigationTitle("Shared Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        HapticManager.lightTap()
                        dismiss()
                    }
                    .font(AppTypography.buttonDefault())
                    .foregroundColor(AppColors.accent)
                }
            }
            .task {
                await viewModel.loadPendingItems()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)

            Text("No pending items")
                .font(AppTypography.headingLarge())
                .foregroundColor(AppColors.textSecondary)

            Text("Shared transactions and reminders from other users will appear here.")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.headingSmall())
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.md)
    }

    // MARK: - Transaction Card

    private func pendingTransactionCard(_ item: PendingTransactionItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: IconSize.sm))
                    .foregroundColor(AppColors.accent)

                Text(item.creatorName)
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text(item.dateString)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }

            Text(item.title)
                .font(AppTypography.headingMedium())
                .foregroundColor(AppColors.textPrimary)

            Text(FinancialFormatter.currency(item.amount))
                .font(AppTypography.financialDefault())
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: Spacing.md) {
                Button {
                    Task {
                        HapticManager.success()
                        await viewModel.acceptTransaction(item)
                    }
                } label: {
                    Text("Accept")
                        .font(AppTypography.buttonDefault())
                        .frame(maxWidth: .infinity)
                        .frame(height: ButtonHeight.sm)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    Task {
                        HapticManager.lightTap()
                        await viewModel.rejectTransaction(item)
                    }
                } label: {
                    Text("Reject")
                        .font(AppTypography.buttonDefault())
                        .frame(maxWidth: .infinity)
                        .frame(height: ButtonHeight.sm)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(Spacing.cardPadding)
        .cardStyle()
    }

    // MARK: - Settlement Card

    private func pendingSettlementCard(_ item: PendingSettlementItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: IconSize.sm))
                    .foregroundColor(AppColors.positive)

                Text(item.fromName)
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text(item.dateString)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }

            Text(FinancialFormatter.currency(item.amount))
                .font(AppTypography.financialDefault())
                .foregroundColor(AppColors.positive)

            HStack(spacing: Spacing.md) {
                Button {
                    Task {
                        HapticManager.success()
                        await viewModel.acceptSettlement(item)
                    }
                } label: {
                    Text("Accept")
                        .font(AppTypography.buttonDefault())
                        .frame(maxWidth: .infinity)
                        .frame(height: ButtonHeight.sm)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    Task {
                        HapticManager.lightTap()
                        await viewModel.rejectSettlement(item)
                    }
                } label: {
                    Text("Reject")
                        .font(AppTypography.buttonDefault())
                        .frame(maxWidth: .infinity)
                        .frame(height: ButtonHeight.sm)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(Spacing.cardPadding)
        .cardStyle()
    }

    // MARK: - Reminder Card

    private func sharedReminderCard(_ item: SharedReminderItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: IconSize.sm))
                    .foregroundColor(AppColors.warning)

                Text(item.fromName)
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.textSecondary)

                Spacer()
            }

            if let message = item.message {
                Text(message)
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textPrimary)
            }

            Text(FinancialFormatter.currency(item.amount))
                .font(AppTypography.financialDefault())
                .foregroundColor(AppColors.negative)

            Button {
                Task {
                    HapticManager.lightTap()
                    await viewModel.markReminderRead(item)
                }
            } label: {
                Text("Dismiss")
                    .font(AppTypography.buttonDefault())
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.sm)
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(Spacing.cardPadding)
        .cardStyle()
    }
}

// MARK: - View Model

@MainActor
final class SharedInboxViewModel: ObservableObject {
    @Published var pendingTransactions: [PendingTransactionItem] = []
    @Published var pendingSettlements: [PendingSettlementItem] = []
    @Published var sharedReminders: [SharedReminderItem] = []
    @Published var isLoading = false

    var isEmpty: Bool {
        pendingTransactions.isEmpty && pendingSettlements.isEmpty && sharedReminders.isEmpty
    }

    private let dataService = SupabaseDataService.shared

    func loadPendingItems() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch pending transaction participations
            let txnParticipations = try await dataService.fetchPendingParticipations()
            pendingTransactions = txnParticipations.map { p in
                PendingTransactionItem(
                    participantId: p.id,
                    transactionId: p.transactionId,
                    title: "Shared Transaction",
                    amount: 0,
                    creatorName: "Someone",
                    dateString: DateFormatter.shortDate.string(from: p.createdAt)
                )
            }

            // Fetch pending settlement participations
            let settlementParticipations = try await dataService.fetchPendingSettlementParticipations()
            pendingSettlements = settlementParticipations.map { p in
                PendingSettlementItem(
                    participantId: p.id,
                    settlementId: p.settlementId,
                    amount: 0,
                    fromName: "Someone",
                    dateString: DateFormatter.shortDate.string(from: p.createdAt)
                )
            }

            // Fetch unread shared reminders
            let reminders = try await dataService.fetchSharedReminders()
            sharedReminders = reminders.map { r in
                SharedReminderItem(
                    reminderId: r.id,
                    amount: r.amount,
                    message: r.message,
                    fromName: "Someone"
                )
            }
        } catch {
            // Silently fail — user can pull to refresh
        }
    }

    func acceptTransaction(_ item: PendingTransactionItem) async {
        do {
            try await dataService.updateParticipantStatus(id: item.participantId, status: "accepted")
            pendingTransactions.removeAll { $0.id == item.id }
        } catch {}
    }

    func rejectTransaction(_ item: PendingTransactionItem) async {
        do {
            try await dataService.updateParticipantStatus(id: item.participantId, status: "rejected")
            pendingTransactions.removeAll { $0.id == item.id }
        } catch {}
    }

    func acceptSettlement(_ item: PendingSettlementItem) async {
        do {
            try await dataService.updateSettlementParticipantStatus(id: item.participantId, status: "accepted")
            pendingSettlements.removeAll { $0.id == item.id }
        } catch {}
    }

    func rejectSettlement(_ item: PendingSettlementItem) async {
        do {
            try await dataService.updateSettlementParticipantStatus(id: item.participantId, status: "rejected")
            pendingSettlements.removeAll { $0.id == item.id }
        } catch {}
    }

    func markReminderRead(_ item: SharedReminderItem) async {
        do {
            try await SupabaseConfig.client.from("shared_reminders")
                .update(["is_read": true])
                .eq("id", value: item.reminderId.uuidString)
                .execute()
            sharedReminders.removeAll { $0.id == item.id }
        } catch {}
    }
}

// MARK: - Item Models

struct PendingTransactionItem: Identifiable {
    let id = UUID()
    let participantId: UUID
    let transactionId: UUID
    let title: String
    let amount: Double
    let creatorName: String
    let dateString: String
}

struct PendingSettlementItem: Identifiable {
    let id = UUID()
    let participantId: UUID
    let settlementId: UUID
    let amount: Double
    let fromName: String
    let dateString: String
}

struct SharedReminderItem: Identifiable {
    let id = UUID()
    let reminderId: UUID
    let amount: Double
    let message: String?
    let fromName: String
}
