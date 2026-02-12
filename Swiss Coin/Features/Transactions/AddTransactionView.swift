import CoreData
import SwiftUI

// MARK: - Add Transaction View
// 3-step wizard: Details → Split → Review

struct AddTransactionView: View {
    @StateObject private var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FocusState private var focusedField: FocusField?

    @AppStorage("default_currency") private var selectedCurrency: String = "USD"
    @State private var currentStep: Int = 1
    @State private var selectedDetent: PresentationDetent = .fraction(0.42)
    @State private var keyboardVisible: Bool = false

    var initialParticipant: Person?
    var initialGroup: UserGroup?

    private enum FocusField: Hashable {
        case title
        case amount
        case note
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Step Content
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        switch currentStep {
                        case 1:
                            step1Content
                        case 2:
                            step2Content
                        case 3:
                            step3Content
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)

                // MARK: - Bottom Navigation Bar
                bottomNavigationBar
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle(currentStep == 1 ? "New Transaction" : currentStep == 2 ? "Split Options" : "Split Details")
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
            .presentationDetents(availableDetents, selection: $selectedDetent)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(AppAnimation.standard) {
                    keyboardVisible = true
                    selectedDetent = detentForCurrentState()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(AppAnimation.standard) {
                    keyboardVisible = false
                    selectedDetent = detentForCurrentState()
                }
            }
            .onChange(of: currentStep) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(AppAnimation.standard) {
                        selectedDetent = detentForCurrentState()
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Details

    private var step1Content: some View {
        VStack(spacing: Spacing.xl) {
            transactionNameSection
            dateAndAmountSection
            noteSection
        }
    }

    // MARK: - Step 2: Split

    private var step2Content: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            paidBySection
            splitWithSection
        }
    }

    // MARK: - Step 3: Review

    private var step3Content: some View {
        multiPartySplitContent
    }

    private var multiPartySplitContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            splitMethodSection
            if viewModel.selectedPayerPersons.count > 1 {
                paidByBreakdownSection
            }
            breakdownSection
            validationSection
        }
    }

    // MARK: - Paid By Breakdown Section (Step 3)

    private var paidByBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Paid By:")
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(AppColors.textPrimary)

            let sortedPayers: [Person] = {
                if viewModel.selectedPayerPersons.isEmpty {
                    // Default: "You" — show current user
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
                    // Single payer: auto-fill, read-only
                    Text(String(format: "%.2f", viewModel.totalAmountDouble))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 50, alignment: .trailing)
                } else {
                    // Multi-payer: editable
                    TextField("0.00", text: payerAmountBinding(for: person))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
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

    // MARK: - Bottom Navigation Bar

    private var bottomNavigationBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: Spacing.md) {
                // Back button (Steps 2 & 3)
                if currentStep > 1 {
                    Button {
                        goToPreviousStep()
                    } label: {
                        Text("Back")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                // Next / Save button
                if currentStep < 3 {
                    Button {
                        goToNextStep()
                    } label: {
                        Text("Next")
                    }
                    .disabled(!isCurrentStepValid)
                    .buttonStyle(PrimaryButtonStyle(isEnabled: isCurrentStepValid))
                } else {
                    Button {
                        HapticManager.tap()
                        viewModel.saveTransaction { success in
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Save Transaction")
                    }
                    .disabled(!viewModel.isValid)
                    .buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.isValid))
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.backgroundSecondary)
        }
    }

    // MARK: - Navigation Helpers

    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 1: return viewModel.isStep1Valid
        case 2: return viewModel.isStep2Valid
        default: return true
        }
    }

    private func goToNextStep() {
        focusedField = nil
        withAnimation(AppAnimation.standard) {
            currentStep = min(currentStep + 1, 3)
        }
        HapticManager.selectionChanged()
    }

    private func goToPreviousStep() {
        focusedField = nil
        withAnimation(AppAnimation.standard) {
            currentStep = max(currentStep - 1, 1)
        }
        HapticManager.selectionChanged()
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

    // MARK: - Dynamic Sheet Height

    private var availableDetents: Set<PresentationDetent> {
        [.fraction(0.42), .fraction(0.50), .fraction(0.58), .fraction(0.65), .fraction(0.72), .large]
    }

    private func detentForCurrentState() -> PresentationDetent {
        if keyboardVisible {
            switch currentStep {
            case 1: return .large
            default: return .large
            }
        }
        switch currentStep {
        case 1: return .fraction(0.50)
        case 2: return .fraction(0.58)
        case 3:
            if viewModel.selectedPayerPersons.count > 1 {
                return .large
            } else {
                return .fraction(0.72)
            }
        default: return .fraction(0.50)
        }
    }

    // MARK: - Transaction Name Section

    private var transactionNameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
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
        }
    }

    // MARK: - Date & Amount Section

    private var dateAndAmountSection: some View {
        HStack(spacing: Spacing.md) {
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

            Menu {
                ForEach(Currency.all) { currency in
                    Button {
                        selectedCurrency = currency.code
                        HapticManager.selectionChanged()
                    } label: {
                        HStack {
                            Text("\(currency.flag) \(currency.symbol)")
                            if currency.code == selectedCurrency {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Text(Currency.fromCode(selectedCurrency).symbol)
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textSecondary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.xs)
            }

            TextField("0.00", text: $viewModel.totalAmount)
                .font(.system(size: 22, weight: .bold, design: .rounded))
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
    }

    // MARK: - Note Section

    private var noteSection: some View {
        TextField("Add a note...", text: $viewModel.note, axis: .vertical)
            .font(AppTypography.body())
            .foregroundColor(AppColors.textPrimary)
            .focused($focusedField, equals: .note)
            .lineLimit(3...5)
            .limitTextLength(to: ValidationLimits.maxNoteLength, text: $viewModel.note)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.cardBackgroundElevated)
            .cornerRadius(CornerRadius.sm)
    }

    // MARK: - Paid By Section (Multi-Select)

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
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.cardBackgroundElevated)
            .cornerRadius(CornerRadius.sm)

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
                    // Default: "You" chip (non-removable indicator)
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
                // "You" option
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
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.cardBackgroundElevated)
            .cornerRadius(CornerRadius.sm)

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
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.clear, lineWidth: 1)
                )
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
                                .font(.system(size: 16))
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
                    .font(.system(size: 17, weight: .semibold))
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
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? AppColors.buttonForeground : AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(isSelected ? AppColors.buttonBackground : AppColors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(isSelected ? Color.clear : AppColors.buttonBackground.opacity(0.2), lineWidth: 1)
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

    // MARK: - Total Amount Bar

    private var totalAmountBar: some View {
        HStack {
            Text("Total Amount")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(CurrencyFormatter.currencySymbol)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.xs)

            Text(String(format: "%.2f", viewModel.totalAmountDouble))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.cardBackgroundElevated)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.separator, lineWidth: 1)
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
                    .font(.system(size: 16, weight: .bold, design: .rounded))
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

            // Input control (only for percentage, shares, adjustment)
            if viewModel.splitMethod == .percentage
                || viewModel.splitMethod == .shares
                || viewModel.splitMethod == .adjustment {
                SplitInputView(viewModel: viewModel, person: person)
            }

            // Dollar amount (ALWAYS rightmost, aligns with Total Balance)
            if viewModel.splitMethod == .amount {
                // Editable TextField styled identically to the equal display
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.currencySymbol)
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    TextField("0.00", text: rawInputBinding(for: person))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 50, alignment: .trailing)
                }
                .onAppear { initializeAmountDefault(for: person) }
            } else {
                // Static dollar amount (equal, percentage, shares, adjustment)
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.currencySymbol)
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)

                    Text(String(format: "%.2f", splitAmount))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
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
}

// MARK: - Preview

#Preview {
    AddTransactionView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
