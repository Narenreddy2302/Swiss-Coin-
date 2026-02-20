//
//  PersonalDetailsView.swift
//  Swiss Coin
//
//  Native iOS Settings-style personal details editor.
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
    @State private var showingDiscardAlert = false

    private enum Field: Hashable {
        case displayName, fullName, phone, email
    }

    var body: some View {
        Form {
            avatarSection
            nameSection
            contactSection
            memberSection
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Personal Details")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    HapticManager.tap()
                    if viewModel.hasChanges {
                        showingDiscardAlert = true
                    } else {
                        dismiss()
                    }
                }
                .font(AppTypography.bodyLarge())
            }

            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button("Done") {
                        HapticManager.tap()
                        focusedField = nil
                        if viewModel.canSave {
                            viewModel.saveChanges(context: viewContext)
                        } else {
                            dismiss()
                        }
                    }
                    .font(AppTypography.headingMedium())
                    .disabled(viewModel.hasChanges && !viewModel.canSave)
                }
            }

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
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
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
        .confirmationDialog(
            "You have unsaved changes.",
            isPresented: $showingDiscardAlert,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                HapticManager.warning()
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {
                HapticManager.tap()
            }
        }
        .interactiveDismissDisabled(viewModel.hasChanges)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        Section {
            EmptyView()
        } header: {
            VStack(spacing: Spacing.md) {
                Button {
                    HapticManager.tap()
                    viewModel.showingPhotoOptions = true
                } label: {
                    if let image = viewModel.selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: AvatarSize.xxl, height: AvatarSize.xxl)
                            .clipShape(Circle())
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
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.tap()
                    viewModel.showingPhotoOptions = true
                } label: {
                    Text(viewModel.hasExistingPhoto ? "Edit Photo" : "Add Photo")
                        .font(AppTypography.bodyDefault())
                        .foregroundColor(AppColors.accent)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .textCase(nil)
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        Section {
            TextField("Display Name", text: $viewModel.displayName)
                .textContentType(.nickname)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .displayName)
                .limitTextLength(to: ValidationLimits.maxDisplayNameLength, text: $viewModel.displayName)
                .onChange(of: viewModel.displayName) { _, _ in
                    viewModel.hasChanges = true
                }

            TextField("Full Name", text: $viewModel.fullName)
                .textContentType(.name)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .fullName)
                .limitTextLength(to: ValidationLimits.maxNameLength, text: $viewModel.fullName)
                .onChange(of: viewModel.fullName) { _, _ in
                    viewModel.hasChanges = true
                }
        } header: {
            Text("Name")
        } footer: {
            if viewModel.displayName.isEmpty {
                Text("Display name is required.")
                    .foregroundColor(AppColors.negative)
            }
        }
    }

    // MARK: - Contact Section

    private var contactSection: some View {
        Section {
            TextField("Phone Number", text: $viewModel.phoneNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .phone)
                .limitTextLength(to: ValidationLimits.maxPhoneLength, text: $viewModel.phoneNumber)
                .onChange(of: viewModel.phoneNumber) { _, newValue in
                    let filtered = newValue.filter { char in
                        char.isNumber || char == "+" || char == " " || char == "-" || char == "(" || char == ")"
                    }
                    if filtered != newValue {
                        viewModel.phoneNumber = filtered
                    }
                    viewModel.hasChanges = true
                    viewModel.validatePhone(filtered)
                }

            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .email)
                .limitTextLength(to: ValidationLimits.maxEmailLength, text: $viewModel.email)
                .onChange(of: viewModel.email) { _, newValue in
                    viewModel.hasChanges = true
                    viewModel.validateEmail(newValue)
                }
        } header: {
            Text("Contact")
        } footer: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if !viewModel.phoneError.isEmpty {
                    Text(viewModel.phoneError)
                        .foregroundColor(AppColors.negative)
                }
                if !viewModel.emailError.isEmpty {
                    Text(viewModel.emailError)
                        .foregroundColor(AppColors.negative)
                }
            }
        }
    }

    // MARK: - Member Section

    private var memberSection: some View {
        Section {
            LabeledContent("Member Since") {
                Text(viewModel.memberSinceText)
                    .foregroundColor(AppColors.textSecondary)
            }
        } header: {
            Text("Account")
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
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var emailError = ""
    @Published var phoneError = ""
    @Published var isSaving = false
    @Published var hasChanges = false
    @Published var didSave = false

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
        !displayName.isEmpty && emailError.isEmpty && phoneError.isEmpty && hasChanges
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

    func validatePhone(_ phone: String) {
        if phone.isEmpty {
            phoneError = ""
            return
        }
        let digits = phone.filter { $0.isNumber }
        if digits.count < 7 {
            phoneError = "Phone number must have at least 7 digits"
        } else {
            phoneError = ""
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
            currentUser.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber

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
            didSave = true
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
