//
//  ArchivedPeopleView.swift
//  Swiss Coin
//
//  View for displaying and managing archived people.
//

import CoreData
import SwiftUI

struct ArchivedPeopleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        predicate: NSPredicate(format: "isArchived == YES"),
        animation: nil)
    private var archivedPeople: FetchedResults<Person>

    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if archivedPeople.isEmpty {
                    EmptyArchivedPeopleView()
                } else {
                    archivedList
                }
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        HapticManager.tap()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    HapticManager.tap()
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var archivedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let peopleCount = archivedPeople.count
                ForEach(Array(archivedPeople.enumerated()), id: \.element.id) { index, person in
                    ArchivedPersonRow(
                        person: person,
                        onRestore: { restorePerson(person) },
                        onDelete: { deletePerson(person) }
                    )

                    if index < peopleCount - 1 {
                        Divider()
                            .padding(.leading, Spacing.lg + AvatarSize.lg + Spacing.md)
                    }
                }
            }
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.section + Spacing.sm)
        }
    }

    private func restorePerson(_ person: Person) {
        person.isArchived = false

        do {
            try viewContext.save()
            HapticManager.success()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to restore person: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func deletePerson(_ person: Person) {
        HapticManager.delete()

        viewContext.delete(person)
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to delete person: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Archived Person Row

private struct ArchivedPersonRow: View {
    @ObservedObject var person: Person
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false
    @State private var balance: Double = 0

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            Circle()
                .fill(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                .overlay(
                    Text(person.initials)
                        .font(AppTypography.headingLarge())
                        .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name ?? "Unknown")
                    .font(AppTypography.bodyLarge())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                if abs(balance) > 0.01 {
                    Text(CurrencyFormatter.formatAbsolute(balance))
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(balance > 0 ? AppColors.positive : AppColors.negative)
                } else {
                    Text("settled up")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.neutral)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: Spacing.sm) {
                Button {
                    HapticManager.tap()
                    onRestore()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: IconSize.lg))
                        .foregroundColor(AppColors.accent)
                }
                .accessibilityLabel("Restore person")

                Button {
                    HapticManager.tap()
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: IconSize.lg))
                        .foregroundColor(AppColors.negative)
                }
                .accessibilityLabel("Delete person permanently")
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColors.background)
        .alert("Delete Permanently", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to permanently delete \"\(person.name ?? "this person")\"? This will remove all their transactions, payment history, and shared expenses. This action cannot be undone.")
        }
        .task {
            balance = person.calculateBalance()
        }
    }
}

// MARK: - Empty Archived People View

private struct EmptyArchivedPeopleView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "archivebox")
                .font(.system(size: IconSize.xxl))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                .accessibilityHidden(true)

            Text("No Archived People")
                .font(AppTypography.displayMedium())
                .foregroundColor(AppColors.textPrimary)

            Text("People you archive will appear here. You can restore them at any time.")
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundSecondary)
    }
}
