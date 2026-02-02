import CoreData
import SwiftUI

struct EditGroupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var group: UserGroup

    @State private var groupName: String
    @State private var colorHex: String
    @State private var selectedMembers: Set<NSManagedObjectID>
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var searchText = ""

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)],
        animation: .default
    )
    private var allPeople: FetchedResults<Person>

    init(group: UserGroup) {
        self.group = group
        _groupName = State(initialValue: group.name ?? "")
        _colorHex = State(initialValue: group.colorHex ?? "#007AFF")

        // Pre-select current members (exclude current user)
        let memberSet = group.members as? Set<Person> ?? []
        let memberIDs = memberSet
            .filter { !CurrentUser.isCurrentUser($0.id) }
            .map { $0.objectID }
        _selectedMembers = State(initialValue: Set(memberIDs))
    }

    /// Generate a valid 6-character hex color code
    private static func randomColorHex() -> String {
        String(format: "#%06X", Int.random(in: 0...0xFFFFFF))
    }

    /// People available to add (excluding current user)
    private var availablePeople: [Person] {
        let filtered = allPeople.filter { !CurrentUser.isCurrentUser($0.id) }
        if searchText.isEmpty {
            return filtered
        }
        return filtered.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var hasChanges: Bool {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalName = group.name ?? ""
        let originalColor = group.colorHex ?? "#007AFF"

        let originalMemberSet = group.members as? Set<Person> ?? []
        let originalMemberIDs = Set(
            originalMemberSet
                .filter { !CurrentUser.isCurrentUser($0.id) }
                .map { $0.objectID }
        )

        return trimmedName != originalName
            || colorHex != originalColor
            || selectedMembers != originalMemberIDs
    }

    var body: some View {
        VStack(spacing: 0) {
            // Group Name Input
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Group Name")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.lg)

                TextField("Enter group name", text: $groupName)
                    .font(AppTypography.body())
                    .limitTextLength(to: ValidationLimits.maxNameLength, text: $groupName)
                    .padding(Spacing.md)
                    .background(AppColors.backgroundTertiary)
                    .cornerRadius(CornerRadius.sm)
                    .padding(.horizontal, Spacing.lg)
            }
            .padding(.top, Spacing.lg)

            // Color picker
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Color")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Spacing.lg)

                HStack {
                    ColorPickerRow(selectedColor: $colorHex)
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.top, Spacing.md)

            // Selected Members Preview
            if !selectedMembers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(selectedMemberPersons, id: \.objectID) { person in
                            VStack(spacing: Spacing.xs) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                                        .frame(width: AvatarSize.md, height: AvatarSize.md)
                                    Text(person.initials)
                                        .font(AppTypography.caption())
                                        .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                                }

                                Text(person.firstName)
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                            }
                            .onTapGesture {
                                HapticManager.selectionChanged()
                                selectedMembers.remove(person.objectID)
                            }
                        }
                    }
                    .padding(Spacing.lg)
                }
                .background(AppColors.backgroundSecondary)
            }

            // Member List
            List {
                Section(header: Text("Members").font(AppTypography.subheadlineMedium())) {
                    if availablePeople.isEmpty {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "person.slash")
                                .font(.system(size: IconSize.xl))
                                .foregroundColor(AppColors.textSecondary)
                            Text("No people available")
                                .font(AppTypography.subheadline())
                                .foregroundColor(AppColors.textSecondary)
                            Text("Add people first to include them in groups")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(availablePeople, id: \.objectID) { person in
                            Button(action: {
                                HapticManager.selectionChanged()
                                toggleMember(person)
                            }) {
                                HStack(spacing: Spacing.md) {
                                    Circle()
                                        .fill(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex).opacity(0.2))
                                        .frame(width: AvatarSize.sm, height: AvatarSize.sm)
                                        .overlay(
                                            Text(person.initials)
                                                .font(AppTypography.caption())
                                                .foregroundColor(Color(hex: person.colorHex ?? CurrentUser.defaultColorHex))
                                        )

                                    Text(person.name ?? "Unknown")
                                        .font(AppTypography.body())
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()

                                    Image(
                                        systemName: selectedMembers.contains(person.objectID)
                                            ? "checkmark.circle.fill" : "circle"
                                    )
                                    .font(.system(size: 22))
                                    .foregroundColor(
                                        selectedMembers.contains(person.objectID)
                                            ? AppColors.accent : AppColors.textSecondary
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundSecondary)
            .searchable(text: $searchText, prompt: "Search people")
        }
        .background(AppColors.backgroundSecondary)
        .navigationTitle("Edit Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    HapticManager.cancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    HapticManager.tap()
                    saveGroup()
                }
                .disabled(
                    groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || selectedMembers.isEmpty || !hasChanges
                )
                .foregroundColor(
                    groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || selectedMembers.isEmpty || !hasChanges
                        ? AppColors.disabled : AppColors.accent
                )
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            HapticManager.prepare()
        }
    }

    private var selectedMemberPersons: [Person] {
        availablePeople.filter { selectedMembers.contains($0.objectID) }
            + allPeople.filter {
                selectedMembers.contains($0.objectID)
                    && !CurrentUser.isCurrentUser($0.id)
                    && !availablePeople.contains($0)
            }
    }

    private func toggleMember(_ person: Person) {
        if selectedMembers.contains(person.objectID) {
            selectedMembers.remove(person.objectID)
        } else {
            selectedMembers.insert(person.objectID)
        }
    }

    private func saveGroup() {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            HapticManager.error()
            return
        }

        group.name = trimmedName
        group.colorHex = colorHex

        // Update members: clear non-current-user members, then re-add selected ones
        // Keep the current user always as a member
        let existingMembers = group.members as? Set<Person> ?? []
        for member in existingMembers {
            if !CurrentUser.isCurrentUser(member.id) {
                group.removeFromMembers(member)
            }
        }

        // Add selected members
        for objectID in selectedMembers {
            if let person = try? viewContext.existingObject(with: objectID) as? Person {
                group.addToMembers(person)
            }
        }

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to save changes. Please try again."
            showingError = true
        }
    }
}
