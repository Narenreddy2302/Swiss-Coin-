import SwiftUI

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
        HStack {
            Text(person.name ?? "Unknown")
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
            Spacer()

            switch viewModel.splitMethod {
            case .equal:
                Text(CurrencyFormatter.format(viewModel.calculateSplit(for: person)))
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textSecondary)
            
            case .percentage:
                HStack(spacing: Spacing.xs) {
                    TextField("0", text: inputBinding)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                    Text("%")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textSecondary)
                }
            
            case .exact:
                HStack(spacing: Spacing.xs) {
                    Text("$")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textSecondary)
                    TextField("0.00", text: inputBinding)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }
            
            case .adjustment:
                HStack(spacing: Spacing.xs) {
                    Text("+/- $")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                    TextField("0", text: inputBinding)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                }
            
            case .shares:
                Stepper(
                    value: Binding(
                        get: { max(1, Int(currentInput) ?? 1) },
                        set: { viewModel.rawInputs[personId] = String($0) }
                    ), 
                    in: 1...100
                ) {
                    let shares = max(1, Int(currentInput) ?? 1)
                    Text("\(shares) Share\(shares == 1 ? "" : "s")")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .onAppear {
            // Initialize with default values if empty
            if currentInput.isEmpty {
                switch viewModel.splitMethod {
                case .percentage:
                    let defaultPercent = viewModel.selectedParticipants.isEmpty ? 100 : (100 / viewModel.selectedParticipants.count)
                    viewModel.rawInputs[personId] = String(defaultPercent)
                case .exact:
                    let defaultAmount = viewModel.totalAmountDouble / max(1, Double(viewModel.selectedParticipants.count))
                    viewModel.rawInputs[personId] = String(format: "%.2f", defaultAmount)
                case .adjustment:
                    viewModel.rawInputs[personId] = "0"
                case .shares:
                    viewModel.rawInputs[personId] = "1"
                case .equal:
                    break // No input needed for equal split
                }
            }
        }
    }
}
