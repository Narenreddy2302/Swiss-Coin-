//
//  TransactionDetailSheet.swift
//  Swiss Coin
//
//  Card-based transaction detail sheet matching the redesigned TransactionDetailView.
//  Shows hero header, unified split details, note, and Edit/Delete action buttons.
//

import CoreData
import SwiftUI

struct TransactionDetailSheet: View {
    @ObservedObject var transaction: FinancialTransaction
    let person: Person?
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""

    init(transaction: FinancialTransaction, person: Person? = nil, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.transaction = transaction
        self.person = person
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    private var snapshot: TransactionSnapshot {
        TransactionSnapshot.build(from: transaction)
    }

    // MARK: - Body

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

                if let note = snapshot.note {
                    noteSection(note: note)
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, Spacing.xl)
                }

                actionButtonsSection
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.xxl)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.groupedBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CornerRadius.xl)
        .presentationBackground(AppColors.groupedBackground)
        .onAppear {
            HapticManager.lightTap()
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
            Button("OK", role: .cancel) { HapticManager.tap() }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: Spacing.md) {
            Circle()
                .fill(AppColors.info.opacity(0.15))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .font(.system(size: IconSize.category, weight: .medium))
                        .foregroundColor(AppColors.info)
                )
                .padding(.top, Spacing.xl)

            Text(snapshot.title)
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            Text(snapshot.formattedDate)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)

            Text(FinancialFormatter.signedCurrency(snapshot.userNetAmount))
                .font(AppTypography.financialHero())
                .foregroundColor(snapshot.netAmountColor)

            Text(snapshot.paymentSummaryText)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.card)
        .shadow(
            color: AppShadow.card(for: colorScheme).color,
            radius: AppShadow.card(for: colorScheme).radius,
            x: AppShadow.card(for: colorScheme).x,
            y: AppShadow.card(for: colorScheme).y
        )
    }

    // MARK: - Split Details Section

    private var splitDetailsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Split Details")
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: 0) {
                let participants = snapshot.unifiedParticipants
                ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                    UnifiedParticipantRow(participant: participant)

                    if index < participants.count - 1 {
                        CardDivider()
                    }
                }
            }
            .padding(Spacing.cardPadding)
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.card)
            .shadow(
                color: AppShadow.card(for: colorScheme).color,
                radius: AppShadow.card(for: colorScheme).radius,
                x: AppShadow.card(for: colorScheme).x,
                y: AppShadow.card(for: colorScheme).y
            )
        }
    }

    // MARK: - Note Section

    private func noteSection(note: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Note")
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading) {
                Text(note)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.cardPadding)
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.card)
            .shadow(
                color: AppShadow.card(for: colorScheme).color,
                radius: AppShadow.card(for: colorScheme).radius,
                x: AppShadow.card(for: colorScheme).x,
                y: AppShadow.card(for: colorScheme).y
            )
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: Spacing.md) {
            Button {
                HapticManager.tap()
                if let onEdit {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onEdit()
                    }
                } else {
                    showingEditSheet = true
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "pencil")
                        .font(.system(size: IconSize.sm))
                    Text("Edit Transaction")
                        .font(AppTypography.buttonLarge())
                }
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.lg)
                .background(AppColors.accent)
                .foregroundColor(AppColors.buttonForeground)
                .cornerRadius(CornerRadius.button)
            }

            Button {
                HapticManager.tap()
                showingDeleteAlert = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "trash")
                        .font(.system(size: IconSize.sm))
                    Text("Delete Transaction")
                        .font(AppTypography.buttonLarge())
                }
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.lg)
                .background(AppColors.cardBackground)
                .foregroundColor(AppColors.negative)
                .cornerRadius(CornerRadius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.button)
                        .strokeBorder(AppColors.negative.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Delete Action

    private func performDelete() {
        if let onDelete {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onDelete()
            }
        } else {
            HapticManager.delete()

            if let splits = transaction.splits as? Set<TransactionSplit> {
                splits.forEach { viewContext.delete($0) }
            }
            if let payers = transaction.payers as? Set<TransactionPayer> {
                payers.forEach { viewContext.delete($0) }
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
}
