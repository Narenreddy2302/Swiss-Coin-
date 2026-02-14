import CoreData
import SwiftUI

// MARK: - Edit Transaction View
// Single-page scrollable form matching reference design (mirrors AddTransactionView)

struct TransactionEditView: View {
    private let transaction: FinancialTransaction
    @StateObject private var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FocusState private var focusedField: FocusField?

    @State private var showCurrencyPicker = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    private enum FocusField: Hashable {
        case title
        case amount
        case paidBySearch
        case splitWithSearch
    }

    init(transaction: FinancialTransaction) {
        self.transaction = transaction
        let ctx = transaction.managedObjectContext
            ?? PersistenceController.shared.container.viewContext
        let vm = TransactionViewModel(context: ctx)
        if !transaction.isDeleted {
            vm.loadTransaction(transaction)
        }
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    transactionNameSection
                    dateAndAmountSection
                    paidBySection
                    splitWithSection
                    splitMethodSection
                    if viewModel.selectedPayerPersons.count > 1 {
                        paidByBreakdownSection
                    }
                    breakdownSection
                    noteSection
                    validationSection
                    updateButton
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.cancel()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(AppTypography.bodyLarge())
                            .foregroundColor(AppColors.textPrimary)
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        focusedField = nil
                    }
                    .font(AppTypography.headingMedium())
                    .foregroundColor(AppColors.accent)
                }
            }
            .presentationDetents([.large])
            .sheet(isPresented: $showCurrencyPicker) {
                TransactionCurrencyPicker(selectedCurrencyCode: $viewModel.transactionCurrency)
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: viewModel.transactionCurrency) { _, newCurrency in
                if CurrencyFormatter.isZeroDecimal(newCurrency) {
                    if let dotIndex = viewModel.totalAmount.firstIndex(of: ".") {
                        viewModel.totalAmount = String(viewModel.totalAmount[..<dotIndex])
                    }
                }
            }
            .alert("Update Failed", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    // MARK: - Shared Helpers

    private func sortedByCurrentUser(_ people: Set<Person>) -> [Person] {
        Array(people).sorted { p1, p2 in
            let isCurrent1 = CurrentUser.isCurrentUser(p1.id)
            let isCurrent2 = CurrentUser.isCurrentUser(p2.id)
            if isCurrent1 != isCurrent2 { return isCurrent1 }
            return (p1.name ?? "") < (p2.name ?? "")
        }
    }

    private func shortName(for person: Person) -> String {
        CurrentUser.isCurrentUser(person.id) ? "You" : person.firstName
    }

    private func fullName(for person: Person) -> String {
        CurrentUser.isCurrentUser(person.id) ? "You" : (person.name ?? "Unknown")
    }

    private func personChip(_ person: Person, onRemove: @escaping () -> Void) -> some View {
        Button {
            withAnimation(AppAnimation.quick) { onRemove() }
            HapticManager.tap()
        } label: {
            Text(shortName(for: person))
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.buttonForeground)
                .lineLimit(1)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(AppColors.buttonBackground)
                .cornerRadius(CornerRadius.full)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transaction Name Section

    private var transactionNameSection: some View {
        TextField("Transaction Name", text: $viewModel.title)
            .font(AppTypography.bodyLarge())
            .foregroundColor(AppColors.textPrimary)
            .focused($focusedField, equals: .title)
            .submitLabel(.next)
            .onSubmit { focusedField = .amount }
            .limitTextLength(to: ValidationLimits.maxTransactionTitleLength, text: $viewModel.title)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.cardBackgroundElevated)
            .cornerRadius(CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }

    // MARK: - Date & Amount Section

    private var dateAndAmountSection: some View {
        HStack(spacing: 0) {
            DatePicker(
                "",
                selection: $viewModel.date,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(AppColors.textPrimary)
            .fixedSize()

            Spacer()

            Divider()
                .frame(height: 28)
                .padding(.horizontal, Spacing.md)

            Button {
                HapticManager.tap()
                focusedField = nil
                showCurrencyPicker = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.flag(for: viewModel.transactionCurrency))
                        .font(AppTypography.bodyDefault())
                    Text(CurrencyFormatter.symbol(for: viewModel.transactionCurrency))
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(AppColors.textSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.xs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Currency: \(viewModel.transactionCurrency). Tap to change.")

            TextField(
                CurrencyFormatter.isZeroDecimal(viewModel.transactionCurrency) ? "0" : "0.00",
                text: $viewModel.totalAmount
            )
                .font(AppTypography.financialLarge())
                .keyboardType(CurrencyFormatter.isZeroDecimal(viewModel.transactionCurrency) ? .numberPad : .decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .amount)
                .limitTextLength(to: 12, text: $viewModel.totalAmount)
                .frame(minWidth: 80)
                .onChange(of: viewModel.totalAmount) { _, newValue in
                    let sanitized = viewModel.sanitizeAmountInput(newValue)
                    if sanitized != newValue {
                        viewModel.totalAmount = sanitized
                    }
                }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.cardBackgroundElevated)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Paid By Section

    private var paidBySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Paid By:")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)

            HStack {
                TextField("Search Contact...", text: $viewModel.paidBySearchText)
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .focused($focusedField, equals: .paidBySearch)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: IconSize.sm, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.cardBackgroundElevated)
            .cornerRadius(CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(AppColors.border, lineWidth: 1)
            )

            if viewModel.paidBySearchText.isEmpty {
                payerChipsScroll
            } else {
                paidBySearchResults
            }
        }
    }

    private var payerChipsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                if viewModel.selectedPayerPersons.isEmpty {
                    Text("You")
                        .font(AppTypography.labelSmall())
                        .foregroundColor(AppColors.buttonForeground)
                        .lineLimit(1)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(AppColors.buttonBackground)
                        .cornerRadius(CornerRadius.full)
                } else {
                    ForEach(sortedByCurrentUser(viewModel.selectedPayerPersons), id: \.self) { person in
                        personChip(person) { viewModel.togglePayer(person) }
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private var paidBySearchResults: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button {
                    withAnimation(AppAnimation.quick) {
                        viewModel.toggleCurrentUserAsPayer(in: viewContext)
                        viewModel.paidBySearchText = ""
                    }
                    HapticManager.selectionChanged()
                    focusedField = .paidBySearch
                } label: {
                    searchResultRow(name: "You", isSelected: viewModel.isCurrentUserPayer && !viewModel.selectedPayerPersons.isEmpty)
                }
                .buttonStyle(.plain)

                ForEach(viewModel.filteredPaidByContacts, id: \.objectID) { person in
                    Divider().padding(.leading, Spacing.lg)

                    Button {
                        withAnimation(AppAnimation.quick) {
                            viewModel.togglePayer(person)
                            viewModel.paidBySearchText = ""
                        }
                        HapticManager.selectionChanged()
                        focusedField = .paidBySearch
                    } label: {
                        searchResultRow(
                            name: person.displayName,
                            isSelected: viewModel.selectedPayerPersons.contains(person)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 200)
        .background(AppColors.cardBackgroundElevated)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .padding(.top, Spacing.xs)
    }

    // MARK: - Split With Section

    private var splitWithSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Split with:")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)

            HStack {
                TextField("Search Contact...", text: $viewModel.splitWithSearchText)
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .focused($focusedField, equals: .splitWithSearch)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: IconSize.sm, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.cardBackgroundElevated)
            .cornerRadius(CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(AppColors.border, lineWidth: 1)
            )

            if viewModel.splitWithSearchText.isEmpty {
                participantChipsScroll
            } else {
                splitWithSearchResults
            }
        }
    }

    private var participantChipsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(sortedByCurrentUser(viewModel.selectedParticipants), id: \.self) { person in
                    personChip(person) { _ = viewModel.selectedParticipants.remove(person) }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private var splitWithSearchResults: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(viewModel.filteredSplitWithGroups, id: \.objectID) { group in
                    Button {
                        withAnimation(AppAnimation.quick) {
                            viewModel.selectGroup(group)
                            viewModel.splitWithSearchText = ""
                        }
                        HapticManager.selectionChanged()
                        focusedField = .splitWithSearch
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: IconSize.sm))
                                .foregroundColor(AppColors.accent)

                            Text(group.name ?? "Unnamed Group")
                                .font(AppTypography.bodyLarge())
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            Text("Add All")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.accent)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, Spacing.lg)
                }

                let validContacts = viewModel.filteredSplitWithContacts.filter { $0.id != nil }

                ForEach(Array(validContacts.enumerated()), id: \.element.objectID) { index, person in
                    Button {
                        withAnimation(AppAnimation.quick) {
                            viewModel.toggleParticipant(person)
                            viewModel.splitWithSearchText = ""
                        }
                        HapticManager.selectionChanged()
                        focusedField = .splitWithSearch
                    } label: {
                        searchResultRow(
                            name: person.displayName,
                            isSelected: viewModel.selectedParticipants.contains(person)
                        )
                    }
                    .buttonStyle(.plain)

                    if index < validContacts.count - 1 {
                        Divider().padding(.leading, Spacing.lg)
                    }
                }

                if validContacts.isEmpty && viewModel.filteredSplitWithGroups.isEmpty {
                    Text("No results found")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.vertical, Spacing.md)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxHeight: 200)
        .background(AppColors.cardBackgroundElevated)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .padding(.top, Spacing.xs)
    }

    // MARK: - Search Result Row

    private func searchResultRow(name: String, isSelected: Bool) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: IconSize.sm, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - Split Method Section

    private var splitMethodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Split Method:")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: Spacing.sm) {
                ForEach(SplitMethod.allCases) { method in
                    methodChip(method)
                }
            }
        }
    }

    private func methodChip(_ method: SplitMethod) -> some View {
        let isSelected = viewModel.splitMethod == method

        return Button {
            guard viewModel.splitMethod != method else { return }
            withAnimation(AppAnimation.standard) {
                viewModel.splitMethod = method
                viewModel.initializeDefaultRawInputs(for: method)
            }
            HapticManager.selectionChanged()
        } label: {
            VStack(spacing: Spacing.xxs) {
                Text(method.icon)
                    .font(.system(size: IconSize.md, weight: .bold))
                    .foregroundColor(isSelected ? AppColors.buttonForeground : AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(isSelected ? AppColors.buttonBackground : AppColors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
                    )

                Text(method.displayName)
                    .font(AppTypography.caption())
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Paid By Breakdown Section

    private var paidByBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Paid By:")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)

            let sortedPayers: [Person] = {
                if viewModel.selectedPayerPersons.isEmpty {
                    return [CurrentUser.getOrCreate(in: viewContext)]
                }
                return sortedByCurrentUser(viewModel.selectedPayerPersons)
            }()

            ForEach(sortedPayers, id: \.self) { person in
                payerAmountRow(person: person)
            }
        }
    }

    private func payerAmountRow(person: Person) -> some View {
        let name = fullName(for: person)
        let isSinglePayer = viewModel.selectedPayerPersons.count <= 1

        return HStack {
            Text(name)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: Spacing.xs) {
                Text(CurrencyFormatter.symbol(for: viewModel.transactionCurrency))
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)

                if isSinglePayer {
                    Text(String(format: "%.2f", viewModel.totalAmountDouble))
                        .font(AppTypography.financialDefault())
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 50, alignment: .trailing)
                } else {
                    TextField("0.00", text: payerAmountBinding(for: person))
                        .font(AppTypography.financialDefault())
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 50, alignment: .trailing)
                }
            }
        }
    }

    private func payerAmountBinding(for person: Person) -> Binding<String> {
        guard let personId = person.id else {
            return .constant("")
        }
        return Binding(
            get: { viewModel.payerAmounts[personId] ?? "" },
            set: { viewModel.payerAmounts[personId] = $0 }
        )
    }

    // MARK: - Breakdown Section

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Breakdown:")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)

            if viewModel.selectedParticipants.isEmpty {
                emptyBreakdownState
            } else if viewModel.isTwoPartySplit && viewModel.splitMethod == .equal {
                TwoPartySplitView(viewModel: viewModel)
            } else {
                participantBreakdownList
            }
        }
    }

    private var emptyBreakdownState: some View {
        HStack {
            Spacer()
            Text("Select participants to see breakdown")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .padding(.vertical, Spacing.lg)
    }

    private var participantBreakdownList: some View {
        VStack(spacing: Spacing.sm) {
            let sortedParticipants = sortedByCurrentUser(viewModel.selectedParticipants)

            ForEach(sortedParticipants, id: \.self) { person in
                breakdownRow(person: person)
                    .id("\(person.id?.uuidString ?? "unknown")-\(viewModel.splitMethod.rawValue)")
            }

            Divider()
                .padding(.top, Spacing.sm)

            HStack {
                Text("Total")
                    .font(AppTypography.labelLarge())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.symbol(for: viewModel.transactionCurrency))
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)

                    let balance = viewModel.totalBalance
                    Text(String(format: "%.2f", abs(balance)))
                        .font(AppTypography.financialDefault())
                        .foregroundColor(abs(balance) < 0.01 ? AppColors.textPrimary : AppColors.negative)
                        .frame(minWidth: 50, alignment: .trailing)
                }
            }
        }
    }

    private func breakdownRow(person: Person) -> some View {
        let name = fullName(for: person)
        let splitAmount = viewModel.calculateSplit(for: person)

        return HStack {
            Text(name)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if viewModel.splitMethod == .percentage
                || viewModel.splitMethod == .shares
                || viewModel.splitMethod == .adjustment {
                SplitInputView(viewModel: viewModel, person: person)
            }

            if viewModel.splitMethod == .amount {
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.symbol(for: viewModel.transactionCurrency))
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)

                    TextField("0.00", text: rawInputBinding(for: person))
                        .font(AppTypography.financialDefault())
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 50, alignment: .trailing)
                }
                .onAppear { initializeAmountDefault(for: person) }
            } else {
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.symbol(for: viewModel.transactionCurrency))
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)

                    Text(String(format: "%.2f", splitAmount))
                        .font(AppTypography.financialDefault())
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 50, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Breakdown Helpers

    private func rawInputBinding(for person: Person) -> Binding<String> {
        guard let personId = person.id else {
            return .constant("")
        }
        return Binding(
            get: { viewModel.rawInputs[personId] ?? "" },
            set: { viewModel.rawInputs[personId] = $0 }
        )
    }

    private func initializeAmountDefault(for person: Person) {
        guard let personId = person.id else { return }
        if (viewModel.rawInputs[personId] ?? "").isEmpty {
            let count = max(1, viewModel.selectedParticipants.count)
            let defaultAmount = viewModel.totalAmountDouble / Double(count)
            viewModel.rawInputs[personId] = String(format: "%.2f", defaultAmount)
        }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Note:")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)

            TextField("Add a note (optional)", text: $viewModel.note, axis: .vertical)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1...4)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(AppColors.cardBackgroundElevated)
                .cornerRadius(CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Validation Section

    @ViewBuilder
    private var validationSection: some View {
        if let validationMessage = viewModel.validationMessage {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: IconSize.sm))
                    .foregroundColor(AppColors.warning)

                Text(validationMessage)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(AppColors.warning.opacity(0.08))
            )
        }
    }

    // MARK: - Update Button

    private var updateButton: some View {
        Button {
            HapticManager.tap()
            viewModel.updateTransaction(transaction) { success in
                if success {
                    dismiss()
                } else {
                    saveErrorMessage = viewModel.validationMessage ?? "Failed to save changes. Please try again."
                    showSaveError = true
                }
            }
        } label: {
            Text("Update Transaction")
                .font(AppTypography.buttonLarge())
                .foregroundColor(AppColors.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.lg)
                .background(AppColors.accent)
                .cornerRadius(CornerRadius.button)
        }
        .disabled(!viewModel.isValid)
        .opacity(viewModel.isValid ? 1.0 : 0.5)
    }
}

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let transaction: FinancialTransaction = {
        let t = FinancialTransaction(context: context)
        t.id = UUID()
        t.title = "Test Transaction"
        t.amount = 100.00
        t.date = Date()
        t.splitMethod = "equal"
        return t
    }()

    TransactionEditView(transaction: transaction)
        .environment(\.managedObjectContext, context)
}
