import SwiftUI

struct SplitInputView: View {
    @ObservedObject var viewModel: TransactionViewModel
    var person: Person

    var body: some View {
        HStack {
            Text(person.name ?? "Unknown")
            Spacer()

            switch viewModel.splitMethod {
            case .equal:
                Text(String(format: "$%.2f", viewModel.calculateSplit(for: person)))
                    .foregroundColor(.gray)
            case .percentage:
                HStack {
                    TextField(
                        "0",
                        text: Binding(
                            get: { viewModel.rawInputs[person.id ?? UUID()] ?? "" },
                            set: { viewModel.rawInputs[person.id ?? UUID()] = $0 }
                        )
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    Text("%")
                }
            case .exact:
                HStack {
                    Text("$")
                    TextField(
                        "0.00",
                        text: Binding(
                            get: { viewModel.rawInputs[person.id ?? UUID()] ?? "" },
                            set: { viewModel.rawInputs[person.id ?? UUID()] = $0 }
                        )
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                }
            case .adjustment:
                HStack {
                    Text("+/- $")
                    TextField(
                        "0",
                        text: Binding(
                            get: { viewModel.rawInputs[person.id ?? UUID()] ?? "" },
                            set: { viewModel.rawInputs[person.id ?? UUID()] = $0 }
                        )
                    )
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                }
            case .shares:
                Stepper(
                    value: Binding(
                        get: { Int(viewModel.rawInputs[person.id ?? UUID()] ?? "1") ?? 1 },
                        set: { viewModel.rawInputs[person.id ?? UUID()] = String($0) }
                    ), in: 1...100
                ) {
                    Text("\(viewModel.rawInputs[person.id ?? UUID()] ?? "1") Share(s)")
                }
            }
        }
    }
}
