import CoreData
import SwiftUI

// MARK: - Add Transaction View
// Redesigned hero-amount-first, card-sectioned layout with clear visual hierarchy

struct AddTransactionView: View {
    @StateObject private var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: FocusField?

    @State private var showCurrencyPicker = false
    @State private var showCategoryPicker = false
    @State private var showNoteField = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var undoParticipant: Person?
    @State private var showUndoToast = false
    @State private var showDatePicker = false
    @State private var heroAmountScale: CGFloat = 1.0

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

    // MARK: - Helpers

    private var smartDateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(viewModel.date) { return "Today" }
        if calendar.isDateInYesterday(viewModel.date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: viewModel.date)
    }

    private var currencyFlag: String {
        CurrencyFormatter.flag(for: viewModel.transactionCurrency)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.sectionGap) {
                        heroAmountSection
                        transactionNameSection
                        categoryAndDateRow
                        paidBySection
                        splitWithSection
                        splitMethodSection
                        if viewModel.selectedPayerPersons.count > 1 {
                            paidByBreakdownSection
                        }
                        breakdownSection
                        noteSection
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, Spacing.screenTopPad)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)

                stickyBottomBar
            }
            .background(
                ZStack {
                    AppColors.conversationBackground
                    DotGridPattern(
                        dotSpacing: 16,
                        dotRadius: 0.5,
                        color: AppColors.receiptDot.opacity(0.5)
                    )
                }
            )
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.conversationBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                    focusedField = .amount
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                TransactionCurrencyPicker(selectedCurrencyCode: $viewModel.transactionCurrency)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(
                    selectedCategory: $viewModel.selectedCategory,
                    isPresented: $showCategoryPicker
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    DatePicker("Select Date", selection: $viewModel.date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppColors.accent)
                        .padding()
                        .navigationTitle("Transaction Date")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showDatePicker = false
                                }
                                .font(AppTypography.headingMedium())
                                .foregroundColor(AppColors.accent)
                            }
                        }
                }
                .presentationDetents([.medium])
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
            .onChange(of: viewModel.transactionCurrency) { _, newCurrency in
                if CurrencyFormatter.isZeroDecimal(newCurrency) {
                    if let dotIndex = viewModel.totalAmount.firstIndex(of: ".") {
                        viewModel.totalAmount = String(viewModel.totalAmount[..<dotIndex])
                    }
                }
            }
            .presentationDetents([.large])
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

    // MARK: - Person Helpers

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

    // MARK: - Section 1: Hero Amount Display

    private var heroAmountSection: some View {
        VStack(alignment: .center, spacing: Spacing.sm) {
            // Large centered amount input
            TextField(
                CurrencyFormatter.isZeroDecimal(viewModel.transactionCurrency) ? "0" : "0.00",
                text: $viewModel.totalAmount
            )
            .font(AppTypography.financialHero())
            .tracking(AppTypography.Tracking.financialHero)
            .keyboardType(CurrencyFormatter.isZeroDecimal(viewModel.transactionCurrency) ? .numberPad : .decimalPad)
            .multilineTextAlignment(.center)
            .foregroundColor(viewModel.totalAmount.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)
            .focused($focusedField, equals: .amount)
            .limitTextLength(to: 12, text: $viewModel.totalAmount)
            .onChange(of: viewModel.totalAmount) { _, newValue in
                let sanitized = viewModel.sanitizeAmountInput(newValue)
                if sanitized != newValue {
                    viewModel.totalAmount = sanitized
                }
                // Scale animation on first digit
                if !newValue.isEmpty && heroAmountScale == 1.0 {
                    withAnimation(AppAnimation.spring) {
                        heroAmountScale = 1.05
                    }
                    withAnimation(AppAnimation.spring.delay(0.15)) {
                        heroAmountScale = 1.0
                    }
                }
            }
            .scaleEffect(heroAmountScale)
            .accessibilityLabel("Transaction amount")

            // Currency badge
            Button {
                HapticManager.tap()
                focusedField = nil
                showCurrencyPicker = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(currencyFlag)
                        .font(.system(size: IconSize.sm))

                    Text(viewModel.transactionCurrency)
                        .font(AppTypography.labelDefault())
                        .foregroundColor(AppColors.textPrimary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(AppColors.backgroundTertiary)
                )
                .overlay(
                    Capsule()
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(1.0)
            .accessibilityLabel("Currency: \(viewModel.transactionCurrency). Tap to change.")
        }
        .padding(.vertical, Spacing.xxl)
        .padding(.horizontal, Spacing.cardPadding)
        .frame(maxWidth: .infinity)
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

    // MARK: - Section 2: Transaction Name Input

    private var transactionNameSection: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: IconSize.sm))
                .foregroundColor(AppColors.textTertiary)

            TextField("Transaction Name", text: $viewModel.title)
                .font(viewModel.title.isEmpty ? AppTypography.bodyLarge() : AppTypography.headingMedium())
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .amount }
                .limitTextLength(to: ValidationLimits.maxTransactionTitleLength, text: $viewModel.title)
                .accessibilityLabel("Transaction name")
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
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .stroke(focusedField == .title ? AppColors.borderFocus : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Section 3: Category & Date Row

    private var categoryAndDateRow: some View {
        HStack(spacing: Spacing.md) {
            // Category pill
            Button {
                HapticManager.tap()
                showCategoryPicker = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(viewModel.selectedCategory?.icon ?? "📦")
                        .font(.system(size: IconSize.sm))

                    Text(viewModel.selectedCategory?.name ?? "Other")
                        .font(AppTypography.labelDefault())
                        .foregroundColor(AppColors.textPrimary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill((viewModel.selectedCategory?.color ?? .gray).opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .stroke((viewModel.selectedCategory?.color ?? .gray).opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Category: \(viewModel.selectedCategory?.name ?? "Other"). Tap to change.")

            // Date pill
            Button {
                HapticManager.selectionChanged()
                showDatePicker = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: IconSize.xs))
                        .foregroundColor(AppColors.textSecondary)

                    Text(smartDateLabel)
                        .font(AppTypography.labelDefault())
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(AppColors.backgroundTertiary)
                )
                .overlay(
                    Capsule()
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Transaction date: \(smartDateLabel). Tap to change.")

            Spacer()
        }
    }

    // MARK: - Section 4: Paid By

    private var paidBySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("PAID BY")

            VStack(spacing: 0) {
                if viewModel.paidBySearchText.isEmpty && viewModel.selectedPayerPersons.isEmpty {
                    // Default single payer: "You"
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
                                Text(CurrencyFormatter.formatAbsolute(viewModel.totalAmountDouble, currencyCode: viewModel.transactionCurrency))
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
                    // Multi-payer chips
                    FlowLayout(spacing: Spacing.sm) {
                        ForEach(sortedByCurrentUser(viewModel.selectedPayerPersons), id: \.self) { person in
                            avatarChip(person) { viewModel.togglePayer(person) }
                        }

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
                            .background(Color.clear)
                            .cornerRadius(CornerRadius.full)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.full)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add payer")
                    }
                    .padding(.horizontal, Spacing.cardPadding)
                    .padding(.vertical, Spacing.md)
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

            ForEach(viewModel.filteredPaidByContacts, id: \.objectID) { person in
                Divider().padding(.leading, Spacing.cardPadding + AvatarSize.sm + Spacing.md)

                Button {
                    withAnimation(AppAnimation.quick) {
                        viewModel.togglePayer(person)
                        viewModel.paidBySearchText = ""
                    }
                    HapticManager.selectionChanged()
                } label: {
                    searchResultRow(
                        name: person.displayName,
                        initials: person.initials,
                        color: personColor(for: person),
                        isSelected: viewModel.selectedPayerPersons.contains(person)
                    )
                }
                .buttonStyle(.plain)
            }

            if viewModel.filteredPaidByContacts.isEmpty {
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

    // MARK: - Section 5: Split With

    private var splitWithSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("SPLIT WITH")

            VStack(spacing: 0) {
                // Selected participants chips
                if !viewModel.selectedParticipants.isEmpty && viewModel.splitWithSearchText.isEmpty {
                    FlowLayout(spacing: Spacing.sm) {
                        ForEach(sortedByCurrentUser(viewModel.selectedParticipants), id: \.self) { person in
                            let isCurrentUser = CurrentUser.isCurrentUser(person.id)
                            if isCurrentUser {
                                // Current user chip — non-removable with lock
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
                                .background(Color.clear)
                                .cornerRadius(CornerRadius.full)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.full)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
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

                        // Add People button
                        Button {
                            focusedField = .splitWithSearch
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "plus")
                                    .font(.system(size: IconSize.xs, weight: .semibold))
                                Text("Add People")
                                    .font(AppTypography.labelSmall())
                            }
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.clear)
                            .cornerRadius(CornerRadius.full)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.full)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add participant")
                    }
                    .padding(.horizontal, Spacing.cardPadding)
                    .padding(.vertical, Spacing.md)

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

    // MARK: - Section 6: Split Method (Horizontal Scroll)

    private var splitMethodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("SPLIT METHOD")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(SplitMethod.allCases) { method in
                        methodPill(method)
                    }
                }
            }
        }
    }

    private func methodPill(_ method: SplitMethod) -> some View {
        let isSelected = viewModel.splitMethod == method

        return Button {
            guard viewModel.splitMethod != method else { return }
            withAnimation(AppAnimation.spring) {
                viewModel.splitMethod = method
                viewModel.initializeDefaultRawInputs(for: method)
            }
            HapticManager.selectionChanged()
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(method.icon)
                    .font(AppTypography.labelLarge())
                Text(method.displayName)
                    .font(AppTypography.labelSmall())
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? AppColors.onAccent : AppColors.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? AppColors.accent : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(method.displayName) split method\(isSelected ? ", selected" : "")")
    }

    // MARK: - Paid By Breakdown Section

    private var paidByBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("PAID BY AMOUNTS")

            VStack(spacing: 0) {
                let sortedPayers = sortedByCurrentUser(viewModel.selectedPayerPersons)
                ForEach(Array(sortedPayers.enumerated()), id: \.element) { index, person in
                    payerAmountRow(person: person)

                    if index < sortedPayers.count - 1 {
                        Divider().padding(.leading, Spacing.cardPadding + AvatarSize.sm + Spacing.md)
                    }
                }

                // Warning if unbalanced
                if !viewModel.isPaidByBalanced {
                    Divider()
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: IconSize.sm))
                            .foregroundColor(AppColors.warning)
                        Text("Amounts must equal \(CurrencyFormatter.formatAbsolute(viewModel.totalAmountDouble, currencyCode: viewModel.transactionCurrency))")
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
                Text(CurrencyFormatter.symbol(for: viewModel.transactionCurrency))
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

    // MARK: - Section 8: Breakdown

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
                    .transition(.opacity.combined(with: .move(edge: .top)))

                if index < sortedParticipants.count - 1 {
                    Divider().padding(.leading, Spacing.cardPadding + AvatarSize.sm + Spacing.md)
                }
            }

            // Heavy divider before total
            Rectangle()
                .fill(AppColors.borderStrong)
                .frame(height: 2)
                .padding(.vertical, Spacing.xs)

            // Total row
            HStack {
                Text("Total Balance")
                    .font(AppTypography.headingSmall())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    let balance = viewModel.totalBalance
                    let isBalanced = abs(balance) < TransactionViewModel.epsilon

                    HStack(spacing: Spacing.xs) {
                        Text(CurrencyFormatter.symbol(for: viewModel.transactionCurrency))
                            .font(AppTypography.bodyDefault())
                            .foregroundColor(AppColors.textSecondary)

                        Text(CurrencyFormatter.formatDecimal(abs(viewModel.totalAmountDouble - balance), currencyCode: viewModel.transactionCurrency))
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

                if viewModel.splitMethod == .percentage || viewModel.splitMethod == .shares {
                    Text(CurrencyFormatter.formatAbsolute(splitAmount, currencyCode: viewModel.transactionCurrency))
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
                    Text(CurrencyFormatter.symbol(for: viewModel.transactionCurrency))
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
                    Text(CurrencyFormatter.symbol(for: viewModel.transactionCurrency))
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

    // MARK: - Section 9: Note

    private var noteSection: some View {
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

    // MARK: - Section 10: Sticky Bottom Bar

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
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("Save Transaction")
                            .font(AppTypography.buttonLarge())
                            .foregroundColor(AppColors.onAccent)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: ButtonHeight.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .fill(viewModel.isValid ? AppColors.accent : AppColors.disabled)
                )
            }
            .disabled(!viewModel.isValid || viewModel.isSaving)
            .opacity(viewModel.isValid ? 1.0 : 0.6)
            .scaleEffect(viewModel.isSaving ? 0.98 : 1.0)
            .animation(AppAnimation.standard, value: viewModel.isValid)
            .animation(AppAnimation.standard, value: viewModel.isSaving)
            .animation(AppAnimation.spring, value: viewModel.saveCompleted)
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
            .background(Color.clear)
            .cornerRadius(CornerRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.full)
                    .stroke(AppColors.border, lineWidth: 1)
            )
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
}

// MARK: - Preview

#Preview {
    AddTransactionView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
