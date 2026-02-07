import CoreData
import SwiftUI

// MARK: - Add Transaction View
// 3-step wizard: Details → Split → Review

struct AddTransactionView: View {
    @StateObject private var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FocusState private var focusedField: FocusField?

    @State private var currentStep: Int = 1

    var initialParticipant: Person?
    var initialGroup: UserGroup?

    private enum FocusField: Hashable {
        case title
        case amount
        case paidBySearch
        case splitWithSearch
    }

    private let stepLabels = ["Details", "Split", "Review"]

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
                // MARK: - Step Indicator
                stepIndicator
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.lg)

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
            .navigationTitle("New Transaction")
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
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
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
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(1...3, id: \.self) { step in
                // Circle
                stepCircle(step: step)

                // Connecting line (not after last step)
                if step < 3 {
                    Rectangle()
                        .fill(step < currentStep ? AppColors.buttonBackground : AppColors.backgroundTertiary)
                        .frame(height: 2)
                }
            }
        }
        .overlay(
            // Step labels
            HStack(spacing: 0) {
                ForEach(1...3, id: \.self) { step in
                    Text(stepLabels[step - 1])
                        .font(AppTypography.caption())
                        .foregroundColor(step <= currentStep ? AppColors.textPrimary : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .offset(y: 28),
            alignment: .top
        )
        .padding(.bottom, Spacing.xl)
    }

    private func stepCircle(step: Int) -> some View {
        ZStack {
            Circle()
                .fill(step <= currentStep ? AppColors.buttonBackground : AppColors.backgroundTertiary)
                .frame(width: 32, height: 32)

            if step < currentStep {
                // Completed: checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.buttonForeground)
            } else {
                // Current or future: number
                Text("\(step)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(step == currentStep ? AppColors.buttonForeground : AppColors.textSecondary)
            }
        }
    }

    // MARK: - Step 1: Details

    private var step1Content: some View {
        VStack(spacing: Spacing.xl) {
            transactionNameSection
            dateAndAmountSection
        }
    }

    // MARK: - Step 2: Split

    private var step2Content: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Split Options")
                .font(AppTypography.title3())
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            paidBySection
            splitWithSection
            actionButtons
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.md)
    }

    // MARK: - Step 3: Review

    private var step3Content: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Split Details")
                .font(AppTypography.title3())
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            splitMethodSection
            totalAmountBar
            breakdownSection
            validationSection
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.md)
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
                            .font(AppTypography.bodyBold())
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: ButtonHeight.lg)
                            .background(
                                Capsule()
                                    .stroke(AppColors.separator, lineWidth: 1.5)
                            )
                    }
                }

                // Next / Save button
                if currentStep < 3 {
                    Button {
                        goToNextStep()
                    } label: {
                        Text("Next")
                            .font(AppTypography.bodyBold())
                            .foregroundColor(isCurrentStepValid ? AppColors.buttonForeground : AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: ButtonHeight.lg)
                            .background(
                                Capsule()
                                    .fill(isCurrentStepValid ? AppColors.buttonBackground : AppColors.disabled)
                            )
                    }
                    .disabled(!isCurrentStepValid)
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
                            .font(AppTypography.bodyBold())
                            .foregroundColor(viewModel.isValid ? AppColors.buttonForeground : AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: ButtonHeight.lg)
                            .background(
                                Capsule()
                                    .fill(viewModel.isValid ? AppColors.buttonBackground : AppColors.disabled)
                            )
                    }
                    .disabled(!viewModel.isValid)
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

    // MARK: - Transaction Name Section

    private var transactionNameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("New Transaction")
                .font(AppTypography.title2())
                .foregroundColor(AppColors.textPrimary)

            TextField("Transaction Name", text: $viewModel.title)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .amount }
                .limitTextLength(to: ValidationLimits.maxTransactionTitleLength, text: $viewModel.title)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
                .background(AppColors.cardBackground)
                .cornerRadius(CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(AppColors.separator, lineWidth: 1)
                )
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

            Text(CurrencyFormatter.currencySymbol)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.xs)

            TextField("0.00", text: $viewModel.totalAmount)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .amount)
                .limitTextLength(to: 12, text: $viewModel.totalAmount)
                .frame(minWidth: 100)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.separator, lineWidth: 1)
        )
    }

    // MARK: - Paid By Section

    private var paidBySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Paid By:")
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textPrimary)

            HStack {
                TextField("Search Contact...", text: $viewModel.paidBySearchText)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)
                    .focused($focusedField, equals: .paidBySearch)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(AppColors.separator, lineWidth: 1)
            )

            if viewModel.paidBySearchText.isEmpty {
                HStack {
                    payerChip
                    Spacer()
                }
                .padding(.top, Spacing.xs)
            } else {
                paidBySearchResults
            }
        }
    }

    private var payerChip: some View {
        let payerName = viewModel.selectedPayer?.firstName ?? "You"
        let payerColor = viewModel.selectedPayer?.avatarBackgroundColor ?? AppColors.accent.opacity(0.15)
        let payerTextColor = viewModel.selectedPayer?.avatarTextColor ?? AppColors.accent
        let initials = viewModel.selectedPayer?.initials ?? CurrentUser.initials

        return Button {
            HapticManager.tap()
        } label: {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(payerColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(payerTextColor)
                    )

                Text(payerName)
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.leading, Spacing.xs)
            .padding(.trailing, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(AppColors.backgroundSecondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var paidBySearchResults: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(AppAnimation.quick) {
                    viewModel.selectedPayer = nil
                    viewModel.paidBySearchText = ""
                }
                HapticManager.selectionChanged()
                focusedField = nil
            } label: {
                searchResultRow(name: "You", isSelected: viewModel.selectedPayer == nil)
            }
            .buttonStyle(.plain)

            ForEach(viewModel.filteredPaidByContacts, id: \.objectID) { person in
                Divider().padding(.leading, Spacing.lg)

                Button {
                    withAnimation(AppAnimation.quick) {
                        viewModel.selectedPayer = person
                        viewModel.paidBySearchText = ""
                    }
                    HapticManager.selectionChanged()
                    focusedField = nil
                } label: {
                    searchResultRow(
                        name: person.displayName,
                        isSelected: viewModel.selectedPayer?.id == person.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(AppColors.backgroundSecondary)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.separator, lineWidth: 1)
        )
        .padding(.top, Spacing.xs)
    }

    // MARK: - Split With Section

    private var splitWithSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Split with:")
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textPrimary)

            HStack {
                TextField("Search Contact...", text: $viewModel.splitWithSearchText)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)
                    .focused($focusedField, equals: .splitWithSearch)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(AppColors.separator, lineWidth: 1)
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
        let name = CurrentUser.isCurrentUser(person.id) ? "You" : (person.firstName ?? person.name ?? "?")
        let initials = CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials

        return Button {
            withAnimation(AppAnimation.quick) {
                viewModel.selectedParticipants.remove(person)
            }
            HapticManager.tap()
        } label: {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(person.avatarBackgroundColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(person.avatarTextColor)
                    )

                Text(name)
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textPrimary)

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.leading, Spacing.xs)
            .padding(.trailing, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(AppColors.backgroundSecondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var splitWithSearchResults: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.filteredSplitWithGroups, id: \.objectID) { group in
                Button {
                    withAnimation(AppAnimation.quick) {
                        viewModel.selectGroup(group)
                        viewModel.splitWithSearchText = ""
                    }
                    HapticManager.selectionChanged()
                    focusedField = nil
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
                    focusedField = nil
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
        .background(AppColors.backgroundSecondary)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(AppColors.separator, lineWidth: 1)
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
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: Spacing.md) {
            NavigationLink {
                ParticipantSelectorView(selectedParticipants: $viewModel.selectedParticipants)
            } label: {
                Text("More Options")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.md)
                    .background(AppColors.backgroundSecondary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
            }

            Button {
                withAnimation(AppAnimation.standard) {
                    viewModel.splitMethod = .equal
                    viewModel.rawInputs = [:]
                }
                HapticManager.success()
                focusedField = nil
                // Auto-advance to Step 3
                withAnimation(AppAnimation.standard) {
                    currentStep = 3
                }
            } label: {
                Text("Split Equal")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.md)
                    .background(AppColors.backgroundSecondary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
            }
        }
    }

    // MARK: - Split Method Section

    private var splitMethodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Split Method:")
                .font(AppTypography.headline())
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? AppColors.buttonForeground : AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(isSelected ? AppColors.buttonBackground : Color.clear)
                    )
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.clear : AppColors.separator, lineWidth: 1)
                    )

                Text(method.displayName)
                    .font(AppTypography.caption2())
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
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(CurrencyFormatter.currencySymbol)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(CornerRadius.xs)

            Text(String(format: "%.2f", viewModel.totalAmountDouble))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.backgroundSecondary)
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
                .font(AppTypography.headline())
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
        VStack(spacing: Spacing.md) {
            let sortedParticipants = Array(viewModel.selectedParticipants).sorted { p1, p2 in
                let isCurrentUser1 = CurrentUser.isCurrentUser(p1.id)
                let isCurrentUser2 = CurrentUser.isCurrentUser(p2.id)
                if isCurrentUser1 && !isCurrentUser2 { return true }
                if !isCurrentUser1 && isCurrentUser2 { return false }
                return (p1.name ?? "") < (p2.name ?? "")
            }

            ForEach(sortedParticipants, id: \.self) { person in
                breakdownRow(person: person)
            }

            HStack {
                Spacer()
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(width: 150, height: 1)
            }
            .padding(.top, Spacing.sm)

            HStack {
                Text("Total Balance")
                    .font(AppTypography.bodyBold())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textSecondary)

                let balance = viewModel.totalBalance
                Text(String(format: "%.2f", abs(balance)))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(abs(balance) < 0.01 ? AppColors.textPrimary : AppColors.negative)
                    .frame(minWidth: 60, alignment: .trailing)
            }

            HStack {
                Spacer()
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(width: 150, height: 1)
            }
        }
    }

    private func breakdownRow(person: Person) -> some View {
        let name = CurrentUser.isCurrentUser(person.id) ? "You" : (person.name ?? "Unknown")
        let splitAmount = viewModel.calculateSplit(for: person)

        return HStack {
            Text(name)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if viewModel.splitMethod == .equal {
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.currencySymbol)
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textSecondary)

                    Text(String(format: "%.2f", splitAmount))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 60, alignment: .trailing)
                }
            } else {
                SplitInputView(viewModel: viewModel, person: person)
                    .frame(maxWidth: 150)
            }
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
