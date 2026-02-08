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
                        selectedSegment = 0
                    }

                    ActionHeaderButton(
                        title: "Shared",
                        icon: "person.2.fill",
                        color: selectedSegment == 1 ? AppColors.accent : AppColors.textPrimary
                    ) {
                        HapticManager.selectionChanged()
                        selectedSegment = 1
                    }
                }
                .padding(.horizontal)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.sm)
                .background(AppColors.backgroundSecondary)

                // Content with animation
                Group {
                    if selectedSegment == 0 {
                        PersonalSubscriptionListView()
                    } else {
                        SharedSubscriptionListView()
                    }
                }
                .animation(AppAnimation.standard, value: selectedSegment)
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
                            .font(.system(size: 15, weight: .medium))
                    }
                    .accessibilityLabel("View archived subscriptions")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.tap()
                        showingAddSubscription = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                    }
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
    }
}
