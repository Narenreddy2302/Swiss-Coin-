//
//  PersonalDetailsView.swift
//  Swiss Coin
//
//  Native iOS Settings-style personal details editor.
//

import Combine
import CoreData
import CryptoKit
import PhotosUI
import Supabase
import SwiftUI

struct PersonalDetailsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PersonalDetailsViewModel()
    @FocusState private var focusedField: Field?
    @State private var showingDiscardAlert = false
    @State private var showCountryPicker = false

    private enum Field: Hashable {
        case displayName, fullName, email, phone
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
        .sheet(isPresented: $showCountryPicker) {
            CountryCodePicker(selectedCountry: $viewModel.selectedCountry)
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
            // Phone input with country code picker
            HStack(spacing: 0) {
                Button {
                    HapticManager.lightTap()
                    showCountryPicker = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(viewModel.selectedCountry.flag)
                            .font(.system(size: IconSize.md))

                        Text(viewModel.selectedCountry.dialCode)
                            .font(AppTypography.bodyLarge())
                            .foregroundColor(AppColors.textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: IconSize.xs))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .accessibilityLabel("\(viewModel.selectedCountry.name), \(viewModel.selectedCountry.dialCode)")
                .accessibilityHint("Double tap to change country code")

                Rectangle()
                    .fill(AppColors.divider)
                    .frame(width: 1)
                    .padding(.vertical, Spacing.sm)

                TextField("Phone number", text: Binding(
                    get: { viewModel.formattedPhoneInput },
                    set: { newValue in
                        viewModel.phoneDigits = newValue.filter(\.isNumber)
                        viewModel.hasChanges = true
                        viewModel.validatePhone()
                    }
                ))
                .font(AppTypography.bodyLarge())
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(.horizontal, Spacing.md)
                .focused($focusedField, equals: .phone)
                .accessibilityLabel("Phone number")
                .accessibilityHint("Enter your phone number without the country code")
                .onChange(of: viewModel.phoneDigits) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    if digits.count > 15 {
                        viewModel.phoneDigits = String(digits.prefix(15))
                    }
                }
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
                if viewModel.phoneDigits.isEmpty {
                    Text("Add your phone number so friends can find you on Swiss Coin.")
                        .foregroundColor(AppColors.textTertiary)
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
    @Published var email: String = ""
    @Published var profileColor: String = AppColors.defaultAvatarColorHex
    @Published var selectedImage: UIImage?

    // Phone editing
    @Published var selectedCountry = CountryCode.switzerland
    @Published var phoneDigits = ""
    @Published var phoneError = ""

    // UI state
    @Published var showingImagePicker = false
    @Published var showingPhotoOptions = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var emailError = ""
    @Published var isSaving = false
    @Published var hasChanges = false
    @Published var didSave = false

    // Account info
    private var accountCreatedDate: Date?
    private var originalPhoneE164 = ""

    // MARK: - Computed Properties

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

    var isPhoneValid: Bool {
        if phoneDigits.isEmpty { return true } // Empty is valid (phone is optional here)
        let digits = phoneDigits.filter(\.isNumber)
        guard digits.count >= 6, digits.count <= 15 else { return false }
        let e164 = selectedCountry.dialCode + digits
        let e164Digits = e164.filter(\.isNumber)
        return e164Digits.count >= 7 && e164Digits.count <= 15
    }

    var e164Phone: String {
        let digits = phoneDigits.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        return selectedCountry.dialCode + digits
    }

    var formattedPhoneInput: String {
        let digits = phoneDigits.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        return Self.formatForDisplay(digits: digits, countryId: selectedCountry.id)
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

    // MARK: - Phone Formatting

    /// Country-aware phone number display grouping.
    private static func formatForDisplay(digits: String, countryId: String) -> String {
        let chars = Array(digits)
        let groups: [Int]
        switch countryId {
        case "CH", "AT": groups = [2, 3, 2, 2]      // 79 123 45 67
        case "US", "CA": groups = [3, 3, 4]          // 555 123 4567
        case "GB":       groups = [4, 6]             // 7911 123456
        case "DE":       groups = [3, 4, 4]          // 151 1234 5678
        case "IN":       groups = [5, 5]             // 98765 43210
        case "FR", "IT": groups = [1, 2, 2, 2, 2]   // 6 12 34 56 78
        default:         groups = [3, 3, 3, 3]       // groups of 3
        }

        var result = ""
        var index = 0
        for (i, groupSize) in groups.enumerated() {
            guard index < chars.count else { break }
            if i > 0 { result += " " }
            let end = min(index + groupSize, chars.count)
            result += String(chars[index..<end])
            index = end
        }
        if index < chars.count {
            result += " " + String(chars[index...])
        }
        return result
    }

    /// Detect country code from an E.164 phone number.
    private static func detectCountryCode(from e164: String) -> (country: CountryCode, digits: String)? {
        guard e164.hasPrefix("+") else { return nil }
        // Try longest dial codes first to avoid ambiguity (e.g., +1 vs +1xxx)
        let sorted = CountryCode.all.sorted { $0.dialCode.count > $1.dialCode.count }
        for country in sorted {
            if e164.hasPrefix(country.dialCode) {
                let digits = String(e164.dropFirst(country.dialCode.count))
                return (country, digits)
            }
        }
        return nil
    }

    // MARK: - Load Data

    func loadCurrentUserData(context: NSManagedObjectContext) {
        let currentUser = CurrentUser.getOrCreate(in: context)
        displayName = currentUser.name ?? "You"
        profileColor = currentUser.colorHex ?? AppColors.defaultAvatarColorHex

        // Load and parse phone number
        let storedPhone = currentUser.phoneNumber ?? ""
        originalPhoneE164 = storedPhone
        if !storedPhone.isEmpty, let detected = Self.detectCountryCode(from: storedPhone) {
            selectedCountry = detected.country
            phoneDigits = detected.digits
        }

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

    func validatePhone() {
        if phoneDigits.isEmpty {
            phoneError = ""
            return
        }
        let digits = phoneDigits.filter(\.isNumber)
        if digits.count < 6 {
            phoneError = "Phone number is too short"
        } else if digits.count > 15 {
            phoneError = "Phone number is too long"
        } else {
            phoneError = ""
        }
    }

    // MARK: - Save Changes

    func saveChanges(context: NSManagedObjectContext) {
        guard canSave else { return }

        isSaving = true
        HapticManager.save()

        Task {
            do {
                // 1. Save to CoreData (source of truth)
                let currentUser = CurrentUser.getOrCreate(in: context)
                currentUser.name = displayName
                currentUser.colorHex = profileColor

                let newPhone = e164Phone
                let phoneChanged = newPhone != originalPhoneE164

                if phoneChanged {
                    currentUser.phoneNumber = newPhone.isEmpty ? nil : newPhone
                }

                if let image = selectedImage {
                    currentUser.photoData = image.jpegData(compressionQuality: 0.8)
                } else {
                    currentUser.photoData = nil
                }

                try context.save()

                // 2. Save to UserDefaults (cache)
                UserDefaults.standard.set(email, forKey: "user_email")
                UserDefaults.standard.set(fullName, forKey: "user_full_name")

                if !newPhone.isEmpty {
                    UserDefaults.standard.set(newPhone, forKey: "user_phone_e164")
                    UserDefaults.standard.set(true, forKey: "user_phone_collected")
                } else if phoneChanged {
                    UserDefaults.standard.removeObject(forKey: "user_phone_e164")
                    UserDefaults.standard.set(false, forKey: "user_phone_collected")
                }

                CurrentUser.updateProfile(
                    name: displayName,
                    colorHex: profileColor,
                    phoneNumber: newPhone.isEmpty ? nil : newPhone,
                    in: context
                )

                // 3. Sync to Supabase (real-time backend update)
                await syncToSupabase(phoneChanged: phoneChanged, newPhone: newPhone)

                // 4. Trigger contact discovery if phone was added or changed
                if phoneChanged, !newPhone.isEmpty {
                    await ContactDiscoveryService.shared.discoverContacts(context: context)
                }

                originalPhoneE164 = newPhone
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
    }

    // MARK: - Supabase Sync

    /// Syncs profile changes to the Supabase `profiles` table in real-time.
    /// Fails gracefully — CoreData is the source of truth and SyncManager provides
    /// eventual consistency if this call fails due to network issues.
    private func syncToSupabase(phoneChanged: Bool, newPhone: String) async {
        guard let userId = AuthManager.shared.currentUserId else { return }

        do {
            var updates: [String: String?] = [
                "display_name": displayName,
                "full_name": fullName.isEmpty ? nil : fullName,
                "email": email.isEmpty ? nil : email,
            ]

            if phoneChanged {
                updates["phone"] = newPhone.isEmpty ? nil : newPhone
                if !newPhone.isEmpty {
                    updates["phone_hash"] = ContactDiscoveryService.hashPhoneNumber(newPhone)
                } else {
                    updates["phone_hash"] = nil
                }
            }

            try await SupabaseConfig.client.from("profiles")
                .update(updates)
                .eq("id", value: userId.uuidString)
                .execute()
        } catch {
            // Log but don't block — offline-first means CoreData is authoritative
            AppLogger.auth.warning("Profile sync to Supabase failed: \(error.localizedDescription)")
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
