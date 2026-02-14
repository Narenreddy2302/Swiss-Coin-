//
//  FinanceQuickActionView.swift
//  Swiss Coin
//
//  Main entry point for the Quick Action feature.
//  Incudes the Floating Action Button and Sheet management.
//

import CoreData
import SwiftUI

struct FinanceQuickActionView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = QuickActionViewModel(context: PersistenceController.shared.container.viewContext)

    var body: some View {
        ZStack {
            // This view is intended to be used as an overlay.
            // It puts the FAB in the bottom right.

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionButton {
                        viewModel.openSheet()
                    }
                }
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        // MARK: Bottom Sheet Presentation
        .sheet(isPresented: $viewModel.isSheetPresented) {
            QuickActionSheet(viewModel: viewModel)
                .environment(\.managedObjectContext, viewContext)
            // iOS 16+ modifier for rounded corners
            // .presentationCornerRadius(14)
        }
        .onAppear {
            viewModel.setup(context: viewContext)
        }
    }
}
