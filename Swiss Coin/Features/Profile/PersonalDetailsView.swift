//
//  PersonalDetailsView.swift
//  Swiss Coin
//
//  View for editing user's personal details.
//  All data is persisted locally via CoreData.
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
        Form {
            // Profile Photo Section
            ProfilePhotoSection(viewModel: viewModel)

            // Profile Color Section
            ProfileColorSection(viewModel: viewModel)

            // Personal Info Section
            PersonalInfoSection(viewModel: viewModel)

            // Contact Info Section
            ContactInfoSection(viewModel: viewModel)
        }
        .navigationTitle("Personal Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Button("Save") {
                        viewModel.saveChanges(context: viewContext)
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canSave)
                }
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
            Text("Your personal details have been updated.")
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
        Section {
            HStack {
                Spacer()
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
                                    .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: viewModel.profileColor), lineWidth: 3)
                                    )
                            } else {
                                initialsView
                            }

                            // Camera badge
                            Circle()
                                .fill(AppColors.accent)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12, weight: .semibold))
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
                Spacer()
            }
            .padding(.vertical, Spacing.md)
        }
        .listRowBackground(Color.clear)
    }

    private var initialsView: some View {
        Circle()
            .fill(Color(hex: viewModel.profileColor).opacity(0.3))
            .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
            .overlay(
                Text(viewModel.initials)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Color(hex: viewModel.profileColor))
            )
            .overlay(
                Circle()
                    .stroke(Color(hex: viewModel.profileColor), lineWidth: 3)
            )
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
        Section {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Profile Color")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Spacing.md) {
                    ForEach(colorOptions, id: \.self) { color in
                        Button {
                            HapticManager.selectionChanged()
                            viewModel.profileColor = color
                            viewModel.hasChanges = true
                        } label: {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            viewModel.profileColor == color ? AppColors.textPrimary : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .opacity(viewModel.profileColor == color ? 1 : 0)
                                )
                        }
                    }
                }
            }
        } header: {
            Text("Appearance")
                .font(AppTypography.subheadlineMedium())
        }
    }
}

// MARK: - Personal Info Section

private struct PersonalInfoSection: View {
    @ObservedObject var viewModel: PersonalDetailsViewModel

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Display Name")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                TextField("Display Name", text: $viewModel.displayName)
                    .textContentType(.nickname)
                    .font(AppTypography.body())
                    .onChange(of: viewModel.displayName) { _, _ in
                        viewModel.hasChanges = true
                    }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Full Name (Optional)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                TextField("Full Name", text: $viewModel.fullName)
                    .textContentType(.name)
                    .font(AppTypography.body())
                    .onChange(of: viewModel.fullName) { _, _ in
                        viewModel.hasChanges = true
                    }
            }
        } header: {
            Text("Name")
                .font(AppTypography.subheadlineMedium())
        } footer: {
            Text("Your display name is shown to contacts. Full name is optional and used for formal communications.")
                .font(AppTypography.caption())
        }
    }
}

// MARK: - Contact Info Section

private struct ContactInfoSection: View {
    @ObservedObject var viewModel: PersonalDetailsViewModel

    var body: some View {
        Section {
            // Phone number (read-only)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phone")
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
            .padding(.vertical, Spacing.xs)

            // Email (editable)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Email (Optional)")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)

                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(AppTypography.body())
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
        } header: {
            Text("Contact")
                .font(AppTypography.subheadlineMedium())
        } footer: {
            Text("Phone number cannot be changed here. Email is optional.")
                .font(AppTypography.caption())
        }
    }
}

// MARK: - View Model

class PersonalDetailsViewModel: ObservableObject {
    // Form fields
    @Published var displayName: String = ""
    @Published var fullName: String = ""
    @Published var phoneNumber: String = ""
    @Published var email: String = ""
    @Published var profileColor: String = "#34C759"
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
        guard phoneNumber.count >= 10 else { return phoneNumber }

        let digits = phoneNumber.filter { $0.isNumber }
        if digits.count == 10 {
            let areaCode = digits.prefix(3)
            let middle = digits.dropFirst(3).prefix(3)
            let last = digits.suffix(4)
            return "(\(areaCode)) \(middle)-\(last)"
        } else if digits.count == 11 && digits.first == "1" {
            let withoutCountry = String(digits.dropFirst())
            let areaCode = withoutCountry.prefix(3)
            let middle = withoutCountry.dropFirst(3).prefix(3)
            let last = withoutCountry.suffix(4)
            return "+1 (\(areaCode)) \(middle)-\(last)"
        }
        return phoneNumber
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
        profileColor = currentUser.colorHex ?? "#34C759"
        phoneNumber = currentUser.phoneNumber ?? ""

        // Load photo from CoreData
        if let photoData = currentUser.photoData, let image = UIImage(data: photoData) {
            selectedImage = image
        }

        // Load email from UserDefaults (lightweight local store)
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
