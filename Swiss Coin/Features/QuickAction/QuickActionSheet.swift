//
//  QuickActionSheet.swift
//  Swiss Coin
//
//  Main bottom sheet container for the Quick Action flow.
//

import SwiftUI
import UIKit

struct QuickActionSheet: View {

    @ObservedObject var viewModel: QuickActionViewModel

    var body: some View {
        NavigationView {  // Used NavigationView for broader compatibility, reference used NavigationStack
            VStack(spacing: 0) {

                // MARK: Step Indicator Dots
                HStack(spacing: Spacing.xs) {
                    ForEach(1...3, id: \.self) { step in
                        Circle()
                            .fill(
                                step <= viewModel.currentStep
                                    ? AppColors.accent : AppColors.textSecondary.opacity(0.3)
                            )
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.md)

                // MARK: Step Content
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        switch viewModel.currentStep {
                        case 1:
                            Step1BasicDetailsView(viewModel: viewModel)
                        case 2:
                            Step2SplitConfigView(viewModel: viewModel)
                        case 3:
                            Step3SplitMethodView(viewModel: viewModel)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxl)
                }
            }
            .background(AppColors.backgroundSecondary)
            // MARK: Navigation Bar
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel button (left)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.tap()
                        viewModel.closeSheet()
                    }
                }

                // Done button (right) - only shown on final step
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.currentStep == 3
                        || (viewModel.currentStep == 2 && !viewModel.isSplit)
                    {
                        Button("Done") {
                            HapticManager.tap()
                            viewModel.saveTransaction()
                        }
                        .font(AppTypography.bodyBold())
                        .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }

    // Dynamic navigation title based on current step
    private var navigationTitle: String {
        switch viewModel.currentStep {
        case 1: return "New Transaction"
        case 2: return "Split Options"
        case 3: return "Split Details"
        default: return ""
        }
    }
}
