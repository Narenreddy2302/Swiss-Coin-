import CoreData
import SwiftUI

struct AddTransactionView: View {
    @StateObject private var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    var initialParticipant: Person?
    var initialGroup: UserGroup?

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
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // MARK: - Hero Amount Section
                        amountSection

                        // MARK: - Transaction Info Card
                        transactionInfoCard

                        // MARK: - Participants Card
                        participantsCard

                        // MARK: - Split Method Card
                        splitMethodCard

                        // MARK: - Split Breakdown Card
                        splitBreakdownCard

                        // MARK: - Validation Feedback
                        validationSection

                        // Bottom padding for save button
                        Spacer()
                            .frame(height: ButtonHeight.xl + Spacing.section)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)

                // MARK: - Floating Save Button
                saveButton
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
            .onAppear {
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
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: Spacing.md) {
            Text("Total Amount")
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(CurrencyFormatter.currencySymbol)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.totalAmount.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)

                TextField("0.00", text: $viewModel.totalAmount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .limitTextLength(to: 12, text: $viewModel.totalAmount)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
            .padding(.horizontal, Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(AppColors.cardBackground)
            )
        }
    }

    // MARK: - Transaction Info Card

    private var transactionInfoCard: some View {
        VStack(spacing: 0) {
            // Title Field
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Title")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                TextField("What's this for?", text: $viewModel.title)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)
                    .limitTextLength(to: ValidationLimits.maxTransactionTitleLength, text: $viewModel.title)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            Divider()
                .padding(.leading, Spacing.lg)

            // Date Picker
            HStack {
                Text("Date")
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(AppColors.accent)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            Divider()
                .padding(.leading, Spacing.lg)

            // Payer Picker
            PayerPicker(selection: $viewModel.selectedPayer)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }

    // MARK: - Participants Card

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Split With")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)

                    if !viewModel.selectedParticipants.isEmpty {
                        Text("\(viewModel.selectedParticipants.count) participant\(viewModel.selectedParticipants.count == 1 ? "" : "s")")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                NavigationLink(
                    destination: ParticipantSelectorView(
                        selectedParticipants: $viewModel.selectedParticipants)
                ) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: IconSize.sm, weight: .medium))
                        Text(viewModel.selectedParticipants.isEmpty ? "Add" : "Edit")
                            .font(AppTypography.subheadlineMedium())
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(AppColors.backgroundTertiary)
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)

            // Selected Participants Chips
            if !viewModel.selectedParticipants.isEmpty {
                Divider()
                    .padding(.leading, Spacing.lg)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(Array(viewModel.selectedParticipants).sorted { ($0.name ?? "") < ($1.name ?? "") }, id: \.self) { person in
                            participantChip(person)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }

    private func participantChip(_ person: Person) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(person.avatarBackgroundColor)
                .frame(width: 24, height: 24)
                .overlay(
                    Text(CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(person.avatarTextColor)
                )

            Text(CurrentUser.isCurrentUser(person.id) ? "Me" : (person.firstName ?? person.name ?? "?"))
                .font(AppTypography.subheadlineMedium())
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.leading, Spacing.xs)
        .padding(.trailing, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(AppColors.backgroundTertiary)
        )
    }

    // MARK: - Split Method Card

    private var splitMethodCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Split Method")
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, Spacing.lg)

            // Custom segmented control
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(SplitMethod.allCases) { method in
                        splitMethodButton(method)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(AppColors.cardBackground)
        )
    }

    private func splitMethodButton(_ method: SplitMethod) -> some View {
        Button {
            withAnimation(AppAnimation.standard) {
                viewModel.splitMethod = method
            }
            HapticManager.selectionChanged()
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: method.systemImage)
                    .font(.system(size: IconSize.md, weight: .medium))
                Text(method.displayName)
                    .font(AppTypography.caption())
            }
            .foregroundColor(viewModel.splitMethod == method ? AppColors.buttonForeground : AppColors.textSecondary)
            .frame(minWidth: 64)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(viewModel.splitMethod == method ? AppColors.buttonBackground : AppColors.backgroundTertiary)
            )
        }
        .buttonStyle(AppButtonStyle(haptic: .none))
    }

    // MARK: - Split Breakdown Card

    @ViewBuilder
    private var splitBreakdownCard: some View {
        if !viewModel.selectedParticipants.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Header with total
                HStack {
                    Text("Breakdown")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    let calculated = viewModel.currentCalculatedTotal
                    if viewModel.splitMethod == .percentage {
                        Text(String(format: "%.1f%%", calculated))
                            .font(AppTypography.amountSmall())
                            .foregroundColor(abs(calculated - 100) < 0.1 ? AppColors.positive : AppColors.negative)
                    } else if viewModel.splitMethod != .equal {
                        Text(CurrencyFormatter.format(calculated))
                            .font(AppTypography.amountSmall())
                            .foregroundColor(
                                abs(calculated - viewModel.totalAmountDouble) < 0.01
                                    ? AppColors.positive : AppColors.negative)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)

                Divider()
                    .padding(.leading, Spacing.lg)

                // Participant splits
                ForEach(Array(viewModel.selectedParticipants).sorted { ($0.name ?? "") < ($1.name ?? "") }, id: \.self) { person in
                    SplitInputView(viewModel: viewModel, person: person)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)

                    if person != Array(viewModel.selectedParticipants).sorted(by: { ($0.name ?? "") < ($1.name ?? "") }).last {
                        Divider()
                            .padding(.leading, Spacing.lg)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackground)
            )
        } else {
            // Empty state
            VStack(spacing: Spacing.md) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: IconSize.xl))
                    .foregroundColor(AppColors.textTertiary)

                Text("Select participants to configure the split")
                    .font(AppTypography.subheadline())
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
            .padding(.horizontal, Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackground)
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
        VStack(spacing: 0) {
            // Gradient fade
            LinearGradient(
                colors: [AppColors.backgroundSecondary.opacity(0), AppColors.backgroundSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Spacing.xxl)

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
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
            .background(AppColors.backgroundSecondary)
        }
    }
}

// Helper Picker
struct PayerPicker: View {
    @Binding var selection: Person?
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        animation: .default)
    private var people: FetchedResults<Person>

    // Filter out current user since "Me" is already shown as an option
    private var otherPeople: [Person] {
        people.filter { !CurrentUser.isCurrentUser($0.id) }
    }

    var body: some View {
        Picker("Who Paid?", selection: $selection) {
            Text("Me").tag(Person?.none)
            ForEach(otherPeople) { person in
                Text(person.name ?? "Unknown").tag(person as Person?)
            }
        }
    }
}
