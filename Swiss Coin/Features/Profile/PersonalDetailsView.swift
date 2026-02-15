//
//  PersonalDetailsView.swift
//  Swiss Coin
//
//  Minimal personal details editor with card-based design.
//

import Combine
import CoreData
import PhotosUI
import SwiftUI

struct PersonalDetailsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PersonalDetailsViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case displayName, fullName, email
    }

    var body: some View {
        ZStack {
            AppColors.backgroundSecondary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    avatarSection
                    nameSection
                    contactSection
                    memberSection
                    saveButton
                }
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.section)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Personal Details")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .font(AppTypography.labelLarge())
            }
        }
        .onAppear {
            viewModel.loadCurrentUserData(context: viewContext)
        }
        .alert("Saved", isPresented: $viewModel.showingSaveConfirmation) {
            Button("OK", role: .cancel) {
                HapticManager.success()
                dismiss()
            }
        } message: {
            Text("Your profile has been updated.")
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {
                HapticManager.tap()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $viewModel.showingImagePicker) {
            ImagePicker(
                selectedImage: $viewModel.selectedImage,
                onImageSelected: { image in
                    viewModel.didSelectImage(image)
                }
            )
        }
        .confirmationDialog(
            "Profile Photo",
            isPresented: $viewModel.showingPhotoOptions,
            titleVisibility: .visible
        ) {
            Button("Choose from Library") {
                HapticManager.tap()
                viewModel.showingImagePicker = true
            }

            if viewModel.hasExistingPhoto {
                Button("Remove Photo", role: .destructive) {
                    HapticManager.warning()
                    viewModel.deletePhoto()
                }
            }

            Button("Cancel", role: .cancel) {
                HapticManager.tap()
            }
        }
        .interactiveDismissDisabled(viewModel.hasChanges)
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: Spacing.md) {
            Button {
                HapticManager.tap()
                viewModel.showingPhotoOptions = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    if let image = viewModel.selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: viewModel.profileColor).opacity(0.4), lineWidth: 2.5)
                            )
                    } else {
                        Circle()
                            .fill(Color(hex: viewModel.profileColor).opacity(0.12))
                            .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                            .overlay(
                                Text(viewModel.initials)
                                    .font(AppTypography.displayHero())
                                    .foregroundColor(Color(hex: viewModel.profileColor))
                            )
                    }

                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: IconSize.category, height: IconSize.category)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: IconSize.xs, weight: .semibold))
                                .foregroundColor(AppColors.onAccent)
                        )
                        .shadow(color: AppColors.shadow, radius: 4, x: 0, y: 2)
                        .offset(x: -Spacing.xxs, y: -Spacing.xxs)
                }
            }
            .buttonStyle(.plain)

            Text("Tap to change photo")
                .font(AppTypography.bodySmall())
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("NAME")

            VStack(spacing: Spacing.lg) {
                // Display Name
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("Display Name")
                            .font(AppTypography.labelDefault())
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        if viewModel.displayName.isEmpty {
                            Text("Required")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.negative)
                        }
                    }

                    TextField("How you appear to others", text: $viewModel.displayName)
                        .textContentType(.nickname)
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(AppColors.textPrimary)
                        .focused($focusedField, equals: .displayName)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(AppColors.backgroundSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .strokeBorder(
                                    focusedField == .displayName ? AppColors.borderFocus : AppColors.border,
                                    lineWidth: focusedField == .displayName ? 1.5 : 0.5
                                )
                        )
                        .limitTextLength(to: ValidationLimits.maxDisplayNameLength, text: $viewModel.displayName)
                        .onChange(of: viewModel.displayName) { _, _ in
                            viewModel.hasChanges = true
                        }

                    HStack {
                        Spacer()
                        Text("\(viewModel.displayName.count)/\(ValidationLimits.maxDisplayNameLength)")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                // Full Name
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Full Name")
                        .font(AppTypography.labelDefault())
                        .foregroundColor(AppColors.textSecondary)

                    TextField("Optional", text: $viewModel.fullName)
                        .textContentType(.name)
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(AppColors.textPrimary)
                        .focused($focusedField, equals: .fullName)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(AppColors.backgroundSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .strokeBorder(
                                    focusedField == .fullName ? AppColors.borderFocus : AppColors.border,
                                    lineWidth: focusedField == .fullName ? 1.5 : 0.5
                                )
                        )
                        .limitTextLength(to: ValidationLimits.maxNameLength, text: $viewModel.fullName)
                        .onChange(of: viewModel.fullName) { _, _ in
                            viewModel.hasChanges = true
                        }
                }
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
            )
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Contact Section

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("CONTACT")

            VStack(spacing: Spacing.lg) {
                // Phone (read-only)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Text("Phone Number")
                            .font(AppTypography.labelDefault())
                            .foregroundColor(AppColors.textSecondary)

                        Image(systemName: "lock.fill")
                            .font(.system(size: IconSize.xs))
                            .foregroundColor(AppColors.textTertiary)
                    }

                    HStack {
                        Text(viewModel.phoneNumber.isEmpty ? "Not set" : viewModel.formattedPhoneNumber)
                            .font(AppTypography.bodyLarge())
                            .foregroundColor(viewModel.phoneNumber.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(AppColors.backgroundTertiary.opacity(0.5))
                    )
                }

                // Email
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Email")
                        .font(AppTypography.labelDefault())
                        .foregroundColor(AppColors.textSecondary)

                    TextField("Optional", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(AppColors.textPrimary)
                        .focused($focusedField, equals: .email)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(AppColors.backgroundSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .strokeBorder(
                                    !viewModel.emailError.isEmpty
                                        ? AppColors.negative
                                        : focusedField == .email ? AppColors.borderFocus : AppColors.border,
                                    lineWidth: (focusedField == .email || !viewModel.emailError.isEmpty) ? 1.5 : 0.5
                                )
                        )
                        .limitTextLength(to: ValidationLimits.maxEmailLength, text: $viewModel.email)
                        .onChange(of: viewModel.email) { _, newValue in
                            viewModel.hasChanges = true
                            viewModel.validateEmail(newValue)
                        }

                    if !viewModel.emailError.isEmpty {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: IconSize.xs))
                            Text(viewModel.emailError)
                                .font(AppTypography.caption())
                        }
                        .foregroundColor(AppColors.negative)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(AppAnimation.fast, value: viewModel.emailError.isEmpty)
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
            )
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Member Section

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("ACCOUNT")

            HStack(spacing: Spacing.md) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: IconSize.md))
                    .foregroundColor(AppColors.positive)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Member since")
                        .font(AppTypography.labelDefault())
                        .foregroundColor(AppColors.textSecondary)

                    Text(viewModel.memberSinceText)
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .fill(AppColors.cardBackground)
            )
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            focusedField = nil
            viewModel.saveChanges(context: viewContext)
        } label: {
            HStack(spacing: Spacing.sm) {
                if viewModel.isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(AppColors.onAccent)
                } else {
                    Text("Save Changes")
                        .font(AppTypography.buttonLarge())
                }
            }
            .foregroundColor(AppColors.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .fill(viewModel.canSave ? AppColors.accent : AppColors.disabled)
            )
        }
        .disabled(!viewModel.canSave)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .animation(AppAnimation.fast, value: viewModel.canSave)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.caption())
            .foregroundColor(AppColors.textTertiary)
            .tracking(AppTypography.Tracking.caption)
            .padding(.horizontal, Spacing.lg + Spacing.xs)
    }
}

// MARK: - View Model

@MainActor
class PersonalDetailsViewModel: ObservableObject {
    // Form fields
    @Published var displayName: String = ""
    @Published var fullName: String = ""
    @Published var phoneNumber: String = ""
    @Published var email: String = ""
    @Published var profileColor: String = AppColors.defaultAvatarColorHex
    @Published var selectedImage: UIImage?

    // UI state
    @Published var showingImagePicker = false
    @Published var showingPhotoOptions = false
    @Published var showingSaveConfirmation = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var emailError = ""
    @Published var isSaving = false
    @Published var hasChanges = false

    // Account info
    private var accountCreatedDate: Date?

    var initials: String {
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

    var formattedPhoneNumber: String {
        let digits = phoneNumber.filter { $0.isNumber }
        guard digits.count >= 7 else { return phoneNumber }

        if digits.hasPrefix("41") && digits.count == 11 {
            let area = String(digits.dropFirst(2).prefix(2))
            let rest = String(digits.dropFirst(4))
            let p1 = String(rest.prefix(3))
            let p2 = String(rest.dropFirst(3).prefix(2))
            let p3 = String(rest.dropFirst(5))
            return "+41 \(area) \(p1) \(p2) \(p3)"
        }

        if digits.hasPrefix("0") && digits.count == 10 {
            let area = String(digits.prefix(3))
            let rest = String(digits.dropFirst(3))
            let p1 = String(rest.prefix(3))
            let p2 = String(rest.dropFirst(3).prefix(2))
            let p3 = String(rest.dropFirst(5))
            return "\(area) \(p1) \(p2) \(p3)"
        }

        if digits.hasPrefix("1") && digits.count == 11 {
            let body = String(digits.dropFirst())
            let area = String(body.prefix(3))
            let mid = String(body.dropFirst(3).prefix(3))
            let last = String(body.suffix(4))
            return "+1 (\(area)) \(mid)-\(last)"
        }

        if digits.count == 10 && !digits.hasPrefix("0") && !digits.hasPrefix("44") && !digits.hasPrefix("91") {
            let area = String(digits.prefix(3))
            let mid = String(digits.dropFirst(3).prefix(3))
            let last = String(digits.suffix(4))
            return "(\(area)) \(mid)-\(last)"
        }

        if digits.hasPrefix("44") && digits.count == 12 {
            let body = String(digits.dropFirst(2))
            let p1 = String(body.prefix(4))
            let p2 = String(body.dropFirst(4))
            return "+44 \(p1) \(p2)"
        }

        if digits.hasPrefix("91") && digits.count == 12 {
            let body = String(digits.dropFirst(2))
            let p1 = String(body.prefix(5))
            let p2 = String(body.dropFirst(5))
            return "+91 \(p1) \(p2)"
        }

        let hasPlus = phoneNumber.trimmingCharacters(in: .whitespaces).hasPrefix("+")
        var result = ""
        for (i, char) in digits.enumerated() {
            if i > 0 && i % 4 == 0 {
                result += " "
            }
            result.append(char)
        }
        return hasPlus ? "+\(result)" : result
    }

    var canSave: Bool {
        !displayName.isEmpty && emailError.isEmpty && hasChanges
    }

    var hasExistingPhoto: Bool {
        selectedImage != nil
    }

    var memberSinceText: String {
        if let date = accountCreatedDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }

        if let storedDateString = UserDefaults.standard.string(forKey: "account_created_date"),
           let storedDate = ISO8601DateFormatter().date(from: storedDateString)
        {
            return {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: storedDate)
            }()
        }

        // First time - store current date
        let now = Date()
        UserDefaults.standard.set(ISO8601DateFormatter().string(from: now), forKey: "account_created_date")
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: now)
    }

    // MARK: - Load Data

    func loadCurrentUserData(context: NSManagedObjectContext) {
        let currentUser = CurrentUser.getOrCreate(in: context)
        displayName = currentUser.name ?? "You"
        profileColor = currentUser.colorHex ?? AppColors.defaultAvatarColorHex
        phoneNumber = currentUser.phoneNumber ?? ""

        if let photoData = currentUser.photoData, let image = UIImage(data: photoData) {
            selectedImage = image
        }

        email = UserDefaults.standard.string(forKey: "user_email") ?? ""
        fullName = UserDefaults.standard.string(forKey: "user_full_name") ?? ""

        if let storedDateString = UserDefaults.standard.string(forKey: "account_created_date"),
           let storedDate = ISO8601DateFormatter().date(from: storedDateString)
        {
            accountCreatedDate = storedDate
        }
    }

    // MARK: - Validation

    func validateEmail(_ email: String) {
        if email.isEmpty {
            emailError = ""
            return
        }

        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        if email.range(of: emailRegex, options: .regularExpression) == nil {
            emailError = "Please enter a valid email address"
        } else {
            emailError = ""
        }
    }

    // MARK: - Save Changes

    func saveChanges(context: NSManagedObjectContext) {
        guard canSave else { return }

        isSaving = true
        HapticManager.save()

        do {
            let currentUser = CurrentUser.getOrCreate(in: context)
            currentUser.name = displayName
            currentUser.colorHex = profileColor

            if let image = selectedImage {
                currentUser.photoData = image.jpegData(compressionQuality: 0.8)
            } else {
                currentUser.photoData = nil
            }

            try context.save()

            UserDefaults.standard.set(email, forKey: "user_email")
            UserDefaults.standard.set(fullName, forKey: "user_full_name")

            CurrentUser.updateProfile(
                name: displayName,
                colorHex: profileColor,
                phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                in: context
            )

            isSaving = false
            hasChanges = false
            HapticManager.success()
            showingSaveConfirmation = true
        } catch {
            isSaving = false
            HapticManager.error()
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Photo Management

    func didSelectImage(_ image: UIImage) {
        let maxDimension: CGFloat = 800
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)

        if ratio < 1 {
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            selectedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            selectedImage = image
        }

        if let data = selectedImage?.jpegData(compressionQuality: 0.8), data.count > 5 * 1024 * 1024 {
            HapticManager.error()
            errorMessage = "Image is too large. Maximum size is 5MB."
            showingError = true
            selectedImage = nil
            return
        }

        hasChanges = true
        HapticManager.success()
    }

    func deletePhoto() {
        selectedImage = nil
        hasChanges = true
        HapticManager.success()
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onImageSelected: ((UIImage) -> Void)?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                DispatchQueue.main.async {
                    if let image = image as? UIImage {
                        self?.parent.onImageSelected?(image)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PersonalDetailsView()
    }
}
