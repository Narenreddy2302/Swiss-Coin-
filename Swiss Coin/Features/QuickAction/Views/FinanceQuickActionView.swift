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
                    Button {
                        HapticManager.tap()
                        showingAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: IconSize.lg, weight: .semibold))
                            .foregroundColor(AppColors.onAccent)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.accent, AppColors.accent.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: AppColors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add transaction")
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
