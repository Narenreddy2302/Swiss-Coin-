//
//  PersonalDetailsView.swift
//  Swiss Coin
//
//  Production-ready view for editing user's personal details.
//  Integrates with both local CoreData and remote Supabase.
//

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
                        Task {
                            await viewModel.saveChanges(context: viewContext)
                        }
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
                    Task {
                        await viewModel.uploadPhoto(image)
                    }
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
                    Task {
                        await viewModel.deletePhoto()
                    }
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
                            if viewModel.isUploadingPhoto {
                                Circle()
                                    .fill(Color(hex: viewModel.profileColor).opacity(0.3))
                                    .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: viewModel.profileColor)))
                                    )
                            } else if let image = viewModel.selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: viewModel.profileColor), lineWidth: 3)
                                    )
                            } else if let avatarUrl = viewModel.avatarUrl, !avatarUrl.isEmpty {
                                AsyncImage(url: URL(string: avatarUrl)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                                            .clipShape(Circle())
                                    case .failure:
                                        initialsView
                                    case .empty:
                                        Circle()
                                            .fill(Color(hex: viewModel.profileColor).opacity(0.3))
                                            .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                                            .overlay(
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle())
                                            )
                                    @unknown default:
                                        initialsView
                                    }
                                }
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
                HStack(spacing: Spacing.xs) {
                    if viewModel.phoneVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.positive)
                    }
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.vertical, Spacing.xs)

            // Email (editable)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("Email (Optional)")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)

                    if viewModel.emailVerified && !viewModel.email.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.positive)
                            Text("Verified")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.positive)
                        }
                    }
                }

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
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Phone number is used for login and cannot be changed here.")
                if !viewModel.email.isEmpty && !viewModel.emailVerified {
                    Text("Email will require verification after saving.")
                        .foregroundColor(AppColors.warning)
                }
            }
            .font(AppTypography.caption())
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
    @Published var phoneVerified: Bool = false
    @Published var email: String = ""
    @Published var emailVerified: Bool = false
    @Published var profileColor: String = "#34C759"
    @Published var avatarUrl: String?
    @Published var selectedImage: UIImage?

    // UI state
    @Published var showingImagePicker = false
    @Published var showingPhotoOptions = false
    @Published var showingSaveConfirmation = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var emailError = ""
    @Published var isSaving = false
    @Published var isUploadingPhoto = false
    @Published var hasChanges = false

    // Original values for change detection
    private var originalDisplayName = ""
    private var originalFullName = ""
    private var originalEmail = ""
    private var originalColor = ""

    private let supabase = SupabaseManager.shared

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
        // Format phone number for display (e.g., +1 (555) 123-4567)
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
        selectedImage != nil || (avatarUrl != nil && !avatarUrl!.isEmpty)
    }

    // MARK: - Load Data

    func loadCurrentUserData(context: NSManagedObjectContext) {
        // Load from CoreData first
        if let currentUser = CurrentUser.fetch(from: context) {
            displayName = currentUser.name ?? "You"
            profileColor = currentUser.colorHex ?? "#34C759"
        }

        // Try to load from Supabase if authenticated
        if CurrentUser.isAuthenticated {
            Task {
                await loadFromSupabase()
            }
        }

        // Store original values
        originalDisplayName = displayName
        originalFullName = fullName
        originalEmail = email
        originalColor = profileColor
    }

    private func loadFromSupabase() async {
        do {
            let profile = try await supabase.getProfileDetails()

            await MainActor.run {
                if let name = profile.displayName, !name.isEmpty {
                    self.displayName = name
                    self.originalDisplayName = name
                }
                if let full = profile.fullName {
                    self.fullName = full
                    self.originalFullName = full
                }
                if let phone = profile.phoneNumber {
                    self.phoneNumber = phone
                }
                self.phoneVerified = profile.phoneVerified
                if let mail = profile.email {
                    self.email = mail
                    self.originalEmail = mail
                }
                self.emailVerified = profile.emailVerified
                if let color = profile.colorHex {
                    self.profileColor = color
                    self.originalColor = color
                }
                self.avatarUrl = profile.avatarUrl
                self.hasChanges = false
            }
        } catch {
            print("Failed to load profile from Supabase: \(error.localizedDescription)")
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

    func saveChanges(context: NSManagedObjectContext) async {
        guard canSave else { return }

        isSaving = true
        HapticManager.save()

        do {
            // Update CoreData
            let currentUser = CurrentUser.getOrCreate(in: context)
            currentUser.name = displayName
            currentUser.colorHex = profileColor
            try context.save()

            // Update Supabase if authenticated
            if CurrentUser.isAuthenticated {
                var update = ProfileDetailsUpdate()

                if displayName != originalDisplayName {
                    update.displayName = displayName
                }
                if fullName != originalFullName {
                    update.fullName = fullName.isEmpty ? nil : fullName
                }
                if email != originalEmail {
                    update.email = email.isEmpty ? nil : email
                }
                if profileColor != originalColor {
                    update.colorHex = profileColor
                }

                _ = try await supabase.updateProfileDetails(update)
            }

            // Update CurrentUserManager
            try await CurrentUserManager.shared.updateDisplayName(displayName)
            try await CurrentUserManager.shared.updateColor(profileColor)

            await MainActor.run {
                self.isSaving = false
                self.hasChanges = false
                HapticManager.success()
                self.showingSaveConfirmation = true
            }
        } catch {
            await MainActor.run {
                self.isSaving = false
                HapticManager.error()
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }

    // MARK: - Photo Management

    func uploadPhoto(_ image: UIImage) async {
        isUploadingPhoto = true

        do {
            // Compress image
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw SupabaseError.networkError("Failed to process image")
            }

            // Check file size (max 5MB)
            if imageData.count > 5 * 1024 * 1024 {
                throw SupabaseError.networkError("Image is too large. Maximum size is 5MB.")
            }

            // Generate filename
            let filename = "avatar_\(Date().timeIntervalSince1970).jpg"

            // Upload to Supabase
            let newAvatarUrl = try await supabase.uploadProfilePhoto(imageData: imageData, filename: filename)

            await MainActor.run {
                self.selectedImage = image
                self.avatarUrl = newAvatarUrl
                self.isUploadingPhoto = false
                self.hasChanges = true
                HapticManager.success()
            }
        } catch {
            await MainActor.run {
                self.isUploadingPhoto = false
                HapticManager.error()
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }

    func deletePhoto() async {
        isUploadingPhoto = true

        do {
            try await supabase.deleteProfilePhoto()

            await MainActor.run {
                self.selectedImage = nil
                self.avatarUrl = nil
                self.isUploadingPhoto = false
                self.hasChanges = true
                HapticManager.success()
            }
        } catch {
            await MainActor.run {
                self.isUploadingPhoto = false
                HapticManager.error()
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
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

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                DispatchQueue.main.async {
                    if let image = image as? UIImage {
                        // Resize image to reasonable dimensions
                        let resizedImage = self?.resizeImage(image, maxDimension: 800) ?? image
                        self?.parent.selectedImage = resizedImage
                        self?.parent.onImageSelected?(resizedImage)
                    }
                }
            }
        }

        private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
            let size = image.size
            let ratio = min(maxDimension / size.width, maxDimension / size.height)

            if ratio >= 1 { return image }

            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            let renderer = UIGraphicsImageRenderer(size: newSize)

            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
    }
}

#Preview {
    NavigationStack {
        PersonalDetailsView()
    }
}
