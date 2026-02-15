import SwiftUI
import CoreData

// MARK: - AddTransactionView

struct AddTransactionView: View {

    // MARK: - Environment

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State Properties

    @StateObject private var viewModel: TransactionViewModel
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var showingDatePicker = false
    @State private var showingCategoryPicker = false
    @State private var showingCurrencyPicker = false

    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: TransactionViewModel(context: context))
    }

    init(viewModel: TransactionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                transactionNameField
                dateAndAmountRow
                paidBySection
                splitWithSection
                splitMethodSection

                if !viewModel.selectedPayerPersons.isEmpty {
                    paidByAmountsSection
                }

                breakdownSection
                totalBalanceSection
                saveButton
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.screenTopPad)
            .padding(.bottom, Spacing.xxxl)
        }
        .background(AppColors.backgroundSecondary)
        .navigationTitle("New Transaction")
        .navigationBarTitleDisplayMode(.large)
        .alert("Validation Error", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
    }

    // MARK: - Transaction Name Field

    private var transactionNameField: some View {
        TextField("Transaction Name", text: $viewModel.title)
            .font(AppTypography.bodyDefault())
            .padding(.horizontal, Spacing.lg)
            .frame(height: ButtonHeight.lg)
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            .accessibilityLabel("Transaction name")
    }

    // MARK: - Date & Amount Row

    private var dateAndAmountRow: some View {
        HStack(spacing: 0) {
            Button(action: { showingDatePicker.toggle() }) {
                Text(formattedDate)
                    .font(AppTypography.headingSmall())
                    .foregroundColor(AppColors.textPrimary)
            }
            .popover(isPresented: $showingDatePicker) {
                VStack {
                    DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                    Button("Done") {
                        showingDatePicker = false
                    }
                    .padding(.bottom)
                }
            }

            Spacer()

            Button(action: {
                HapticManager.lightTap()
                showingCurrencyPicker = true
            }) {
                HStack(spacing: Spacing.xs) {
                    Text(currencySymbol)
                        .font(AppTypography.headingSmall())
                        .foregroundColor(AppColors.textPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: IconSize.xs))
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            TextField("0.00", text: $viewModel.totalAmount)
                .font(AppTypography.headingMedium())
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
                .onChange(of: viewModel.totalAmount) { _, newValue in
                    viewModel.totalAmount = viewModel.sanitizeAmountInput(newValue)
                }
                .accessibilityLabel("Transaction amount")
        }
        .padding(.horizontal, Spacing.lg)
        .frame(height: ButtonHeight.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .sheet(isPresented: $showingCurrencyPicker) {
            TransactionCurrencyPicker(selectedCurrencyCode: $viewModel.transactionCurrency)
        }
    }

    // MARK: - Paid By Section

    private var paidBySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Paid By:")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)

            searchContactField(
                text: $viewModel.paidBySearchText,
                placeholder: "Search Contact..."
            )

            if !viewModel.paidBySearchText.isEmpty {
                if !viewModel.filteredPaidByContacts.isEmpty || !viewModel.filteredPaidByPhoneContacts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            // Existing persons
                            ForEach(viewModel.filteredPaidByContacts.prefix(10)) { contact in
                                Button(action: {
                                    viewModel.togglePayer(contact)
                                    viewModel.paidBySearchText = ""
                                }) {
                                    contactChip(
                                        name: contact.name ?? "Unknown",
                                        isSelected: viewModel.selectedPayerPersons.contains(contact)
                                    )
                                }
                            }
                            // Phone contacts
                            ForEach(viewModel.filteredPaidByPhoneContacts.prefix(5)) { contact in
                                Button(action: {
                                    viewModel.addPhoneContactAsPayer(contact)
                                }) {
                                    phoneContactChip(contact: contact)
                                }
                            }
                        }
                    }
                    .frame(height: 40)
                }
            }

            contactChipsRow(
                contacts: viewModel.selectedPayerPersons.sorted { ($0.name ?? "") < ($1.name ?? "") },
                isRemovable: true,
                onRemove: { person in
                    viewModel.togglePayer(person)
                },
                emptyText: "You"
            )
        }
    }

    // MARK: - Split With Section

    private var splitWithSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Split with:")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)

            searchContactField(
                text: $viewModel.splitWithSearchText,
                placeholder: "Search Contact..."
            )

            if !viewModel.splitWithSearchText.isEmpty {
                if !viewModel.filteredSplitWithContacts.isEmpty || !viewModel.filteredSplitWithPhoneContacts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            // Existing persons
                            ForEach(viewModel.filteredSplitWithContacts.prefix(10)) { contact in
                                Button(action: {
                                    viewModel.toggleParticipant(contact)
                                    viewModel.splitWithSearchText = ""
                                }) {
                                    contactChip(
                                        name: contact.name ?? "Unknown",
                                        isSelected: viewModel.selectedParticipants.contains(contact)
                                    )
                                }
                            }
                            // Phone contacts
                            ForEach(viewModel.filteredSplitWithPhoneContacts.prefix(5)) { contact in
                                Button(action: {
                                    viewModel.addPhoneContactAsParticipant(contact)
                                }) {
                                    phoneContactChip(contact: contact)
                                }
                            }
                        }
                    }
                    .frame(height: 40)
                }
            }

            contactChipsRow(
                contacts: viewModel.selectedParticipants.sorted { ($0.name ?? "") < ($1.name ?? "") },
                isRemovable: true,
                onRemove: { person in
                    viewModel.toggleParticipant(person)
                }
            )
        }
    }

    // MARK: - Split Method Section

    private var splitMethodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Split Method:")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: 0) {
                ForEach(Array(SplitMethod.allCases.enumerated()), id: \.element) { index, method in
                    splitMethodButton(method: method)
                    if index < SplitMethod.allCases.count - 1 && viewModel.splitMethod != method && viewModel.splitMethod != SplitMethod.allCases[index + 1] {
                        Divider()
                            .frame(height: IconSize.lg)
                            .foregroundColor(AppColors.border)
                    }
                }
            }
            .padding(Spacing.xs)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.medium)
        }
    }

    // MARK: - Paid By Amounts Section

    private var paidByAmountsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("PAID BY")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textSecondary)
                .tracking(0.5)

            let sortedPayers = viewModel.selectedPayerPersons.sorted { ($0.name ?? "") < ($1.name ?? "") }
            VStack(spacing: 0) {
                ForEach(Array(sortedPayers.enumerated()), id: \.element) { index, payer in
                    if viewModel.selectedPayerPersons.count > 1, let payerId = payer.id {
                        editableAmountRow(
                            name: payer.name ?? "Unknown",
                            amount: Binding(
                                get: { viewModel.payerAmounts[payerId] ?? "0.00" },
                                set: { viewModel.payerAmounts[payerId] = viewModel.sanitizeAmountInput($0) }
                            )
                        )
                    } else {
                        amountRow(name: payer.name ?? "Unknown", amount: viewModel.totalAmountDouble)
                    }
                    if index < sortedPayers.count - 1 {
                        AppColors.divider.frame(height: 0.5)
                    }
                }
            }
        }
    }

    // MARK: - Breakdown Section

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("SPLIT BREAKDOWN")
                .font(AppTypography.labelSmall())
                .foregroundColor(AppColors.textSecondary)
                .tracking(0.5)

            let sortedParticipants = viewModel.selectedParticipants.sorted { ($0.name ?? "") < ($1.name ?? "") }
            VStack(spacing: 0) {
                ForEach(Array(sortedParticipants.enumerated()), id: \.element) { index, person in
                    if let personId = person.id {
                        breakdownRow(for: person, personId: personId)
                    }
                    if index < sortedParticipants.count - 1 {
                        AppColors.divider.frame(height: 0.5)
                    }
                }
            }
        }
    }

    // MARK: - Breakdown Row

    @ViewBuilder
    private func breakdownRow(for person: Person, personId: UUID) -> some View {
        switch viewModel.splitMethod {
        case .equal:
            amountRow(
                name: person.name ?? "Unknown",
                amount: viewModel.calculateSplit(for: person)
            )
        case .amount:
            editableAmountRow(
                name: person.name ?? "Unknown",
                amount: Binding(
                    get: { viewModel.rawInputs[personId] ?? "0.00" },
                    set: { viewModel.rawInputs[personId] = viewModel.sanitizeAmountInput($0) }
                )
            )
        case .percentage:
            editablePercentageRow(
                name: person.name ?? "Unknown",
                percentage: Binding(
                    get: { viewModel.rawInputs[personId] ?? "0" },
                    set: { newValue in
                        let filtered = newValue.filter { $0.isNumber || $0 == "." }
                        if let value = Double(filtered), value <= 100 {
                            viewModel.rawInputs[personId] = filtered
                        } else if filtered.isEmpty {
                            viewModel.rawInputs[personId] = ""
                        }
                    }
                )
            )
        case .shares:
            editableSharesRow(
                name: person.name ?? "Unknown",
                shares: Binding(
                    get: { viewModel.rawInputs[personId] ?? "1" },
                    set: { newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        viewModel.rawInputs[personId] = filtered.isEmpty ? "1" : filtered
                    }
                )
            )
        case .adjustment:
            editableAdjustmentRow(
                name: person.name ?? "Unknown",
                adjustment: Binding(
                    get: { viewModel.rawInputs[personId] ?? "0" },
                    set: { viewModel.rawInputs[personId] = viewModel.sanitizeAmountInput($0) }
                ),
                calculatedAmount: viewModel.calculateSplit(for: person)
            )
        }
    }

    // MARK: - Total Balance Section

    private var totalBalanceSection: some View {
        VStack(spacing: 0) {
            AppColors.divider.frame(height: 0.5)

            HStack {
                Text("Total")
                    .font(AppTypography.headingSmall())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(FinancialFormatter.currency(abs(viewModel.totalBalance), currencyCode: viewModel.transactionCurrency))
                    .font(AppTypography.headingSmall())
                    .foregroundColor(abs(viewModel.totalBalance) < 0.01 ? AppColors.positive : AppColors.negative)
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: saveTransaction) {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.onAccent))
                } else {
                    Text("Save Transaction")
                        .font(AppTypography.buttonLarge())
                        .foregroundColor(AppColors.onAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppColors.accent,
                        AppColors.accent.opacity(0.85)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(CornerRadius.card)
            .shadow(color: AppColors.accent.opacity(0.3), radius: 6, x: 0, y: 4)
        }
        .disabled(viewModel.isSaving || !viewModel.isValid)
        .opacity(viewModel.isSaving || !viewModel.isValid ? 0.6 : 1.0)
        .padding(.top, Spacing.md)
        .accessibilityLabel("Save transaction")
    }

    // MARK: - Reusable Components

    private func searchContactField(text: Binding<String>, placeholder: String) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .font(AppTypography.bodyDefault())

            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)
                .font(.system(size: IconSize.sm))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private func contactChipsRow(contacts: [Person], isRemovable: Bool = false, onRemove: ((Person) -> Void)? = nil, emptyText: String? = nil) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                if contacts.isEmpty, let emptyText = emptyText {
                    contactChip(name: emptyText, isSelected: false)
                } else {
                    ForEach(contacts, id: \.self) { contact in
                        if isRemovable {
                            Button(action: {
                                HapticManager.lightTap()
                                onRemove?(contact)
                            }) {
                                contactChip(name: contact.name ?? "Unknown", isSelected: true)
                            }
                            .buttonStyle(AppButtonStyle())
                        } else {
                            contactChip(name: contact.name ?? "Unknown", isSelected: true)
                        }
                    }
                }
            }
        }
    }

    private func phoneContactChip(contact: ContactsManager.PhoneContact) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: IconSize.sm))
                .foregroundColor(AppColors.accent)

            Text(contact.fullName)
                .font(AppTypography.labelDefault())
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.compactVertical)
        .background(AppColors.surface)
        .cornerRadius(CornerRadius.full)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.full)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private func contactChip(name: String, isSelected: Bool) -> some View {
        Text(name)
            .font(AppTypography.labelDefault())
            .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textTertiary)
            .lineLimit(1)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.compactVertical)
            .background(isSelected ? AppColors.backgroundTertiary : AppColors.surface)
            .cornerRadius(CornerRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.full)
                    .stroke(isSelected ? AppColors.borderStrong : AppColors.border, lineWidth: 1)
            )
    }

    private func splitMethodButton(method: SplitMethod) -> some View {
        let isActive = viewModel.splitMethod == method
        return Button(action: {
            viewModel.splitMethod = method
            viewModel.initializeDefaultRawInputs(for: method)
        }) {
            Image(systemName: systemImageForSplitMethod(method))
                .font(.system(size: IconSize.sm, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.sm)
                .background(isActive ? AppColors.cardBackground : Color.clear)
                .cornerRadius(CornerRadius.small)
                .shadow(color: isActive ? AppColors.shadow : Color.clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Row Components

    private func amountRow(name: String, amount: Double) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(FinancialFormatter.currency(amount, currencyCode: viewModel.transactionCurrency))
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, Spacing.md)
    }

    private func editableAmountRow(name: String, amount: Binding<String>) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(currencySymbol)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)

            TextField("0.00", text: amount)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
        .padding(.vertical, Spacing.md)
    }

    private func editablePercentageRow(name: String, percentage: Binding<String>) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            TextField("0", text: percentage)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 40)

            Text("%")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)

            Text(FinancialFormatter.currency(viewModel.totalAmountDouble * (Double(percentage.wrappedValue) ?? 0) / 100, currencyCode: viewModel.transactionCurrency))
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.vertical, Spacing.md)
    }

    private func editableSharesRow(name: String, shares: Binding<String>) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            TextField("1", text: shares)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 40)

            Text("shares")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, Spacing.md)
    }

    private func editableAdjustmentRow(name: String, adjustment: Binding<String>, calculatedAmount: Double) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text("+")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textSecondary)

            TextField("0.00", text: adjustment)
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)

            Text("=")
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textTertiary)

            Text(FinancialFormatter.currency(calculatedAmount, currencyCode: viewModel.transactionCurrency))
                .font(AppTypography.headingSmall())
                .foregroundColor(AppColors.textPrimary)
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Helpers

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    private var formattedDate: String {
        let dayString = Self.monthDayFormatter.string(from: viewModel.date)

        let calendar = Calendar.current
        let day = calendar.component(.day, from: viewModel.date)
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }

        let year = Self.yearFormatter.string(from: viewModel.date)

        return "\(dayString)\(suffix), \(year)"
    }

    private var currencySymbol: String {
        Currency.fromCode(viewModel.transactionCurrency).symbol
    }

    private func systemImageForSplitMethod(_ method: SplitMethod) -> String {
        switch method {
        case .equal: return "equal"
        case .amount: return "dollarsign"
        case .percentage: return "percent"
        case .shares: return "divide"
        case .adjustment: return "line.3.horizontal"
        }
    }

    // MARK: - Save Transaction

    private func saveTransaction() {
        viewModel.saveTransaction { success in
            if success {
                dismiss()
            } else {
                let validation = viewModel.validate()
                validationMessage = validation.message ?? "Unable to save transaction"
                showingValidationAlert = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AddTransactionView(context: PersistenceController.preview.container.viewContext)
    }
}
