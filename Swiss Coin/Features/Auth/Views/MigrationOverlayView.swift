//
//  MigrationOverlayView.swift
//  Swiss Coin
//
//  Full-screen overlay shown during local→cloud data migration.
//  Displays current entity being migrated and progress count.
//

import SwiftUI

struct MigrationOverlayView: View {
    @ObservedObject var migrationService: MigrationService

    private let totalSteps = 15

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: Spacing.xxl) {
                Spacer()

                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: IconSize.xxl))
                    .foregroundColor(AppColors.accent)
                    .symbolEffect(.pulse, options: .repeating)

                VStack(spacing: Spacing.sm) {
                    Text("Migrating Your Data")
                        .font(AppTypography.displayMedium())
                        .foregroundColor(AppColors.textPrimary)

                    Text("Your existing data is being synced to the cloud. This only happens once.")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxl)
                }

                VStack(spacing: Spacing.md) {
                    ProgressView(value: Double(migrationService.migratedCount), total: Double(totalSteps))
                        .tint(AppColors.accent)
                        .padding(.horizontal, Spacing.xxxl)

                    Text(migrationService.currentEntity)
                        .font(AppTypography.labelDefault())
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()
                Spacer()
            }
        }
    }
}
