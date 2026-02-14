//
//  QuickActionSheetPresenter.swift
//  Swiss Coin
//
//  Wrapper component that presents QuickActionSheet with proper ViewModel initialization.
//  Supports pre-selecting a Person or UserGroup for the transaction.
//

import SwiftUI
import CoreData

struct QuickActionSheetPresenter: View {
    @Environment(\.managedObjectContext) private var viewContext

    let initialPerson: Person?
    let initialGroup: UserGroup?

    @StateObject private var viewModel: QuickActionViewModel

    // MARK: - Initialization

    /// Initialize with optional Person pre-selection
    init(initialPerson: Person) {
        self.initialPerson = initialPerson
        self.initialGroup = nil

        // Create ViewModel with context - will be replaced in onAppear
        _viewModel = StateObject(wrappedValue: QuickActionViewModel(
            context: PersistenceController.shared.container.viewContext,
            initialPerson: initialPerson
        ))
    }

    /// Initialize with optional UserGroup pre-selection
    init(initialGroup: UserGroup) {
        self.initialPerson = nil
        self.initialGroup = initialGroup

        // Create ViewModel with context - will be replaced in onAppear
        _viewModel = StateObject(wrappedValue: QuickActionViewModel(
            context: PersistenceController.shared.container.viewContext,
            initialGroup: initialGroup
        ))
    }

    /// Initialize with no pre-selection (new transaction)
    init() {
        self.initialPerson = nil
        self.initialGroup = nil

        // Create ViewModel with context - will be replaced in onAppear
        _viewModel = StateObject(wrappedValue: QuickActionViewModel(
            context: PersistenceController.shared.container.viewContext
        ))
    }

    // MARK: - Body

    var body: some View {
        QuickActionSheet(viewModel: viewModel)
            .environment(\.managedObjectContext, viewContext)
            .onAppear {
                // Ensure ViewModel uses the correct context
                viewModel.setup(context: viewContext)
            }
    }
}

// MARK: - Preview

#Preview("Person") {
    QuickActionSheetPresenter(
        initialPerson: {
            let context = PersistenceController.preview.container.viewContext
            let person = Person(context: context)
            person.id = UUID()
            person.name = "John Doe"
            return person
        }()
    )
}

#Preview("Group") {
    QuickActionSheetPresenter(
        initialGroup: {
            let context = PersistenceController.preview.container.viewContext
            let group = UserGroup(context: context)
            group.id = UUID()
            group.name = "Weekend Trip"
            return group
        }()
    )
}

#Preview("No Selection") {
    QuickActionSheetPresenter()
}
