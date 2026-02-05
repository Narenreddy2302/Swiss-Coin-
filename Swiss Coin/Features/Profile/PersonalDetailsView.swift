//
//  PersonalDetailsView.swift
//  Swiss Coin
//
//  Simplified personal details editor with card-based design.
//

import Combine
import CoreData
import PhotosUI
import SwiftUI

struct PersonalDetailsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PersonalDetailsViewModel()

    var body: some View {
        ZStack {
            AppColors.backgroundSecondary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // Profile Photo Section
                    ProfilePhotoSection(viewModel: viewModel)

                    // Name Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Your Name")
                            .font(AppTypography.headline())
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.sm)

                        VStack(spacing: 0) {
                            // Display Name
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Display Name")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textSecondary)

                                TextField("How you appear to others", text: $viewModel.displayName)
                                    .textContentType(.nickname)
                                    .font(AppTypography.body())
                                    .foregroundColor(AppColors.textPrimary)
                                    .limitTextLength(to: ValidationLimits.maxDisplayNameLength, text: $viewModel.displayName)
                                    .onChange(of: viewModel.displayName) { _, _ in
                                        viewModel.hasChanges = true
                                    }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)

                            Divider()
                                .padding(.leading, Spacing.lg)

                            // Full Name (Optional)
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Full Name (Optional)")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textSecondary)

                                TextField("Your complete name", text: $viewModel.fullName)
                                    .textContentType(.name)
                                    .font(AppTypography.body())
                                    .foregroundColor(AppColors.textPrimary)
                                    .limitTextLength(to: ValidationLimits.maxNameLength, text: $viewModel.fullName)
                                    .onChange(of: viewModel.fullName) { _, _ in
                                        viewModel.hasChanges = true
                                    }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                    }

                    // Profile Color Section
                    ProfileColorSection(viewModel: viewModel)

                    // Contact Info Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Contact Information")
                            .font(AppTypography.headline())
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.sm)

                        VStack(spacing: 0) {
                            // Phone (Read-only)
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text("Phone Number")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textSecondary)

                                    Text(viewModel.phoneNumber.isEmpty ? "Not set" : viewModel.formattedPhoneNumber)
                                        .font(AppTypography.body())
                                        .foregroundColor(AppColors.textPrimary)
                                }

                                Spacer()

                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)

                            Divider()
                                .padding(.leading, Spacing.lg)

                            // Email (Editable)
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Email (Optional)")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textSecondary)

                                TextField("your@email.com", text: $viewModel.email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(AppTypography.body())
                                    .foregroundColor(AppColors.textPrimary)
                                    .limitTextLength(to: ValidationLimits.maxEmailLength, text: $viewModel.email)
                                    .onChange(of: viewModel.email) { _, newValue in
                                        viewModel.hasChanges = true
                                        viewModel.validateEmail(newValue)
                                    }

                                if !viewModel.emailError.isEmpty {
                                    Text(viewModel.emailError)
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.negative)
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                    }

                    // Save Button
                    Button {
                        viewModel.saveChanges(context: viewContext)
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Text("Save Changes")
                                .font(AppTypography.subheadlineMedium())
                        }
                    }
                    .foregroundColor(AppColors.buttonForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: ButtonHeight.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(viewModel.canSave ? AppColors.buttonBackground : AppColors.disabled)
                    )
                    .disabled(!viewModel.canSave)
                    .padding(.horizontal)
                    .padding(.top, Spacing.lg)
                }
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.section)
            }
        }
        .navigationTitle("Personal Details")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadCurrentUserData(context: viewContext)
        }
        .alert("Saved Successfully", isPresented: $viewModel.showingSaveConfirmation) {
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
    }
}

// MARK: - Profile Photo Section

private struct ProfilePhotoSection: View {
    @ObservedObject var viewModel: PersonalDetailsViewModel

    var body: some View {
        VStack(spacing: Spacing.md) {
            Button {
                HapticManager.tap()
                viewModel.showingPhotoOptions = true
            } label: {
                ZStack {
                    if let image = viewModel.selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: viewModel.profileColor), lineWidth: 3)
                            )
                    } else {
                        Circle()
                            .fill(Color(hex: viewModel.profileColor).opacity(0.2))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(viewModel.initials)
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundColor(Color(hex: viewModel.profileColor))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: viewModel.profileColor).opacity(0.3), lineWidth: 3)
                            )
                    }

                    // Camera badge
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 35, y: 35)
                }
            }
            .buttonStyle(.plain)

            Text("Tap to change photo")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }
}

// MARK: - Profile Color Section

private struct ProfileColorSection: View {
    @ObservedObject var viewModel: PersonalDetailsViewModel

    private let colorOptions = [
        "#34C759", "#007AFF", "#FF9500", "#FF2D55",
        "#AF52DE", "#5856D6", "#00C7BE", "#FF3B30",
        "#32ADE6", "#BF5AF2", "#FFD60A", "#64D2FF"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Profile Color")
                .font(AppTypography.headline())
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, Spacing.sm)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Spacing.md) {
                ForEach(colorOptions, id: \.self) { color in
                    Button {
                        HapticManager.selectionChanged()
                        viewModel.profileColor = color
                        viewModel.hasChanges = true
                    } label: {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(
                                        viewModel.profileColor == color ? AppColors.textPrimary : Color.clear,
                                        lineWidth: 3
                                    )
                            )
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .opacity(viewModel.profileColor == color ? 1 : 0)
                            )
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
            )
            .padding(.horizontal)
        }
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

    // Original values for change detection
    private var originalDisplayName = ""
    private var originalFullName = ""
    private var originalEmail = ""
    private var originalColor = ""

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

        // Swiss: +41 XX XXX XX XX (11 digits with country code)
        if digits.hasPrefix("41") && digits.count == 11 {
            let area = String(digits.dropFirst(2).prefix(2))
            let rest = String(digits.dropFirst(4))
            let p1 = String(rest.prefix(3))
            let p2 = String(rest.dropFirst(3).prefix(2))
            let p3 = String(rest.dropFirst(5))
            return "+41 \(area) \(p1) \(p2) \(p3)"
        }

        // Swiss local: 0XX XXX XX XX (10 digits starting with 0)
        if digits.hasPrefix("0") && digits.count == 10 {
            let area = String(digits.prefix(3))
            let rest = String(digits.dropFirst(3))
            let p1 = String(rest.prefix(3))
            let p2 = String(rest.dropFirst(3).prefix(2))
            let p3 = String(rest.dropFirst(5))
            return "\(area) \(p1) \(p2) \(p3)"
        }

        // US/Canada: +1 (XXX) XXX-XXXX (11 digits with country code)
        if digits.hasPrefix("1") && digits.count == 11 {
            let body = String(digits.dropFirst())
            let area = String(body.prefix(3))
            let mid = String(body.dropFirst(3).prefix(3))
            let last = String(body.suffix(4))
            return "+1 (\(area)) \(mid)-\(last)"
        }

        // US local: (XXX) XXX-XXXX (10 digits)
        if digits.count == 10 && !digits.hasPrefix("0") && !digits.hasPrefix("44") && !digits.hasPrefix("91") {
            let area = String(digits.prefix(3))
            let mid = String(digits.dropFirst(3).prefix(3))
            let last = String(digits.suffix(4))
            return "(\(area)) \(mid)-\(last)"
        }

        // UK: +44 XXXX XXXXXX (12 digits with country code)
        if digits.hasPrefix("44") && digits.count == 12 {
            let body = String(digits.dropFirst(2))
            let p1 = String(body.prefix(4))
            let p2 = String(body.dropFirst(4))
            return "+44 \(p1) \(p2)"
        }

        // India: +91 XXXXX XXXXX (12 digits with country code)
        if digits.hasPrefix("91") && digits.count == 12 {
            let body = String(digits.dropFirst(2))
            let p1 = String(body.prefix(5))
            let p2 = String(body.dropFirst(5))
            return "+91 \(p1) \(p2)"
        }

        // Generic international
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

    // MARK: - Load Data

    func loadCurrentUserData(context: NSManagedObjectContext) {
        let currentUser = CurrentUser.getOrCreate(in: context)
        displayName = currentUser.name ?? "You"
        profileColor = currentUser.colorHex ?? AppColors.defaultAvatarColorHex
        phoneNumber = currentUser.phoneNumber ?? ""

        // Load photo from CoreData
        if let photoData = currentUser.photoData, let image = UIImage(data: photoData) {
            selectedImage = image
        }

        // Load email from UserDefaults
        email = UserDefaults.standard.string(forKey: "user_email") ?? ""
        fullName = UserDefaults.standard.string(forKey: "user_full_name") ?? ""

        // Store original values
        originalDisplayName = displayName
        originalFullName = fullName
        originalEmail = email
        originalColor = profileColor
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
            // Update CoreData
            let currentUser = CurrentUser.getOrCreate(in: context)
            currentUser.name = displayName
            currentUser.colorHex = profileColor

            // Save photo data
            if let image = selectedImage {
                currentUser.photoData = image.jpegData(compressionQuality: 0.8)
            } else {
                currentUser.photoData = nil
            }

            try context.save()

            // Save additional fields to UserDefaults
            UserDefaults.standard.set(email, forKey: "user_email")
            UserDefaults.standard.set(fullName, forKey: "user_full_name")

            // Update CurrentUser profile
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
        // Resize if needed
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

        // Check file size (max 5MB)
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
