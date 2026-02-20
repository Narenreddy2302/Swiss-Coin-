import SwiftUI
import CoreData

struct AddTransactionPresenter: View {
    @Environment(\.managedObjectContext) private var viewContext

    @StateObject private var viewModel: TransactionViewModel
    @State private var hasPhoneNumber = false

    // MARK: - Initialization

    /// Initialize with no pre-selection (new transaction)
    init() {
        _viewModel = StateObject(wrappedValue: TransactionViewModel(
            context: PersistenceController.shared.container.viewContext
        ))
    }

    /// Initialize with a Person pre-selected as participant
    init(initialPerson: Person) {
        _viewModel = StateObject(wrappedValue: TransactionViewModel(
            context: PersistenceController.shared.container.viewContext,
            initialPerson: initialPerson
        ))
    }

    /// Initialize with a UserGroup pre-selected (all members added)
    init(initialGroup: UserGroup) {
        _viewModel = StateObject(wrappedValue: TransactionViewModel(
            context: PersistenceController.shared.container.viewContext,
            initialGroup: initialGroup
        ))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            if hasPhoneNumber {
                AddTransactionView(viewModel: viewModel)
            } else {
                PhoneRequiredView()
            }
        }
        .presentationBackground(AppColors.backgroundSecondary)
        .onAppear { checkPhoneNumber() }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            checkPhoneNumber()
        }
    }

    // MARK: - Phone Check

    private func checkPhoneNumber() {
        let currentUser = CurrentUser.getOrCreate(in: viewContext)
        let phone = currentUser.phoneNumber ?? ""
        let digits = phone.filter { $0.isNumber }
        hasPhoneNumber = digits.count >= 7
    }
}
