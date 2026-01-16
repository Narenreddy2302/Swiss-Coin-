//
//  PersonalDetailsView.swift
//  Swiss Coin
//
//  View for editing user's personal details.
//

import CoreData
import SwiftUI

struct PersonalDetailsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var displayName: String = ""
    @State private var fullName: String = ""
    @State private var phoneNumber: String = ""
    @State private var email: String = ""
    @State private var profileColor: String = "#34C759"

    @State private var showingImagePicker = false
    @State private var profileImage: UIImage?
    @State private var showingSaveConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    // Predefined color options
    private let colorOptions = [
        "#34C759", "#007AFF", "#FF9500", "#FF2D55",
        "#AF52DE", "#5856D6", "#00C7BE", "#FF3B30"
    ]

    var body: some View {
        Form {
            // Profile Photo Section
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: Spacing.md) {
                        Button {
                            HapticManager.tap()
                            showingImagePicker = true
                        } label: {
                            if let image = profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: profileColor), lineWidth: 3)
                                    )
                            } else {
                                Circle()
                                    .fill(Color(hex: profileColor).opacity(0.3))
                                    .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                                    .overlay(
                                        Text(initials)
                                            .font(.system(size: 32, weight: .semibold))
                                            .foregroundColor(Color(hex: profileColor))
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: profileColor), lineWidth: 3)
                                    )
                            }
                        }

                        Text("Tap to change photo")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, Spacing.md)
            }
            .listRowBackground(Color.clear)

            // Profile Color Section
            Section {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Profile Color")
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(AppColors.textSecondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Spacing.md) {
                        ForEach(colorOptions, id: \.self) { color in
                            Button {
                                HapticManager.selectionChanged()
                                profileColor = color
                            } label: {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(profileColor == color ? AppColors.textPrimary : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                }
            } header: {
                Text("Appearance")
                    .font(AppTypography.subheadlineMedium())
            }

            // Personal Info Section
            Section {
                TextField("Display Name", text: $displayName)
                    .textContentType(.nickname)

                TextField("Full Name (Optional)", text: $fullName)
                    .textContentType(.name)
            } header: {
                Text("Name")
                    .font(AppTypography.subheadlineMedium())
            } footer: {
                Text("Your display name is shown to contacts. Full name is optional.")
                    .font(AppTypography.caption())
            }

            // Contact Info Section
            Section {
                HStack {
                    Text("Phone")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(phoneNumber.isEmpty ? "Not set" : phoneNumber)
                        .foregroundColor(AppColors.textSecondary)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }

                TextField("Email (Optional)", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            } header: {
                Text("Contact")
                    .font(AppTypography.subheadlineMedium())
            } footer: {
                Text("Phone number is used for login and cannot be changed here.")
                    .font(AppTypography.caption())
            }
        }
        .navigationTitle("Personal Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .fontWeight(.semibold)
                .disabled(isSaving || displayName.isEmpty)
            }
        }
        .onAppear {
            loadCurrentUserData()
        }
        .alert("Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) {
                HapticManager.success()
                dismiss()
            }
        } message: {
            Text("Your personal details have been updated.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                HapticManager.tap()
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Computed Properties

    private var initials: String {
        if displayName.isEmpty {
            return "ME"
        }
        let words = displayName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else {
            return String(displayName.prefix(2)).uppercased()
        }
    }

    // MARK: - Functions

    private func loadCurrentUserData() {
        if let currentUser = CurrentUser.fetch(from: viewContext) {
            displayName = currentUser.name ?? "You"
            profileColor = currentUser.colorHex ?? "#34C759"
            // Note: In production, also load from Supabase profiles table
        }
    }

    private func saveChanges() {
        guard !displayName.isEmpty else {
            HapticManager.error()
            errorMessage = "Display name cannot be empty"
            showingError = true
            return
        }

        isSaving = true
        HapticManager.save()

        // Update CoreData
        let currentUser = CurrentUser.getOrCreate(in: viewContext)
        currentUser.name = displayName
        currentUser.colorHex = profileColor

        do {
            try viewContext.save()
            showingSaveConfirmation = true
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showingError = true
        }

        isSaving = false
    }
}
