import CoreData
import SwiftUI

struct AddTransactionView: View {
    @StateObject private var viewModel: TransactionViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext

    // We need to inject the context into the ViewModel.
    // Since StateObject is initialized before body, we can't straightforwardly pass environment context to init.
    // Solution: Init with a placeholder, then configure in onAppear, or use a custom init if possible.
    // Easier: Use @ObservedObject if we own it in a parent, but this is a top-level sheet.
    // Let's use a custom init.

    var initialParticipant: Person?
    var initialGroup: UserGroup?

    init(viewContext: NSManagedObjectContext? = nil, initialParticipant: Person? = nil, initialGroup: UserGroup? = nil) {
        self.initialParticipant = initialParticipant
        self.initialGroup = initialGroup
        // We can't access Environment here easily for the default init used by navigation.
        // So we will rely on ".onAppear" pattern or just passing it if possible.
        // Actually, let's just make it ObservedObject and create it in the wrapper? No, that's messy.
        // Correct pattern for SwiftUI 2.0+ is StateObject. We will defer context assignment or use a closure.
        // Let's just create it with a dummy and assign in onAppear for simplicity in this constrained agent environment.
        _viewModel = StateObject(
            wrappedValue: TransactionViewModel(
                context: PersistenceController.shared.container.viewContext))
        // Note: This relies on the shared persistence controller which is global.
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: - 1. Meta Data
                Section(header: Text("Transaction Info")) {
                    TextField("Title", text: $viewModel.title)
                    TextField("Total Amount", text: $viewModel.totalAmount)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)

                    PayerPicker(selection: $viewModel.selectedPayer)
                }

                // MARK: - 2. Participants
                Section(header: Text("Split With (Select Participants)")) {
                    NavigationLink(
                        destination: ParticipantSelectorView(
                            selectedParticipants: $viewModel.selectedParticipants)
                    ) {
                        HStack {
                            Text("Participants")
                            Spacer()
                            Text("\(viewModel.selectedParticipants.count) selected")
                                .foregroundColor(.secondary)
                        }
                    }
                    // Quick view of selected
                    if !viewModel.selectedParticipants.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(viewModel.selectedParticipants), id: \.self) {
                                    person in
                                    Text(person.name ?? "?")
                                        .padding(6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }

                // MARK: - 3. Split Logic
                Picker("Method", selection: $viewModel.splitMethod) {
                    ForEach(SplitMethod.allCases) { method in
                        Image(systemName: method.systemImage).tag(method)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                if !viewModel.selectedParticipants.isEmpty {
                    // Dynamic Inputs
                    ForEach(Array(viewModel.selectedParticipants), id: \.self) { person in
                        SplitInputView(viewModel: viewModel, person: person)
                    }
                } else {
                    Text("Select participants above to configure the split.")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                }

                // Validation Feedback
                if !viewModel.selectedParticipants.isEmpty {
                    Section {
                        HStack {
                            Text("Total Distributed")
                            Spacer()
                            let calculated = viewModel.currentCalculatedTotal

                            if viewModel.splitMethod == .percentage {
                                Text(String(format: "%.1f%%", calculated))
                                    .foregroundColor(abs(calculated - 100) < 0.1 ? .green : .red)
                            } else {
                                Text(String(format: "$%.2f", calculated))
                                    .foregroundColor(
                                        abs(calculated - viewModel.totalAmountDouble) < 0.01
                                            ? .green : .red)
                            }
                        }
                    }
                }

                // Validation Error Message
                if let validationMessage = viewModel.validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.negative)
                    }
                }

                Section {
                    Button("Save Transaction") {
                        viewModel.saveTransaction { success in
                            if success {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isValid)
                    .buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.isValid))
                }
            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                if let person = initialParticipant {
                    viewModel.selectedParticipants.insert(person)
                }
                if let group = initialGroup {
                    viewModel.selectedGroup = group
                    // Pre-populate participants with group members
                    let members = group.members as? Set<Person> ?? []
                    for member in members {
                        viewModel.selectedParticipants.insert(member)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .secondarySystemBackground))
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
        people.filter { !CurrentUser.isCurrentUser($0) }
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
