import CoreData
import SwiftUI

// MARK: - Add Transaction View
// Single-page scrollable form matching reference design

struct AddTransactionView: View {
    @StateObject private var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FocusState private var focusedField: FocusField?

    @AppStorage("default_currency") private var selectedCurrency: String = "USD"
    @State private var showCurrencyPicker = false

    var initialParticipant: Person?
    var initialGroup: UserGroup?

    private enum FocusField: Hashable {
        case title
        case amount
        case paidBySearch
        case splitWithSearch
    }

    init(viewContext: NSManagedObjectContext? = nil, initialParticipant: Person? = nil, initialGroup: UserGroup? = nil) {
        self.initialParticipant = initialParticipant
        self.initialGroup = initialGroup
        let ctx = viewContext
            ?? initialParticipant?.managedObjectContext
            ?? initialGroup?.managedObjectContext
            ?? PersistenceController.shared.container.viewContext
        _viewModel = StateObject(
            wrappedValue: TransactionViewModel(context: ctx))
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
                    saveButton
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.backgroundSecondary)
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .onAppear {
                setupInitialParticipants()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = .title
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

    // MARK: - Setup

    private func setupInitialParticipants() {
        if let person = initialParticipant {
            viewModel.selectedParticipants.insert(person)
        }
        if let group = initialGroup {
            viewModel.selectedGroup = group
            let members = group.members as? Set<Person> ?? []
            for member in members {
                viewModel.selectedParticipants.insert(member)
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
            let sortedParticipants = sortedByCurrentUser(viewModel.selectedParticipants)

            ForEach(sortedParticipants, id: \.self) { person in
                breakdownRow(person: person)
                    .id("\(person.id?.uuidString ?? "unknown")-\(viewModel.splitMethod.rawValue)")
            }

            Divider()
                .padding(.top, Spacing.sm)

            HStack {
                Text("Total")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.currencySymbol)
                        .font(AppTypography.subheadline())
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

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            HapticManager.tap()
            viewModel.saveTransaction { success in
                if success {
                    dismiss()
                }
            }
        } label: {
            Text("Save Transaction")
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
    AddTransactionView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
