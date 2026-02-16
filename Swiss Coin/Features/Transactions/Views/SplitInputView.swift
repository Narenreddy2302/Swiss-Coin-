import CoreData
import SwiftUI

/// Input control for split amounts — adapts based on split method.
/// Used inside the breakdown section of AddTransactionView.
struct SplitInputView: View {
    @ObservedObject var viewModel: TransactionViewModel
    let person: Person

    private var personId: UUID {
        person.id ?? UUID()
    }

    private var rawBinding: Binding<String> {
        Binding(
            get: { viewModel.rawInputs[personId] ?? "" },
            set: { viewModel.rawInputs[personId] = $0 }
        )
    }

    var body: some View {
        switch viewModel.splitMethod {
        case .percentage:
            percentageInput
        case .shares:
            sharesInput
        case .adjustment:
            adjustmentInput
        default:
            EmptyView()
        }
    }

    // MARK: - Percentage Input

    private var percentageInput: some View {
        HStack(spacing: Spacing.xs) {
            TextField("0", text: rawBinding)
                .font(AppTypography.financialSmall())
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppColors.textPrimary)
                .frame(minWidth: 40, alignment: .trailing)
                .accessibilityLabel("Percentage for \(person.displayName)")

            Text("%")
                .font(AppTypography.labelDefault())
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(AppColors.backgroundTertiary)
        )
        .onAppear { initializePercentageDefault() }
    }

    // MARK: - Shares Input (Stepper)

    private var sharesInput: some View {
        let currentShares = Int(Double(viewModel.rawInputs[personId] ?? "1") ?? 1)

        return HStack(spacing: Spacing.sm) {
            // Minus button
            Button {
                let newVal = max(0, currentShares - 1)
                viewModel.rawInputs[personId] = "\(newVal)"
                HapticManager.lightTap()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: IconSize.xs, weight: .semibold))
                    .foregroundColor(currentShares > 0 ? AppColors.textPrimary : AppColors.disabled)
                    .frame(width: IconSize.category, height: IconSize.category)
                    .background(
                        Circle().fill(AppColors.backgroundTertiary)
                    )
            }
            .buttonStyle(.plain)
            .disabled(currentShares <= 0)
            .accessibilityLabel("Decrease shares")

            // Share count
            Text("\(currentShares)")
                .font(AppTypography.financialSmall())
                .foregroundColor(AppColors.textPrimary)
                .frame(minWidth: 24)

            // Plus button
            Button {
                let newVal = currentShares + 1
                viewModel.rawInputs[personId] = "\(newVal)"
                HapticManager.lightTap()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: IconSize.xs, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: IconSize.category, height: IconSize.category)
                    .background(
                        Circle().fill(AppColors.backgroundTertiary)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Increase shares")
        }
        .onAppear { initializeSharesDefault() }
    }

    // MARK: - Adjustment Input

    private var adjustmentInput: some View {
        HStack(spacing: Spacing.xs) {
            Text("±")
                .font(AppTypography.labelDefault())
                .foregroundColor(AppColors.textSecondary)

            TextField("0", text: rawBinding)
                .font(AppTypography.financialSmall())
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppColors.textPrimary)
                .frame(minWidth: 40, alignment: .trailing)
                .accessibilityLabel("Adjustment for \(person.displayName)")
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(AppColors.backgroundTertiary)
        )
        .onAppear { initializeAdjustmentDefault() }
    }

    // MARK: - Default Initialization

    private func initializePercentageDefault() {
        if (viewModel.rawInputs[personId] ?? "").isEmpty {
            let count = max(1, viewModel.selectedParticipants.count)
            let defaultPercent = 100.0 / Double(count)
            viewModel.rawInputs[personId] = String(format: "%.1f", defaultPercent)
        }
    }

    private func initializeSharesDefault() {
        if (viewModel.rawInputs[personId] ?? "").isEmpty {
            viewModel.rawInputs[personId] = "1"
        }
    }

    private func initializeAdjustmentDefault() {
        if (viewModel.rawInputs[personId] ?? "").isEmpty {
            viewModel.rawInputs[personId] = "0"
        }
    }
}

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let viewModel: TransactionViewModel = {
        let vm = TransactionViewModel(context: context)
        vm.totalAmount = "100"
        vm.splitMethod = .percentage
        return vm
    }()

    let person: Person = {
        let p = Person(context: context)
        p.id = UUID()
        p.name = "John Doe"
        p.colorHex = "#007AFF"
        return p
    }()

    SplitInputView(viewModel: viewModel, person: person)
        .padding()
        .background(AppColors.backgroundSecondary)
}
