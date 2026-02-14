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

    @AppStorage("default_currency") private var selectedCurrency: String = "USD"
    @State private var showCurrencyPicker = false

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
        vm.loadTransaction(transaction)
        _viewModel = StateObject(wrappedValue: vm)
    }

    // MARK: - Computed Properties

    private var currentCurrency: Currency {
        Currency.all.first(where: { $0.code == selectedCurrency }) ?? Currency.all[0]
    }

    private var currencyBinding: Binding<Currency> {
        Binding(
            get: { currentCurrency },
            set: { selectedCurrency = $0.code }
        )
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
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        focusedField = nil
                    }
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.accent)
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerSheet(
                    selectedCurrency: currencyBinding,
                    isPresented: $showCurrencyPicker
                )
                .presentationDetents([.medium, .large])
            }
            .presentationDetents([.large])
        }
    }

    // MARK: - Transaction Name Section

    private var transactionNameSection: some View {
        TextField("Transaction Name", text: $viewModel.title)
            .font(AppTypography.body())
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
                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(AppColors.backgroundTertiary)
                    .cornerRadius(CornerRadius.xs)
            }
            .buttonStyle(.plain)

            TextField("0.00", text: $viewModel.totalAmount)
                .font(AppTypography.financialLarge())
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .amount)
                .limitTextLength(to: 12, text: $viewModel.totalAmount)
                .frame(minWidth: 80)
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
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(AppColors.textPrimary)

            HStack {
                TextField("Search Contact...", text: $viewModel.paidBySearchText)
                    .font(AppTypography.body())
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
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.buttonForeground)
                        .lineLimit(1)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(AppColors.buttonBackground)
                        .cornerRadius(CornerRadius.md)
                } else {
                    let sortedPayers = Array(viewModel.selectedPayerPersons).sorted { p1, p2 in
                        let isCurrentUser1 = CurrentUser.isCurrentUser(p1.id)
                        let isCurrentUser2 = CurrentUser.isCurrentUser(p2.id)
                        if isCurrentUser1 && !isCurrentUser2 { return true }
                        if !isCurrentUser1 && isCurrentUser2 { return false }
                        return (p1.name ?? "") < (p2.name ?? "")
                    }

                    ForEach(sortedPayers, id: \.self) { person in
                        removablePayerChip(person)
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private func removablePayerChip(_ person: Person) -> some View {
        let name = CurrentUser.isCurrentUser(person.id) ? "You" : person.firstName

        return Button {
            withAnimation(AppAnimation.quick) {
                viewModel.togglePayer(person)
            }
            HapticManager.tap()
        } label: {
            Text(name)
                .font(AppTypography.caption())
                .foregroundColor(AppColors.buttonForeground)
                .lineLimit(1)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(AppColors.buttonBackground)
                .cornerRadius(CornerRadius.md)
        }
        .buttonStyle(.plain)
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
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(AppColors.textPrimary)

            HStack {
                TextField("Search Contact...", text: $viewModel.splitWithSearchText)
                    .font(AppTypography.body())
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
                let sortedParticipants = Array(viewModel.selectedParticipants).sorted { p1, p2 in
                    let isCurrentUser1 = CurrentUser.isCurrentUser(p1.id)
                    let isCurrentUser2 = CurrentUser.isCurrentUser(p2.id)
                    if isCurrentUser1 && !isCurrentUser2 { return true }
                    if !isCurrentUser1 && isCurrentUser2 { return false }
                    return (p1.name ?? "") < (p2.name ?? "")
                }

                ForEach(sortedParticipants, id: \.self) { person in
                    removableParticipantChip(person)
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private func removableParticipantChip(_ person: Person) -> some View {
        let name = CurrentUser.isCurrentUser(person.id) ? "You" : person.firstName

        return Button {
            withAnimation(AppAnimation.quick) {
                _ = viewModel.selectedParticipants.remove(person)
            }
            HapticManager.tap()
        } label: {
            Text(name)
                .font(AppTypography.caption())
                .foregroundColor(AppColors.buttonForeground)
                .lineLimit(1)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(AppColors.buttonBackground)
                .cornerRadius(CornerRadius.md)
        }
        .buttonStyle(.plain)
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
                                .font(AppTypography.body())
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
                        .font(AppTypography.subheadline())
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
                .font(AppTypography.body())
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
                .font(AppTypography.subheadlineMedium())
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
            withAnimation(AppAnimation.standard) {
                viewModel.splitMethod = method
                viewModel.rawInputs = [:]
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
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(AppColors.textPrimary)

            let sortedPayers: [Person] = {
                if viewModel.selectedPayerPersons.isEmpty {
                    if let currentUser = try? viewContext.fetch(Person.fetchRequest()).first(where: { CurrentUser.isCurrentUser($0.id) }) {
                        return [currentUser]
                    }
                    return []
                }
                return Array(viewModel.selectedPayerPersons).sorted { p1, p2 in
                    let isCurrentUser1 = CurrentUser.isCurrentUser(p1.id)
                    let isCurrentUser2 = CurrentUser.isCurrentUser(p2.id)
                    if isCurrentUser1 && !isCurrentUser2 { return true }
                    if !isCurrentUser1 && isCurrentUser2 { return false }
                    return (p1.name ?? "") < (p2.name ?? "")
                }
            }()

            ForEach(sortedPayers, id: \.self) { person in
                payerAmountRow(person: person)
            }
        }
    }

    private func payerAmountRow(person: Person) -> some View {
        let name = CurrentUser.isCurrentUser(person.id) ? "You" : (person.name ?? "Unknown")
        let isSinglePayer = viewModel.selectedPayerPersons.count <= 1

        return HStack {
            Text(name)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: Spacing.xs) {
                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.subheadline())
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
        let personId = person.id ?? UUID()
        return Binding(
            get: { viewModel.payerAmounts[personId] ?? "" },
            set: { viewModel.payerAmounts[personId] = $0 }
        )
    }

    // MARK: - Breakdown Section

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Breakdown:")
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(AppColors.textPrimary)

            if viewModel.selectedParticipants.isEmpty {
                emptyBreakdownState
            } else {
                participantBreakdownList
            }
        }
    }

    private var emptyBreakdownState: some View {
        HStack {
            Spacer()
            Text("Select participants to see breakdown")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .padding(.vertical, Spacing.lg)
    }

    private var participantBreakdownList: some View {
        VStack(spacing: Spacing.sm) {
            let sortedParticipants = Array(viewModel.selectedParticipants).sorted { p1, p2 in
                let isCurrentUser1 = CurrentUser.isCurrentUser(p1.id)
                let isCurrentUser2 = CurrentUser.isCurrentUser(p2.id)
                if isCurrentUser1 && !isCurrentUser2 { return true }
                if !isCurrentUser1 && isCurrentUser2 { return false }
                return (p1.name ?? "") < (p2.name ?? "")
            }

            ForEach(sortedParticipants, id: \.self) { person in
                breakdownRow(person: person)
                    .id("\(person.id?.uuidString ?? "unknown")-\(viewModel.splitMethod.rawValue)")
            }

            HStack {
                Spacer()
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(width: 200, height: 1)
            }
            .padding(.top, Spacing.sm)

            HStack {
                Text("Total Balance")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)

                let balance = viewModel.totalBalance
                Text(String(format: "%.2f", abs(balance)))
                    .font(AppTypography.financialDefault())
                    .foregroundColor(abs(balance) < 0.01 ? AppColors.textPrimary : AppColors.negative)
                    .frame(minWidth: 50, alignment: .trailing)
            }

            HStack {
                Spacer()
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(width: 200, height: 1)
            }
        }
    }

    private func breakdownRow(person: Person) -> some View {
        let name = CurrentUser.isCurrentUser(person.id) ? "You" : (person.name ?? "Unknown")
        let splitAmount = viewModel.calculateSplit(for: person)

        return HStack {
            Text(name)
                .font(AppTypography.subheadline())
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
                    Text(CurrencyFormatter.currencySymbol)
                        .font(AppTypography.subheadline())
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
                    Text(CurrencyFormatter.currencySymbol)
                        .font(AppTypography.subheadline())
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
        let personId = person.id ?? UUID()
        return Binding(
            get: { viewModel.rawInputs[personId] ?? "" },
            set: { viewModel.rawInputs[personId] = $0 }
        )
    }

    private func initializeAmountDefault(for person: Person) {
        let personId = person.id ?? UUID()
        if (viewModel.rawInputs[personId] ?? "").isEmpty {
            let count = max(1, viewModel.selectedParticipants.count)
            let defaultAmount = viewModel.totalAmountDouble / Double(count)
            viewModel.rawInputs[personId] = String(format: "%.2f", defaultAmount)
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
                    .font(AppTypography.footnote())
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
                }
            }
        } label: {
            Text("Update Transaction")
                .font(AppTypography.labelLarge())
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.lg)
                .background(AppColors.cardBackground)
                .cornerRadius(CornerRadius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.button)
                        .stroke(AppColors.textPrimary, lineWidth: 1)
                )
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
