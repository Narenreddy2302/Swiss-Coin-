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

    /// Initialize with a pre-selected person
    init(initialPerson: Person) {
        _viewModel = StateObject(wrappedValue: QuickActionViewModel(
            context: PersistenceController.shared.container.viewContext,
            initialPerson: initialPerson
        ))
    }

    /// Initialize with a pre-selected group
    init(initialGroup: UserGroup) {
        _viewModel = StateObject(wrappedValue: QuickActionViewModel(
            context: PersistenceController.shared.container.viewContext,
            initialGroup: initialGroup
        ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Step Indicator Dots
                HStack(spacing: 6) {
                    ForEach(1...3, id: \.self) { step in
                        Circle()
                            .fill(
                                step <= viewModel.currentStep
                                    ? AppColors.accent : AppColors.textSecondary.opacity(0.3)
                            )
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Step Content
                ScrollView {
                    VStack(spacing: 20) {
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.currentStep == 3
                        || (viewModel.currentStep == 2 && !viewModel.isSplit)
                    {
                        Button("Done") {
                            viewModel.saveTransaction()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.currentStep {
        case 1: return "New Transaction"
        case 2: return "Split Options"
        case 3: return "Split Details"
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
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(AppColors.accent)
                        .shadow(color: AppColors.accent.opacity(0.4), radius: 10, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            TextField(
                placeholder, text: $text,
                onEditingChanged: { isEditing in
                    if isEditing {
                        onFocus?()
                    }
                }
            )
            .font(.system(size: 17))

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
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
                    .foregroundColor(isSelected ? .white : .secondary)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
        }
        .frame(width: size, height: size)
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
                // Email or phone if available?
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

                // Member count if available
                // Text("\(group.members?.count ?? 0) members")
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

// MARK: - Currency Picker

struct CurrencyPickerView: View {
    let currencies: [Currency]
    @Binding var selectedCurrency: Currency
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(currencies.enumerated()), id: \.element.id) { (index, currency) in
                Button {
                    selectedCurrency = currency
                    isPresented = false
                } label: {
                    HStack(spacing: 12) {
                        Text(currency.flag)
                            .font(.system(size: 20))
                        Text(currency.name)
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(currency.code)
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                        if selectedCurrency.id == currency.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                if index < currencies.count - 1 {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Category Picker

struct CategoryPickerView: View {
    let categories: [Category]
    @Binding var selectedCategory: Category?
    @Binding var isPresented: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(categories) { category in
                Button {
                    selectedCategory = category
                    isPresented = false
                } label: {
                    VStack(spacing: 6) {
                        Text(category.icon)
                            .font(.system(size: 28))
                        Text(category.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(
                                selectedCategory?.id == category.id ? category.color : .primary
                            )
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedCategory?.id == category.id
                                            ? category.color : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    )
                }
            }
        }
    }
}

// MARK: - Split Method Chip

struct SplitMethodChip: View {
    let method: QuickActionSplitMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Icon
                Text(method.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? AppColors.accent : AppColors.backgroundSecondary)
                    )

                // Label
                Text(method.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 2)
                    )
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
            HStack(spacing: 14) {
                // Icon
                Text(icon)
                    .font(.system(size: 32))

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Radio button
                Circle()
                    .strokeBorder(
                        isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.5), lineWidth: 2
                    )
                    .background(
                        Circle()
                            .fill(isSelected ? AppColors.accent : Color.clear)
                    )
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .opacity(isSelected ? 1 : 0)
                    )
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}
