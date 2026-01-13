import CoreData
import SwiftUI

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Fetch last 5 transactions
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FinancialTransaction.date, ascending: false)],
        animation: .default)
    private var recentTransactions: FetchedResults<FinancialTransaction>

    @State private var showingProfile = false

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Summary Section (Hero-like)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Summary")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    SummaryCard(
                                        title: "You Owe", amount: 0, color: .red,
                                        icon: "arrow.down.left.circle.fill")
                                    SummaryCard(
                                        title: "You are Owed", amount: 0, color: .green,
                                        icon: "arrow.up.right.circle.fill")
                                }
                                .padding(.horizontal)
                            }
                        }

                        Divider()
                            .padding(.leading)

                        // Recent Activity (Up Next style)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Recent Activity")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                NavigationLink(destinations: TransactionHistoryView()) {
                                    Text("See All")
                                        .font(.body)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal)

                            if recentTransactions.isEmpty {
                                EmptyStateView()
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(recentTransactions.prefix(5)) { transaction in
                                        TransactionRow(transaction: transaction)
                                        Divider()
                                            .padding(.leading, 20)
                                    }
                                }
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top)
                    .padding(.bottom, 40)
                }
                .background(Color(uiColor: .secondarySystemBackground))

                // Overlay the Quick Action FAB
                FinanceQuickActionView()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileButton {
                        showingProfile = true
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No recent activity")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Transactions you add will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String  // Added icon

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text(Formatters.currency.string(from: NSNumber(value: amount)) ?? "$0.00")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .frame(width: 160)
        .padding()
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct TransactionRow: View {
    let transaction: FinancialTransaction

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Date Box (Simulating Album Art/Episode logic)
            VStack {
                Text(transaction.date ?? Date(), format: .dateTime.month())
                    .font(.caption2)
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                Text(transaction.date ?? Date(), format: .dateTime.day())
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(width: 50, height: 50)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title ?? "Unknown")
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let method = transaction.splitMethod {
                        Text(method)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(4)
                    }

                    if let payer = transaction.payer {
                        Text("Paid by \(payer.name ?? "?")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Text(Formatters.currency.string(from: NSNumber(value: transaction.amount)) ?? "$0.00")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .padding()
        .background(Color(uiColor: .tertiarySystemGroupedBackground))  // Ensure touch target
    }
}

struct Formatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()
}

extension NavigationLink where Label == Text, Destination == TransactionHistoryView {
    init(destinations: Destination, @ViewBuilder label: () -> Label) {
        self.init(destination: destinations, label: label)
    }
}
