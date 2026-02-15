import CoreData
import SwiftUI

struct FinanceQuickActionView: View {

    @State private var showingAddTransaction = false

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionButton {
                        showingAddTransaction = true
                    }
                }
                .padding(.trailing, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionPresenter()
        }
    }
}
