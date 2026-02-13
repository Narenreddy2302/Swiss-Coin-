import CoreData
import SwiftUI

/// A compact split input view for the redesigned transaction form
/// Displays and allows editing of split amounts based on the selected split method
struct SplitInputView: View {
    @ObservedObject var viewModel: TransactionViewModel
    let person: Person

    private var personId: UUID {
        person.id ?? UUID()
    }

    private var currentInput: String {
        viewModel.rawInputs[personId] ?? ""
    }

    private var inputBinding: Binding<String> {
        Binding(
            get: { viewModel.rawInputs[personId] ?? "" },
            set: { viewModel.rawInputs[personId] = $0 }
        )
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            splitInput
        }
        .onAppear {
            initializeDefaultValues()
        }
    }

    // MARK: - Initialization

    private func initializeDefaultValues() {
        // Initialize with default values if empty
        if currentInput.isEmpty {
            let participantCount = max(1, viewModel.selectedParticipants.count)

            switch viewModel.splitMethod {
            case .percentage:
                let defaultPercent = 100.0 / Double(participantCount)
                viewModel.rawInputs[personId] = String(format: "%.1f", defaultPercent)

            case .adjustment:
                viewModel.rawInputs[personId] = "0"

            case .shares:
                viewModel.rawInputs[personId] = "1"

            default:
                break
            }
        }
    }

    // MARK: - Split Input

    @ViewBuilder
    private var splitInput: some View {
        switch viewModel.splitMethod {
        case .percentage:
            percentageInput

        case .adjustment:
            adjustmentInput

        case .shares:
            sharesInput

        default:
            EmptyView()
        }
    }

    // MARK: - Percentage Input

    private var percentageInput: some View {
        HStack(spacing: Spacing.sm) {
            TextField("0", text: inputBinding)
                .font(.system(size: IconSize.sm, weight: .bold, design: .default))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 50)

            Text("%")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Adjustment Input

    private var adjustmentInput: some View {
        HStack(spacing: Spacing.xs) {
            Text("±")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)

            Text(CurrencyFormatter.currencySymbol)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)

            TextField("0", text: inputBinding)
                .font(.system(size: IconSize.sm, weight: .bold, design: .default))
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 60)
        }
    }

    // MARK: - Shares Input

    private var sharesInput: some View {
        let currentShares = max(1, Int(currentInput) ?? 1)

        return HStack(spacing: Spacing.sm) {
            // Decrement button
            Button {
                guard currentShares > 1 else { return }
                viewModel.rawInputs[personId] = String(currentShares - 1)
                HapticManager.selectionChanged()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: IconSize.sm, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(AppColors.backgroundTertiary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Shares count
            Text("\(currentShares)")
                .font(.system(size: IconSize.sm, weight: .bold, design: .default))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 30)
                .multilineTextAlignment(.center)

            // Increment button
            Button {
                viewModel.rawInputs[personId] = String(currentShares + 1)
                HapticManager.selectionChanged()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: IconSize.sm, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(AppColors.backgroundTertiary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
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
