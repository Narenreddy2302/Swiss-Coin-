import SwiftUI
import CoreData

struct AddTransactionPresenter: View {
    @Environment(\.managedObjectContext) private var viewContext

    @StateObject private var viewModel: TransactionViewModel

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
            AddTransactionView(viewModel: viewModel)
        }
        .presentationBackground(AppColors.backgroundSecondary)
    }
}
