//
//  SubscriptionView.swift
//  Swiss Coin
//
//  Main subscription view with segmented control for Personal and Shared subscriptions.
//  Follows the PeopleView pattern exactly for consistency.
//

import CoreData
import SwiftUI

struct SubscriptionView: View {
    @State private var selectedSegment = 0  // 0 = Personal, 1 = Shared
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddSubscription = false
    @State private var showingArchivedSubscriptions = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment Header (matching People's page)
                HStack(spacing: Spacing.md) {
                    ActionHeaderButton(
                        title: "Personal",
                        icon: "person.fill",
                        color: selectedSegment == 0 ? AppColors.accent : AppColors.textPrimary
                    ) {
                        HapticManager.selectionChanged()
                        searchText = ""
                        selectedSegment = 0
                    }

                    ActionHeaderButton(
                        title: "Shared",
                        icon: "person.2.fill",
                        color: selectedSegment == 1 ? AppColors.accent : AppColors.textPrimary
                    ) {
                        HapticManager.selectionChanged()
                        searchText = ""
                        selectedSegment = 1
                    }
                }
                .padding(.horizontal)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.sm)
                .background(AppColors.backgroundSecondary)

                // Content
                Group {
                    if selectedSegment == 0 {
                        PersonalSubscriptionListView(showingAddSubscription: $showingAddSubscription, searchText: $searchText)
                    } else {
                        SharedSubscriptionListView(showingAddSubscription: $showingAddSubscription, searchText: $searchText)
                    }
                }
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Subscriptions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.tap()
                        showingArchivedSubscriptions = true
                    } label: {
                        Image(systemName: "archivebox")
                            .font(AppTypography.labelLarge())
                    }
                    .accessibilityLabel("View archived subscriptions")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.tap()
                        showingAddSubscription = true
                    } label: {
                        Image(systemName: "plus")
                            .font(AppTypography.buttonLarge())
                    }
                    .accessibilityLabel("Add subscription")
                }
            }
            .sheet(isPresented: $showingAddSubscription) {
                AddSubscriptionView(isSharedDefault: selectedSegment == 1)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingArchivedSubscriptions) {
                ArchivedSubscriptionsView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .onAppear {
                HapticManager.prepare()
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search subscriptions"
        )
    }
}
