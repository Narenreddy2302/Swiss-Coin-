import CoreData
import SwiftUI

struct ParticipantSelectorView: View {
    @Binding var selectedParticipants: Set<Person>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        animation: .default)
    private var people: FetchedResults<Person>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \UserGroup.name, ascending: true)],
        animation: .default)
    private var groups: FetchedResults<UserGroup>

    @State private var pickerMode = 0

    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingImportContacts = false

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Picker
            Picker("Mode", selection: $pickerMode) {
                Text("People").tag(0)
                Text("Groups").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            // Selected count badge
            if !selectedParticipants.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(AppColors.positive)

                    Text("\(selectedParticipants.count) selected")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Button {
                        HapticManager.tap()
                        withAnimation(AppAnimation.standard) {
                            selectedParticipants.removeAll()
                        }
                    } label: {
                        Text("Clear All")
                            .font(AppTypography.subheadlineMedium())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(AppColors.positive.opacity(0.06))
            }

            Divider()

            // Content
            ScrollView {
                LazyVStack(spacing: 0) {
                    if pickerMode == 0 {
                        ForEach(people) { person in
                            personRow(person)

                            if person.id != people.last?.id {
                                Divider()
                                    .padding(.leading, Spacing.lg + AvatarSize.md + Spacing.md)
                            }
                        }
                    } else {
                        ForEach(groups) { group in
                            groupRow(group)

                            if group.id != groups.last?.id {
                                Divider()
                                    .padding(.leading, Spacing.lg + AvatarSize.md + Spacing.md)
                            }
                        }
                    }
                }
            }
        }
        .background(AppColors.backgroundSecondary)
        .navigationTitle("Select Participants")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingImportContacts = true }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: IconSize.md, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .sheet(isPresented: $showingImportContacts) {
            ImportContactsView { newPeople in
                for person in newPeople {
                    selectedParticipants.insert(person)
                }
            }
            .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Person Row

    private func personRow(_ person: Person) -> some View {
        Button(action: {
            HapticManager.selectionChanged()
            withAnimation(AppAnimation.quick) {
                toggle(person)
            }
        }) {
            HStack(spacing: Spacing.md) {
                // Avatar
                Circle()
                    .fill(person.avatarBackgroundColor)
                    .frame(width: AvatarSize.md, height: AvatarSize.md)
                    .overlay(
                        Text(CurrentUser.isCurrentUser(person.id) ? CurrentUser.initials : person.initials)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(person.avatarTextColor)
                    )

                // Name
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    if CurrentUser.isCurrentUser(person.id) {
                        Text("Me")
                            .font(AppTypography.bodyBold())
                            .foregroundColor(AppColors.textPrimary)
                    } else {
                        Text(person.name ?? "Unknown")
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Selection indicator
                if selectedParticipants.contains(person) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: IconSize.lg))
                        .foregroundColor(AppColors.positive)
                } else {
                    Circle()
                        .strokeBorder(AppColors.separator, lineWidth: 1.5)
                        .frame(width: IconSize.lg, height: IconSize.lg)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Group Row

    private func groupRow(_ group: UserGroup) -> some View {
        Button(action: {
            HapticManager.tap()
            withAnimation(AppAnimation.quick) {
                toggleGroup(group)
            }
        }) {
            HStack(spacing: Spacing.md) {
                // Group Icon
                Circle()
                    .fill(Color(hex: group.colorHex ?? "#808080").opacity(0.2))
                    .frame(width: AvatarSize.md, height: AvatarSize.md)
                    .overlay(
                        Image(systemName: "person.2.fill")
                            .font(.system(size: IconSize.sm))
                            .foregroundColor(Color(hex: group.colorHex ?? "#808080"))
                    )

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(group.name ?? "Unknown Group")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    let memberCount = (group.members as? Set<Person>)?.count ?? 0
                    Text("\(memberCount) member\(memberCount == 1 ? "" : "s")")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Add all indicator
                HStack(spacing: Spacing.xs) {
                    Text("Add All")
                        .font(AppTypography.subheadlineMedium())
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: IconSize.md))
                }
                .foregroundColor(AppColors.accent)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func toggle(_ person: Person) {
        if selectedParticipants.contains(person) {
            selectedParticipants.remove(person)
        } else {
            selectedParticipants.insert(person)
        }
    }

    private func toggleGroup(_ group: UserGroup) {
        guard let members = group.members as? Set<Person> else { return }
        // Logic: Add any not currently selected
        for member in members {
            selectedParticipants.insert(member)
        }
    }
}
