//
//  MemberPickerView.swift
//  Swiss Coin
//
//  View for selecting members when creating/editing shared subscriptions.
//

import CoreData
import SwiftUI

struct MemberPickerView: View {
    @Binding var selectedMembers: Set<Person>
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        animation: .default)
    private var allPeople: FetchedResults<Person>

    // Filter out current user
    private var availablePeople: [Person] {
        allPeople.filter { !CurrentUser.isCurrentUser($0.id) }
    }

    @State private var searchText = ""

    private var filteredPeople: [Person] {
        if searchText.isEmpty {
            return availablePeople
        }
        return availablePeople.filter { person in
            (person.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Search
                Section {
                    TextField("Search people", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .listRowBackground(AppColors.cardBackground)

                // Selected Members
                if !selectedMembers.isEmpty {
                    Section {
                        ForEach(Array(selectedMembers).sorted { ($0.name ?? "") < ($1.name ?? "") }) { member in
                            HStack {
                                Circle()
                                    .fill(Color(hex: member.colorHex ?? "#808080").opacity(0.3))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(member.initials)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: member.colorHex ?? "#808080"))
                                    )

                                Text(member.displayName)
                                    .font(AppTypography.body())
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Button {
                                    HapticManager.tap()
                                    selectedMembers.remove(member)
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                        }
                    } header: {
                        Text("Selected (\(selectedMembers.count))")
                    }
                    .listRowBackground(AppColors.cardBackground)
                }

                // Available People
                Section {
                    if filteredPeople.isEmpty {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.textSecondary.opacity(0.5))

                            Text("No People Found")
                                .font(AppTypography.headline())
                                .foregroundColor(AppColors.textPrimary)

                            Text("Add people in the Library tab first")
                                .font(AppTypography.subheadline())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                    } else {
                        ForEach(filteredPeople) { person in
                            if !selectedMembers.contains(person) {
                                Button {
                                    HapticManager.selectionChanged()
                                    selectedMembers.insert(person)
                                } label: {
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: person.colorHex ?? "#808080").opacity(0.3))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Text(person.initials)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(Color(hex: person.colorHex ?? "#808080"))
                                            )

                                        Text(person.displayName)
                                            .font(AppTypography.body())
                                            .foregroundColor(AppColors.textPrimary)
                                            .lineLimit(1)

                                        Spacer()

                                        Image(systemName: "circle")
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Add Members")
                }
                .listRowBackground(AppColors.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundSecondary.ignoresSafeArea())
            .navigationTitle("Select Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.tap()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
