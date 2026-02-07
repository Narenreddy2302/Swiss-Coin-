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
        HStack(spacing: Spacing.md) {
            // Avatar
            Circle()
                .fill(person.avatarBackgroundColor)
                .frame(width: AvatarSize.xs, height: AvatarSize.xs)
                .overlay(
                    Text(CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(person.avatarTextColor)
                )

            // Name
            Text(CurrentUser.isCurrentUser(person.id) ? "Me" : (person.name ?? "Unknown"))
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: Spacing.sm)

            // Input based on split method
            splitInput
        }
        .onAppear {
            // Initialize with default values if empty
            if currentInput.isEmpty {
                switch viewModel.splitMethod {
                case .percentage:
                    let defaultPercent = viewModel.selectedParticipants.isEmpty ? 100.0 : (100.0 / Double(viewModel.selectedParticipants.count))
                    viewModel.rawInputs[personId] = String(format: "%.1f", defaultPercent)
                case .amount:
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

    @ViewBuilder
    private var splitInput: some View {
        switch viewModel.splitMethod {
        case .equal:
            Text(CurrencyFormatter.format(viewModel.calculateSplit(for: person)))
                .font(AppTypography.amount())
                .foregroundColor(AppColors.textPrimary)

        case .percentage:
            HStack(spacing: Spacing.xxs) {
                TextField("0", text: inputBinding)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 56)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.xs)
                            .fill(AppColors.backgroundTertiary)
                    )
                Text("%")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
            }

        case .amount:
            HStack(spacing: Spacing.xxs) {
                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
                TextField("0.00", text: inputBinding)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 72)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.xs)
                            .fill(AppColors.backgroundTertiary)
                    )
            }

        case .adjustment:
            HStack(spacing: Spacing.xxs) {
                Text("+/-")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
                TextField("0", text: inputBinding)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 56)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.xs)
                            .fill(AppColors.backgroundTertiary)
                    )
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
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)
            }
        }
    }
}
