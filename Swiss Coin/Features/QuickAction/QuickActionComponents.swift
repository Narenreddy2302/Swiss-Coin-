//
//  QuickActionComponents.swift
//  Swiss Coin
//
//  Reusable components for the Quick Action views.
//

import CoreData
import SwiftUI
import UIKit

// MARK: - Quick Action Sheet Wrapper

/// A wrapper view that presents QuickActionSheet with optional initial data.
/// Use this when presenting from context menus or other entry points that need pre-selection.
struct QuickActionSheetPresenter: View {
    @StateObject private var viewModel: QuickActionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    /// Initialize with a pre-selected person
    init(initialPerson: Person) {
        // Use the person's own context which is available at init time
        let ctx = initialPerson.managedObjectContext ?? PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: QuickActionViewModel(
            context: ctx,
            initialPerson: initialPerson
        ))
    }

    /// Initialize with a pre-selected group
    init(initialGroup: UserGroup) {
        let ctx = initialGroup.managedObjectContext ?? PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: QuickActionViewModel(
            context: ctx,
            initialGroup: initialGroup
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step Indicator Dots
                HStack(spacing: Spacing.xs) {
                    ForEach(1...viewModel.totalSteps, id: \.self) { step in
                        Circle()
                            .fill(
                                step <= viewModel.currentStep
                                    ? AppColors.accent : AppColors.textSecondary.opacity(0.3)
                            )
                            .frame(width: 8, height: 8)
                    }
                }
                .animation(AppAnimation.standard, value: viewModel.totalSteps)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.md)

                // Step Content
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        switch viewModel.currentStep {
                        case 1:
                            Step1BasicDetailsView(viewModel: viewModel)
                        case 2:
                            Step2SplitConfigView(viewModel: viewModel)
                        case 3:
                            Step3SplitMethodView(viewModel: viewModel)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.tap()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) {
                    HapticManager.tap()
                }
            } message: {
                Text(viewModel.errorMessage)
            }
            .onChange(of: viewModel.isSheetPresented) { _, isPresented in
                if !isPresented {
                    dismiss()
                }
            }
        }
    }

    // Step 1 and 2 titles are rendered in the step content itself
    private var navigationTitle: String {
        switch viewModel.currentStep {
        case 1: return ""
        case 2: return ""
        case 3: return ""
        default: return ""
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(AppColors.buttonForeground)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(AppColors.buttonBackground)
                        .shadow(color: AppColors.shadow, radius: 10, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add new transaction")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Search Bar

struct SearchBarView: View {
    let placeholder: String
    @Binding var text: String
    var onFocus: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: IconSize.sm))
                .foregroundColor(AppColors.textSecondary)

            TextField(
                placeholder, text: $text,
                onEditingChanged: { isEditing in
                    if isEditing {
                        onFocus?()
                    }
                }
            )
            .font(AppTypography.body())

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: IconSize.sm))
                        .foregroundColor(AppColors.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.surface)
        .cornerRadius(CornerRadius.sm)
    }
}

// MARK: - Person Avatar

struct PersonAvatar: View {
    let initials: String
    let isCurrentUser: Bool
    let isSelected: Bool
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? AppColors.accent : AppColors.backgroundSecondary)

            if isCurrentUser {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(isSelected ? AppColors.buttonForeground : .secondary)
                    .accessibilityHidden(true)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundColor(isSelected ? AppColors.buttonForeground : .secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isCurrentUser ? "You" : initials)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Contact Search Row

struct ContactSearchRow: View {
    let person: Person
    let isSelected: Bool

    // Explicitly indicating if this row represents the current user "You"
    // Usually Person entity implies a real contact, but if we wrap "You" in a Person or treat it separately.
    // Here we assume standard Person.

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(
                initials: person.initials,
                isCurrentUser: false,  // Core Data Person is usually not "Me" unless we add a flag
                isSelected: isSelected,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Group Search Row

struct GroupSearchRow: View {
    let group: UserGroup
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Group icon placeholder
            Text("👥")  // group.icon ?? "👥"
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(Color.orange.opacity(0.2))  // group.color ?? .orange
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name ?? "Unnamed Group")
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Selected Group Badge

struct SelectedGroupBadge: View {
    let group: UserGroup
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("👥")
                .font(.system(size: 18))

            Text(group.name ?? "Group")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.accent)
                .lineLimit(1)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 20, height: 20)
                    .background(AppColors.accent.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.accent.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Currency Picker Sheet

struct CurrencyPickerSheet: View {
    @Binding var selectedCurrency: Currency
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(Currency.all) { currency in
                    Button {
                        HapticManager.selectionChanged()
                        selectedCurrency = currency
                        isPresented = false
                    } label: {
                        HStack(spacing: Spacing.md) {
                            Text(currency.flag)
                                .font(.system(size: 24))
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(currency.name)
                                    .font(AppTypography.body())
                                    .foregroundColor(AppColors.textPrimary)
                                Text(currency.code)
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            Text(currency.symbol)
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.textSecondary)
                            if selectedCurrency.id == currency.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.tap()
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Category Picker Sheet

struct CategoryPickerSheet: View {
    @Binding var selectedCategory: Category?
    @Binding var isPresented: Bool
    @State private var showingNewCategory = false

    private var categories: [Category] {
        Category.all
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        Button {
                            HapticManager.selectionChanged()
                            selectedCategory = category
                            isPresented = false
                        } label: {
                            HStack(spacing: Spacing.md) {
                                Text(category.icon)
                                    .font(.system(size: 24))
                                Text(category.name)
                                    .font(AppTypography.body())
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if selectedCategory?.id == category.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Button {
                        HapticManager.tap()
                        showingNewCategory = true
                    } label: {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppColors.accent)
                            Text("Create New Category")
                                .font(AppTypography.body())
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.tap()
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingNewCategory) {
                NewCategorySheet(
                    isPresented: $showingNewCategory,
                    onSave: { category in
                        Category.saveCustomCategory(category)
                        selectedCategory = category
                        isPresented = false
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - New Category Sheet

struct NewCategorySheet: View {
    @Binding var isPresented: Bool
    let onSave: (Category) -> Void

    @State private var name = ""
    @State private var icon = "📌"
    @State private var selectedColorName = "blue"

    private let emojiOptions = ["📌", "🏠", "🎵", "📚", "🎮", "🐾", "💼", "🎁", "🔧", "⚽", "🌿", "💰"]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xxl) {
                // Icon picker
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Icon")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Button {
                                    HapticManager.selectionChanged()
                                    icon = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 28))
                                        .frame(width: 48, height: 48)
                                        .background(
                                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                                .fill(icon == emoji ? AppColors.accent.opacity(0.15) : AppColors.backgroundTertiary)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                                .stroke(icon == emoji ? AppColors.accent : Color.clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                    }
                }

                // Name field
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Name")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)
                    TextField("Category name", text: $name)
                        .font(AppTypography.body())
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(CornerRadius.md)
                }

                // Color picker
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Color")
                        .font(AppTypography.headline())
                        .foregroundColor(AppColors.textPrimary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Spacing.sm) {
                        ForEach(Category.colorOptions, id: \.name) { option in
                            Button {
                                HapticManager.selectionChanged()
                                selectedColorName = option.name
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColorName == option.name ? 3 : 0)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(AppColors.accent, lineWidth: selectedColorName == option.name ? 2 : 0)
                                            .padding(-2)
                                    )
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .background(AppColors.backgroundSecondary)
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.tap()
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticManager.tap()
                        let trimmedName = name.trimmingCharacters(in: .whitespaces)
                        let id = "custom_\(trimmedName.lowercased().replacingOccurrences(of: " ", with: "_"))_\(UUID().uuidString.prefix(4))"
                        let category = Category(
                            id: id,
                            name: trimmedName,
                            icon: icon,
                            color: Category.color(forName: selectedColorName),
                            colorName: selectedColorName
                        )
                        onSave(category)
                    }
                    .font(AppTypography.bodyBold())
                    .disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - Split Method Chip

struct SplitMethodChip: View {
    let method: SplitMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Text(method.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? AppColors.buttonForeground : AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? AppColors.accent : AppColors.backgroundTertiary)
                    )

                Text(method.displayName)
                    .font(AppTypography.caption())
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textPrimary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(isSelected ? AppColors.accent.opacity(0.08) : Color.clear)
            )
        }
    }
}

// MARK: - Split Option Row

struct SplitOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.backgroundTertiary)
                    .cornerRadius(CornerRadius.sm)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)
                    Text(subtitle)
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.4),
                            lineWidth: 2
                        )
                    Circle()
                        .fill(isSelected ? AppColors.accent : Color.clear)
                        .padding(2)
                    Circle()
                        .fill(AppColors.buttonForeground)
                        .frame(width: 8, height: 8)
                        .opacity(isSelected ? 1 : 0)
                }
                .frame(width: 24, height: 24)
            }
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
