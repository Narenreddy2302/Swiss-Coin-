import CoreData
import SwiftUI

// MARK: - Add Transaction View
// Premium single-page scrollable form with card-based sections

struct AddTransactionView: View {
    @StateObject private var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: FocusField?

    @AppStorage("default_currency") private var selectedCurrency: String = "USD"
    @State private var activeCurrency: Currency = Currency.fromGlobalSetting()
    @State private var showCurrencyPicker = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    @State private var showCurrencyPicker = false
    @State private var showCategoryPicker = false
    @State private var showNoteField = false
    @State private var undoParticipant: Person?
    @State private var showUndoToast = false

    var initialParticipant: Person?
    var initialGroup: UserGroup?

    private enum FocusField: Hashable {
        case title
        case amount
        case paidBySearch
        case splitWithSearch
        case note
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
            ZStack(alignment: .bottom) {
                // Scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.sectionGap) {
                        transactionHeaderSection
                        amountAndDateSection
                        paidBySection
                        splitWithSection
                        splitMethodSection
                        if viewModel.selectedPayerPersons.count > 1 {
                            paidByBreakdownSection
                        }
                        breakdownSection
                        noteSection
                    }
                    breakdownSection
                    noteSection
                    validationSection
                    saveButton
                }
                .scrollDismissesKeyboard(.interactively)

                // Sticky bottom bar
                stickyBottomBar
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
                        Image(systemName: "xmark")
                            .font(.system(size: IconSize.sm, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .accessibilityLabel("Cancel")
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
            .onAppear {
                setupInitialParticipants()
                HapticManager.sheetPresent()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = .title
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                currencyPickerSheet
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(
                    selectedCategory: $viewModel.selectedCategory,
                    isPresented: $showCategoryPicker
                )
                .presentationDetents([.medium, .large])
            }
            .undoToast(
                isShowing: $showUndoToast,
                message: "Participant removed",
                onUndo: {
                    if let person = undoParticipant {
                        withAnimation(AppAnimation.spring) {
                            viewModel.selectedParticipants.insert(person)
                        }
                        undoParticipant = nil
                    }
                }
            )
            .presentationDetents([.large])
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerSheet(selectedCurrency: $activeCurrency, isPresented: $showCurrencyPicker)
            }
            .onChange(of: activeCurrency) { newCurrency in
                selectedCurrency = newCurrency.code
            }
            .alert("Save Failed", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
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

    // MARK: - Helpers

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

    private func personColor(for person: Person) -> Color {
        Color(hex: person.colorHex ?? AppColors.defaultAvatarColorHex)
    }

    // MARK: - Section 1: Transaction Header (Name + Category)

    private var transactionHeaderSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.lg) {
                // Category icon circle
                Button {
                    HapticManager.tap()
                    showCategoryPicker = true
                } label: {
                    ZStack {
                        Circle()
                            .fill((viewModel.selectedCategory?.color ?? .gray).opacity(0.15))
                            .frame(width: AvatarSize.lg, height: AvatarSize.lg)

                        Text(viewModel.selectedCategory?.icon ?? "📦")
                            .font(.system(size: IconSize.lg))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select category")

                // Title field
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    TextField("Transaction Name", text: $viewModel.title)
                        .font(viewModel.title.isEmpty ? AppTypography.bodyLarge() : AppTypography.headingLarge())
                        .foregroundColor(AppColors.textPrimary)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }
                        .limitTextLength(to: ValidationLimits.maxTransactionTitleLength, text: $viewModel.title)
                        .accessibilityLabel("Transaction name")
                }
            }

            Divider()
                .padding(.top, Spacing.md)

            // Category selector row
            Button {
                HapticManager.tap()
                showCategoryPicker = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text(viewModel.selectedCategory?.icon ?? "📦")
                        .font(.system(size: IconSize.sm))

                    Text(viewModel.selectedCategory?.name ?? "Other")
                        .font(AppTypography.labelDefault())
                        .foregroundColor(AppColors.textSecondary)

            Button {
                HapticManager.tap()
                showCurrencyPicker = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(activeCurrency.flag)
                        .font(AppTypography.bodyDefault())
                    Text(activeCurrency.symbol)
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(AppColors.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: IconSize.xs, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select currency")

            TextField("0.00", text: $viewModel.totalAmount)
                .font(AppTypography.financialLarge())
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .amount)
                .limitTextLength(to: 12, text: $viewModel.totalAmount)
                .frame(minWidth: 80)
                .onChange(of: viewModel.totalAmount) { newValue in
                    var filtered = newValue.filter { "0123456789.".contains($0) }
                    if let firstDot = filtered.firstIndex(of: ".") {
                        let afterDot = filtered[filtered.index(after: firstDot)...]
                        let digitsAfterDot = afterDot.filter { $0 != "." }
                        filtered = String(filtered[...firstDot]) + String(digitsAfterDot.prefix(2))
                    }
                    if filtered != newValue {
                        viewModel.totalAmount = filtered
                    }
                }
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(
                    color: AppShadow.card(for: colorScheme).color,
                    radius: AppShadow.card(for: colorScheme).radius,
                    x: AppShadow.card(for: colorScheme).x,
                    y: AppShadow.card(for: colorScheme).y
                )
        )
    }

    // MARK: - Section 2: Amount + Date + Currency

    private var amountAndDateSection: some View {
        VStack(spacing: Spacing.md) {
            // Date picker row
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: IconSize.sm))
                    .foregroundColor(AppColors.textSecondary)

                DatePicker(
                    "",
                    selection: $viewModel.date,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(AppColors.textPrimary)
                .fixedSize()
                .accessibilityLabel("Transaction date")

                Spacer()
            }

            Divider()

            // Hero amount zone
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    // Currency selector button
                    Button {
                        HapticManager.tap()
                        showCurrencyPicker = true
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(CurrencyFormatter.currencyFlag)
                                .font(.system(size: IconSize.md))

                            Text(CurrencyFormatter.currencySymbol)
                                .font(AppTypography.financialLarge())
                                .foregroundColor(AppColors.textSecondary)

                            Image(systemName: "chevron.down")
                                .font(.system(size: IconSize.xs, weight: .semibold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Currency: \(CurrencyFormatter.currencyCode). Tap to change.")

                    // Amount field
                    TextField(
                        CurrencyFormatter.isZeroDecimalCurrency ? "0" : "0.00",
                        text: $viewModel.totalAmount
                    )
                    .font(AppTypography.financialHero())
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(AppColors.textPrimary)
                    .focused($focusedField, equals: .amount)
                    .onChange(of: viewModel.totalAmount) { _, newValue in
                        let sanitized = viewModel.sanitizeAmountInput(newValue)
                        if sanitized != newValue {
                            viewModel.totalAmount = sanitized
                        }
                    }
                    .accessibilityLabel("Transaction amount")
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .padding(Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(
                    color: AppShadow.card(for: colorScheme).color,
                    radius: AppShadow.card(for: colorScheme).radius,
                    x: AppShadow.card(for: colorScheme).x,
                    y: AppShadow.card(for: colorScheme).y
                )
        )
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
                        HapticManager.selectionChanged()
                        selectedCurrency = currency.code
                        showCurrencyPicker = false
                    } label: {
                        HStack(spacing: Spacing.md) {
                            Text(currency.flag)
                                .font(.system(size: IconSize.lg))

                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(currency.name)
                                    .font(AppTypography.bodyLarge())
                                    .foregroundColor(AppColors.textPrimary)
                                Text(currency.code)
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            Text(currency.symbol)
                                .font(AppTypography.bodyLarge())
                                .foregroundColor(AppColors.textSecondary)

                            if selectedCurrency == currency.id {
                                Image(systemName: "checkmark")
                                    .font(AppTypography.headingMedium())
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.tap()
                        showCurrencyPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Section 3: Paid By

    private var paidBySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("PAID BY")

            VStack(spacing: 0) {
                // Default single payer row or search
                if viewModel.paidBySearchText.isEmpty && viewModel.selectedPayerPersons.isEmpty {
                    // Show "You" as default payer
                    Button {
                        focusedField = .paidBySearch
                    } label: {
                        HStack(spacing: Spacing.md) {
                            avatarCircle(
                                initials: CurrentUser.initials,
                                color: Color(hex: CurrentUser.defaultColorHex),
                                size: AvatarSize.sm
                            )

                            Text("You")
                                .font(AppTypography.bodyLarge())
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            if viewModel.totalAmountDouble > 0 {
                                Text(CurrencyFormatter.formatAbsolute(viewModel.totalAmountDouble))
                                    .font(AppTypography.financialDefault())
                                    .foregroundColor(AppColors.positive)
                            }

                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: IconSize.md))
                                .foregroundColor(AppColors.positive)
                        }
                        .padding(Spacing.cardPadding)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Paid by You. Tap to change.")
                } else if !viewModel.selectedPayerPersons.isEmpty && viewModel.paidBySearchText.isEmpty {
                    // Show selected payers as avatar chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(sortedByCurrentUser(viewModel.selectedPayerPersons), id: \.self) { person in
                                avatarChip(person) { viewModel.togglePayer(person) }
                            }

                            // Add more button
                            Button {
                                focusedField = .paidBySearch
                            } label: {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "plus")
                                        .font(.system(size: IconSize.xs, weight: .semibold))
                                    Text("Add")
                                        .font(AppTypography.labelSmall())
                                }
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(AppColors.accentMuted)
                                .cornerRadius(CornerRadius.full)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add payer")
                        }
                        .padding(.horizontal, Spacing.cardPadding)
                        .padding(.vertical, Spacing.md)
                    }
                }

                Divider().padding(.leading, Spacing.cardPadding)

                // Search field
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(AppColors.textTertiary)

                    TextField("Search contacts...", text: $viewModel.paidBySearchText)
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textPrimary)
                        .focused($focusedField, equals: .paidBySearch)
                        .accessibilityLabel("Search payers")

                    if !viewModel.paidBySearchText.isEmpty {
                        Button {
                            viewModel.paidBySearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: IconSize.sm))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, Spacing.cardPadding)
                .padding(.vertical, Spacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .shadow(
                        color: AppShadow.card(for: colorScheme).color,
                        radius: AppShadow.card(for: colorScheme).radius,
                        x: AppShadow.card(for: colorScheme).x,
                        y: AppShadow.card(for: colorScheme).y
                    )
            )

            // Floating search results
            if !viewModel.paidBySearchText.isEmpty {
                paidBySearchResults
            }
        }
    }

    private var paidBySearchResults: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(AppAnimation.quick) {
                    viewModel.toggleCurrentUserAsPayer(in: viewContext)
                    viewModel.paidBySearchText = ""
                }
                HapticManager.selectionChanged()
            } label: {
                searchResultRow(
                    name: "You",
                    initials: CurrentUser.initials,
                    color: Color(hex: CurrentUser.defaultColorHex),
                    isSelected: viewModel.isCurrentUserPayer && !viewModel.selectedPayerPersons.isEmpty
                )
            }
            .buttonStyle(.plain)

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

    // MARK: - Section 4: Split With

    private var splitWithSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("SPLIT WITH")

            VStack(spacing: 0) {
                // Selected participants chips
                if !viewModel.selectedParticipants.isEmpty && viewModel.splitWithSearchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(sortedByCurrentUser(viewModel.selectedParticipants), id: \.self) { person in
                                let isCurrentUser = CurrentUser.isCurrentUser(person.id)
                                if isCurrentUser {
                                    // Current user chip — non-removable
                                    HStack(spacing: Spacing.xs) {
                                        avatarCircle(
                                            initials: CurrentUser.initials,
                                            color: Color(hex: CurrentUser.defaultColorHex),
                                            size: 22
                                        )
                                        Text("You")
                                            .font(AppTypography.labelSmall())
                                            .foregroundColor(AppColors.textPrimary)
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 8))
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(AppColors.backgroundTertiary)
                                    .cornerRadius(CornerRadius.full)
                                    .accessibilityLabel("You, locked participant")
                                } else {
                                    avatarChip(person) {
                                        withAnimation(AppAnimation.spring) {
                                            undoParticipant = person
                                            _ = viewModel.selectedParticipants.remove(person)
                                            showUndoToast = true
                                        }
                                    }
                                }
                            }

                            // Add more button
                            Button {
                                focusedField = .splitWithSearch
                            } label: {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "plus")
                                        .font(.system(size: IconSize.xs, weight: .semibold))
                                    Text("Add")
                                        .font(AppTypography.labelSmall())
                                }
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(AppColors.accentMuted)
                                .cornerRadius(CornerRadius.full)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add participant")
                        }
                        .padding(.horizontal, Spacing.cardPadding)
                        .padding(.vertical, Spacing.md)
                    }

                    // Person count
                    HStack {
                        Text("\(viewModel.selectedParticipants.count) people")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.cardPadding)
                    .padding(.bottom, Spacing.xs)
                }

                Divider().padding(.leading, Spacing.cardPadding)

                // Search field
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(AppColors.textTertiary)

                    TextField("Search contacts...", text: $viewModel.splitWithSearchText)
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textPrimary)
                        .focused($focusedField, equals: .splitWithSearch)
                        .accessibilityLabel("Search participants")

                    if !viewModel.splitWithSearchText.isEmpty {
                        Button {
                            viewModel.splitWithSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: IconSize.sm))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, Spacing.cardPadding)
                .padding(.vertical, Spacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .shadow(
                        color: AppShadow.card(for: colorScheme).color,
                        radius: AppShadow.card(for: colorScheme).radius,
                        x: AppShadow.card(for: colorScheme).x,
                        y: AppShadow.card(for: colorScheme).y
                    )
            )

            // Floating search results
            if !viewModel.splitWithSearchText.isEmpty {
                splitWithSearchResults
            }

            // Empty participants state
            if viewModel.selectedParticipants.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: IconSize.xl))
                            .foregroundColor(AppColors.textTertiary)
                        Text("Select at least one person to split with")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, Spacing.lg)
            }
        }
    }

    private var splitWithSearchResults: some View {
        VStack(spacing: 0) {
            // Groups
            ForEach(viewModel.filteredSplitWithGroups, id: \.objectID) { group in
                Button {
                    withAnimation(AppAnimation.quick) {
                        viewModel.selectGroup(group)
                        viewModel.splitWithSearchText = ""
                    }
                    HapticManager.selectionChanged()
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: IconSize.sm))
                            .foregroundColor(AppColors.accent)
                            .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                            .background(AppColors.accentMuted)
                            .clipShape(Circle())

                        Text(group.name ?? "Unnamed Group")
                            .font(AppTypography.bodyLarge())
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Text("Add All")
                            .font(AppTypography.labelSmall())
                            .foregroundColor(AppColors.accent)
                    }
                    .padding(.horizontal, Spacing.cardPadding)
                    .padding(.vertical, Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, Spacing.cardPadding + AvatarSize.sm + Spacing.md)
            }

            // Contacts
            let validContacts = viewModel.filteredSplitWithContacts.filter { $0.id != nil }
            ForEach(Array(validContacts.enumerated()), id: \.element.objectID) { index, person in
                Button {
                    withAnimation(AppAnimation.quick) {
                        viewModel.toggleParticipant(person)
                        viewModel.splitWithSearchText = ""
                    }
                    HapticManager.selectionChanged()
                } label: {
                    searchResultRow(
                        name: person.displayName,
                        initials: person.initials,
                        color: personColor(for: person),
                        isSelected: viewModel.selectedParticipants.contains(person)
                    )
                }
                .buttonStyle(.plain)

                if index < validContacts.count - 1 {
                    Divider().padding(.leading, Spacing.cardPadding + AvatarSize.sm + Spacing.md)
                }
            }

            if validContacts.isEmpty && viewModel.filteredSplitWithGroups.isEmpty {
                HStack {
                    Spacer()
                    Text("No results found")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .padding(.vertical, Spacing.lg)
            }
        }
        .frame(maxHeight: 220)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.elevatedSurface)
                .shadow(
                    color: AppShadow.elevated(for: colorScheme).color,
                    radius: AppShadow.elevated(for: colorScheme).radius,
                    x: AppShadow.elevated(for: colorScheme).x,
                    y: AppShadow.elevated(for: colorScheme).y
                )
        )
    }

    // MARK: - Section 5: Split Method

    private var splitMethodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("SPLIT METHOD")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(SplitMethod.allCases) { method in
                        methodCard(method)
                    }
                }
            }
        }
    }

    private func methodCard(_ method: SplitMethod) -> some View {
        let isSelected = viewModel.splitMethod == method

        return Button {
            guard viewModel.splitMethod != method else { return }
            withAnimation(AppAnimation.standard) {
                viewModel.splitMethod = method
                viewModel.initializeDefaultRawInputs(for: method)
            }
            HapticManager.selectionChanged()
        } label: {
            VStack(spacing: Spacing.sm) {
                Image(systemName: method.systemImage)
                    .font(.system(size: IconSize.lg, weight: .medium))
                    .foregroundColor(isSelected ? AppColors.onAccent : AppColors.textPrimary)

                Text(method.displayName)
                    .font(AppTypography.labelSmall())
                    .foregroundColor(isSelected ? AppColors.onAccent : AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(isSelected ? AppColors.accent : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(AppAnimation.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(method.displayName) split method\(isSelected ? ", selected" : "")")
    }

    // MARK: - Paid By Breakdown Section

    private var paidByBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("PAID BY AMOUNTS")

            let sortedPayers: [Person] = {
                if viewModel.selectedPayerPersons.isEmpty {
                    return [CurrentUser.getOrCreate(in: viewContext)]
                }

                // Warning if unbalanced
                if !viewModel.isPaidByBalanced {
                    Divider()
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: IconSize.sm))
                            .foregroundColor(AppColors.warning)
                        Text("Amounts must equal \(CurrencyFormatter.formatAbsolute(viewModel.totalAmountDouble))")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.warning)
                        Spacer()
                    }
                    .padding(Spacing.cardPadding)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .shadow(
                        color: AppShadow.card(for: colorScheme).color,
                        radius: AppShadow.card(for: colorScheme).radius,
                        x: AppShadow.card(for: colorScheme).x,
                        y: AppShadow.card(for: colorScheme).y
                    )
            )
        }
    }

    private func payerAmountRow(person: Person) -> some View {
        let name = fullName(for: person)
        let isSinglePayer = viewModel.selectedPayerPersons.count <= 1
        let personId = person.id ?? UUID()

        return HStack(spacing: Spacing.md) {
            avatarCircle(
                initials: CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials,
                color: personColor(for: person),
                size: AvatarSize.sm
            )

            Text(name)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: Spacing.xs) {
                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textSecondary)

                if isSinglePayer {
                    Text(String(format: "%.2f", viewModel.totalAmountDouble))
                        .font(AppTypography.financialDefault())
                        .foregroundColor(AppColors.textPrimary)
                } else {
                    TextField("0.00", text: Binding(
                        get: { viewModel.payerAmounts[personId] ?? "" },
                        set: { viewModel.payerAmounts[personId] = $0 }
                    ))
                    .font(AppTypography.financialDefault())
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(minWidth: 60, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.md)
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("BREAKDOWN")

            if viewModel.selectedParticipants.isEmpty {
                emptyBreakdownState
            } else if viewModel.isTwoPartySplit && viewModel.splitMethod == .equal {
                TwoPartySplitView(viewModel: viewModel)
            } else {
                participantBreakdownCard
            }
        }
    }

    private var emptyBreakdownState: some View {
        HStack {
            Spacer()
            VStack(spacing: Spacing.sm) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: IconSize.xl))
                    .foregroundColor(AppColors.textTertiary)
                Text("Select participants to see breakdown")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(
                    color: AppShadow.card(for: colorScheme).color,
                    radius: AppShadow.card(for: colorScheme).radius,
                    x: AppShadow.card(for: colorScheme).x,
                    y: AppShadow.card(for: colorScheme).y
                )
        )
    }

    private var participantBreakdownCard: some View {
        VStack(spacing: 0) {
            let sortedParticipants = sortedByCurrentUser(viewModel.selectedParticipants)

            ForEach(Array(sortedParticipants.enumerated()), id: \.element) { index, person in
                breakdownRow(person: person)
                    .id("\(person.id?.uuidString ?? "unknown")-\(viewModel.splitMethod.rawValue)")

                if index < sortedParticipants.count - 1 {
                    Divider().padding(.leading, Spacing.cardPadding + AvatarSize.sm + Spacing.md)
                }
            }

            Divider()
                .padding(.vertical, Spacing.xs)

            // Total row
            HStack {
                Text("Total")
                    .font(AppTypography.headingSmall())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    let balance = viewModel.totalBalance
                    let isBalanced = abs(balance) < TransactionViewModel.epsilon

                    HStack(spacing: Spacing.xs) {
                        Text(CurrencyFormatter.currencySymbol)
                            .font(AppTypography.bodyDefault())
                            .foregroundColor(AppColors.textSecondary)

                        Text(CurrencyFormatter.formatDecimal(abs(viewModel.totalAmountDouble - balance)))
                            .font(AppTypography.financialDefault())
                            .foregroundColor(isBalanced ? AppColors.positive : AppColors.negative)
                    }

                    if let remainingText = viewModel.balanceRemainingText {
                        Text(remainingText)
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.negative)
                    }
                }
            }
            .padding(.horizontal, Spacing.cardPadding)
            .padding(.vertical, Spacing.md)
            .animation(AppAnimation.standard, value: viewModel.totalBalance)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(AppColors.cardBackground)
                .shadow(
                    color: AppShadow.card(for: colorScheme).color,
                    radius: AppShadow.card(for: colorScheme).radius,
                    x: AppShadow.card(for: colorScheme).x,
                    y: AppShadow.card(for: colorScheme).y
                )
        )
    }

    private func breakdownRow(person: Person) -> some View {
        let name = fullName(for: person)
        let splitAmount = viewModel.calculateSplit(for: person)

        return HStack(spacing: Spacing.md) {
            avatarCircle(
                initials: CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials,
                color: personColor(for: person),
                size: AvatarSize.sm
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(name)
                    .font(AppTypography.bodyDefault())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                // Show calculated amount below for percentage/shares
                if viewModel.splitMethod == .percentage || viewModel.splitMethod == .shares {
                    Text(CurrencyFormatter.formatAbsolute(splitAmount))
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            if viewModel.splitMethod == .percentage
                || viewModel.splitMethod == .shares
                || viewModel.splitMethod == .adjustment {
                SplitInputView(viewModel: viewModel, person: person)
            }

            if viewModel.splitMethod == .amount {
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.currencySymbol)
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)

                    TextField("0.00", text: rawInputBinding(for: person))
                        .font(AppTypography.financialDefault())
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 60, alignment: .trailing)
                }
                .onAppear { initializeAmountDefault(for: person) }
            } else if viewModel.splitMethod == .equal {
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.currencySymbol)
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textSecondary)

                    Text(String(format: "%.2f", splitAmount))
                        .font(AppTypography.financialDefault())
                        .foregroundColor(AppColors.positive)
                }
            }
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Section 7: Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("NOTE")

            VStack(spacing: 0) {
                if showNoteField {
                    TextEditor(text: $viewModel.note)
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minHeight: 80, maxHeight: 150)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .focused($focusedField, equals: .note)
                        .scrollContentBackground(.hidden)
                        .limitTextLength(to: ValidationLimits.maxNoteLength, text: $viewModel.note)
                        .accessibilityLabel("Transaction note")

                    HStack {
                        Spacer()
                        Text("\(viewModel.note.count)/\(ValidationLimits.maxNoteLength)")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.horizontal, Spacing.cardPadding)
                    .padding(.bottom, Spacing.sm)
                } else {
                    Button {
                        withAnimation(AppAnimation.standard) {
                            showNoteField = true
                        }
                        HapticManager.lightTap()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedField = .note
                        }
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: IconSize.sm))
                                .foregroundColor(AppColors.textTertiary)

                            Text("Add a note (optional)")
                                .font(AppTypography.bodyDefault())
                                .foregroundColor(AppColors.textTertiary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: IconSize.xs, weight: .semibold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(Spacing.cardPadding)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a note")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
                    .shadow(
                        color: AppShadow.card(for: colorScheme).color,
                        radius: AppShadow.card(for: colorScheme).radius,
                        x: AppShadow.card(for: colorScheme).x,
                        y: AppShadow.card(for: colorScheme).y
                    )
            )
        }
    }

    // MARK: - Sticky Bottom Bar (Validation + Save)

    private var stickyBottomBar: some View {
        VStack(spacing: Spacing.sm) {
            // Validation message
            if let validationMessage = viewModel.validationMessage {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(AppColors.warning)

                    Text(validationMessage)
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)

                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(AppColors.warning.opacity(0.08))
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(AppAnimation.standard, value: viewModel.validationMessage)
            }

            // Save button
            Button {
                HapticManager.save()
                viewModel.saveTransaction { success in
                    if success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(AppColors.onAccent)
                    } else if viewModel.saveCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: IconSize.md, weight: .semibold))
                            .foregroundColor(AppColors.onAccent)
                    } else {
                        Text("Save Transaction")
                            .font(AppTypography.buttonLarge())
                            .foregroundColor(AppColors.onAccent)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.button)
                        .fill(viewModel.isValid ? AppColors.accent : AppColors.disabled)
                )
            }
            .disabled(!viewModel.isValid || viewModel.isSaving)
            .opacity(viewModel.isValid ? 1.0 : 0.6)
            .animation(AppAnimation.standard, value: viewModel.isValid)
            .animation(AppAnimation.standard, value: viewModel.isSaving)
            .accessibilityLabel("Save transaction")
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Spacing.md)
        .padding(.bottom, Spacing.xs)
        .background(
            Rectangle()
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadow, radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Shared Components

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.labelSmall())
            .foregroundColor(AppColors.textTertiary)
            .textCase(.uppercase)
            .tracking(AppTypography.Tracking.labelSmall)
            .padding(.horizontal, Spacing.xs)
    }

    private func avatarCircle(initials: String, color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(color)
            )
            .overlay(
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
    }

    private func avatarChip(_ person: Person, onRemove: @escaping () -> Void) -> some View {
        Button {
            withAnimation(AppAnimation.spring) { onRemove() }
            HapticManager.tap()
        } label: {
            HStack(spacing: Spacing.xs) {
                avatarCircle(
                    initials: CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials,
                    color: personColor(for: person),
                    size: 22
                )

                Text(shortName(for: person))
                    .font(AppTypography.labelSmall())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.leading, Spacing.xs)
            .padding(.trailing, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(AppColors.accentMuted)
            .cornerRadius(CornerRadius.full)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(shortName(for: person))")
    }

    private func searchResultRow(name: String, initials: String, color: Color, isSelected: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            avatarCircle(initials: initials, color: color, size: AvatarSize.sm)

            Text(name)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: IconSize.md))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
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

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            HapticManager.tap()
            viewModel.saveTransaction { success in
                if success {
                    dismiss()
                } else {
                    saveErrorMessage = viewModel.validationMessage ?? "Failed to save transaction. Please try again."
                    showSaveError = true
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
