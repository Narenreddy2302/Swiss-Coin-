//
//  SupabaseManager.swift
//  Swiss Coin
//
//  Centralized Supabase client management for database operations.
//  Handles authentication, real-time subscriptions, and data sync.
//

import Combine
import Foundation

// MARK: - Configuration

/// Supabase configuration - Replace with your project credentials
enum SupabaseConfig {
    static let url = "https://your-project.supabase.co"
    static let anonKey = "your-anon-key"

    // Feature flags
    static let enableRealtime = true
    static let enableOfflineSync = true
}

// MARK: - Network Errors

enum SupabaseError: LocalizedError {
    case networkError(String)
    case authenticationError(String)
    case invalidResponse
    case decodingError(String)
    case serverError(Int, String)
    case notAuthenticated
    case rateLimited
    case conflict(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationError(let message):
            return "Authentication failed: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .notAuthenticated:
            return "You must be logged in to perform this action"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .conflict(let message):
            return "Conflict: \(message)"
        }
    }
}

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case authenticated(userId: UUID)
    case unauthenticated
    case verifyingOTP
}

// MARK: - Supabase Manager

@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    // MARK: - Published Properties

    @Published private(set) var authState: AuthState = .unknown
    @Published private(set) var isLoading = false
    @Published private(set) var currentUserId: UUID?
    @Published private(set) var sessionToken: String?

    // MARK: - Private Properties

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Keychain Keys

    private enum KeychainKey {
        static let accessToken = "swiss_coin_access_token"
        static let refreshToken = "swiss_coin_refresh_token"
        static let userId = "swiss_coin_user_id"
    }

    // MARK: - Init

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601

        // Restore session on init
        Task {
            await restoreSession()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: - Session Management

    /// Restore session from Keychain
    private func restoreSession() async {
        if let token = KeychainHelper.read(key: KeychainKey.accessToken),
           let userIdString = KeychainHelper.read(key: KeychainKey.userId),
           let userId = UUID(uuidString: userIdString) {
            self.sessionToken = token
            self.currentUserId = userId
            self.authState = .authenticated(userId: userId)

            // Verify session is still valid
            await verifySession()
        } else {
            self.authState = .unauthenticated
        }
    }

    /// Verify current session is valid
    private func verifySession() async {
        guard let token = sessionToken else {
            authState = .unauthenticated
            return
        }

        do {
            let _: UserProfile = try await request(
                endpoint: "/rest/v1/rpc/get_user_profile_complete",
                method: "POST",
                requiresAuth: true
            )
            // Session is valid
        } catch {
            // Session expired or invalid
            await signOut()
        }
    }

    /// Save session to Keychain
    private func saveSession(accessToken: String, refreshToken: String, userId: UUID) {
        KeychainHelper.save(key: KeychainKey.accessToken, value: accessToken)
        KeychainHelper.save(key: KeychainKey.refreshToken, value: refreshToken)
        KeychainHelper.save(key: KeychainKey.userId, value: userId.uuidString)

        self.sessionToken = accessToken
        self.currentUserId = userId
        self.authState = .authenticated(userId: userId)
    }

    /// Clear session from Keychain
    private func clearSession() {
        KeychainHelper.delete(key: KeychainKey.accessToken)
        KeychainHelper.delete(key: KeychainKey.refreshToken)
        KeychainHelper.delete(key: KeychainKey.userId)

        self.sessionToken = nil
        self.currentUserId = nil
        self.authState = .unauthenticated
    }

    // MARK: - Authentication

    /// Request OTP for phone number
    func requestOTP(phoneNumber: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let body: [String: Any] = ["phone": phoneNumber]

        let _: EmptyResponse = try await request(
            endpoint: "/auth/v1/otp",
            method: "POST",
            body: body,
            requiresAuth: false
        )

        authState = .verifyingOTP
    }

    /// Verify OTP and sign in
    func verifyOTP(phoneNumber: String, code: String) async throws -> UUID {
        isLoading = true
        defer { isLoading = false }

        let body: [String: Any] = [
            "phone": phoneNumber,
            "token": code,
            "type": "sms"
        ]

        let response: AuthResponse = try await request(
            endpoint: "/auth/v1/verify",
            method: "POST",
            body: body,
            requiresAuth: false
        )

        guard let accessToken = response.accessToken,
              let refreshToken = response.refreshToken,
              let userId = response.user?.id else {
            throw SupabaseError.authenticationError("Invalid auth response")
        }

        saveSession(accessToken: accessToken, refreshToken: refreshToken, userId: userId)

        // Create default settings for new user
        try? await createDefaultSettings()

        return userId
    }

    /// Sign out
    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        // Try to invalidate session on server
        if sessionToken != nil {
            let _: EmptyResponse? = try? await request(
                endpoint: "/auth/v1/logout",
                method: "POST",
                requiresAuth: true
            )
        }

        clearSession()
    }

    /// Refresh access token
    func refreshToken() async throws {
        guard let refreshToken = KeychainHelper.read(key: KeychainKey.refreshToken) else {
            throw SupabaseError.notAuthenticated
        }

        let body: [String: Any] = ["refresh_token": refreshToken]

        let response: AuthResponse = try await request(
            endpoint: "/auth/v1/token?grant_type=refresh_token",
            method: "POST",
            body: body,
            requiresAuth: false
        )

        guard let newAccessToken = response.accessToken,
              let newRefreshToken = response.refreshToken,
              let userId = response.user?.id ?? currentUserId else {
            throw SupabaseError.authenticationError("Failed to refresh token")
        }

        saveSession(accessToken: newAccessToken, refreshToken: newRefreshToken, userId: userId)
    }

    // MARK: - User Settings

    /// Create default settings for new user
    private func createDefaultSettings() async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/rpc/create_user_default_settings",
            method: "POST",
            requiresAuth: true
        )
    }

    /// Get complete user profile
    func getUserProfile() async throws -> UserProfile {
        return try await request(
            endpoint: "/rest/v1/rpc/get_user_profile_complete",
            method: "POST",
            requiresAuth: true
        )
    }

    /// Update user settings
    func updateUserSettings(_ settings: UserSettingsUpdate) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_settings",
            method: "PATCH",
            body: settings.dictionary,
            requiresAuth: true,
            filters: ["user_id": "eq.\(currentUserId?.uuidString ?? "")"]
        )
    }

    /// Update notification settings
    func updateNotificationSettings(_ settings: NotificationSettingsUpdate) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_notification_settings",
            method: "PATCH",
            body: settings.dictionary,
            requiresAuth: true,
            filters: ["user_id": "eq.\(currentUserId?.uuidString ?? "")"]
        )
    }

    /// Update privacy settings
    func updatePrivacySettings(_ settings: PrivacySettingsUpdate) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_privacy_settings",
            method: "PATCH",
            body: settings.dictionary,
            requiresAuth: true,
            filters: ["user_id": "eq.\(currentUserId?.uuidString ?? "")"]
        )
    }

    /// Update security settings
    func updateSecuritySettings(_ settings: SecuritySettingsUpdate) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_security_settings",
            method: "PATCH",
            body: settings.dictionary,
            requiresAuth: true,
            filters: ["user_id": "eq.\(currentUserId?.uuidString ?? "")"]
        )
    }

    // MARK: - Sessions Management

    /// Get active sessions
    func getActiveSessions() async throws -> [UserSessionInfo] {
        return try await request(
            endpoint: "/rest/v1/user_sessions",
            method: "GET",
            requiresAuth: true,
            filters: [
                "user_id": "eq.\(currentUserId?.uuidString ?? "")",
                "status": "eq.active",
                "select": "*"
            ]
        )
    }

    /// Terminate a session
    func terminateSession(sessionId: UUID) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_sessions",
            method: "PATCH",
            body: ["status": "terminated"],
            requiresAuth: true,
            filters: ["id": "eq.\(sessionId.uuidString)"]
        )
    }

    /// Terminate all other sessions
    func terminateAllOtherSessions() async throws {
        // This would be a custom RPC function
        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/rpc/terminate_other_sessions",
            method: "POST",
            requiresAuth: true
        )
    }

    // MARK: - Blocked Users

    /// Get blocked users
    func getBlockedUsers() async throws -> [BlockedUserInfo] {
        return try await request(
            endpoint: "/rest/v1/blocked_users",
            method: "GET",
            requiresAuth: true,
            filters: [
                "blocker_id": "eq.\(currentUserId?.uuidString ?? "")",
                "select": "*, blocked:profiles!blocked_id(id, display_name, avatar_url)"
            ]
        )
    }

    /// Block a user
    func blockUser(userId: UUID, reason: String? = nil) async throws {
        let body: [String: Any] = [
            "blocker_id": currentUserId?.uuidString ?? "",
            "blocked_id": userId.uuidString,
            "reason": reason as Any
        ]

        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/blocked_users",
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }

    /// Unblock a user
    func unblockUser(userId: UUID) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/blocked_users",
            method: "DELETE",
            requiresAuth: true,
            filters: [
                "blocker_id": "eq.\(currentUserId?.uuidString ?? "")",
                "blocked_id": "eq.\(userId.uuidString)"
            ]
        )
    }

    // MARK: - Transaction Categories

    /// Get custom categories
    func getCustomCategories() async throws -> [TransactionCategory] {
        return try await request(
            endpoint: "/rest/v1/transaction_categories",
            method: "GET",
            requiresAuth: true,
            filters: [
                "user_id": "eq.\(currentUserId?.uuidString ?? "")",
                "is_deleted": "eq.false",
                "select": "*"
            ]
        )
    }

    /// Create custom category
    func createCategory(name: String, icon: String, color: String, type: String) async throws -> TransactionCategory {
        let body: [String: Any] = [
            "user_id": currentUserId?.uuidString ?? "",
            "name": name,
            "icon_name": icon,
            "color_hex": color,
            "category_type": type,
            "is_system": false
        ]

        return try await request(
            endpoint: "/rest/v1/transaction_categories",
            method: "POST",
            body: body,
            requiresAuth: true,
            returnSingle: true
        )
    }

    // MARK: - Data Export

    /// Request data export
    func requestDataExport() async throws -> String {
        let response: DataExportResponse = try await request(
            endpoint: "/rest/v1/rpc/request_data_export",
            method: "POST",
            requiresAuth: true
        )
        return response.exportUrl
    }

    // MARK: - Account Deletion

    /// Request account deletion
    func requestAccountDeletion() async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/rpc/request_account_deletion",
            method: "POST",
            requiresAuth: true
        )
    }

    // MARK: - Profile Management

    /// Get profile details
    func getProfileDetails() async throws -> ProfileDetails {
        let response: ProfileDetailsResponse = try await request(
            endpoint: "/rest/v1/rpc/get_profile_details",
            method: "POST",
            body: ["p_user_id": currentUserId?.uuidString ?? ""],
            requiresAuth: true
        )
        return response.toProfileDetails()
    }

    /// Update profile details (display name, full name, email, color)
    func updateProfileDetails(_ update: ProfileDetailsUpdate) async throws -> ProfileDetails {
        var body: [String: Any] = ["p_user_id": currentUserId?.uuidString ?? ""]

        if let displayName = update.displayName { body["p_display_name"] = displayName }
        if let fullName = update.fullName { body["p_full_name"] = fullName }
        if let email = update.email { body["p_email"] = email }
        if let colorHex = update.colorHex { body["p_color_hex"] = colorHex }
        if let avatarUrl = update.avatarUrl { body["p_avatar_url"] = avatarUrl }

        let response: ProfileUpdateResponse = try await request(
            endpoint: "/rest/v1/rpc/update_profile_details",
            method: "POST",
            body: body,
            requiresAuth: true
        )

        guard response.success, let profile = response.profile else {
            throw SupabaseError.serverError(400, response.error ?? "Failed to update profile")
        }

        return profile
    }

    /// Upload profile photo to Supabase Storage
    func uploadProfilePhoto(imageData: Data, filename: String) async throws -> String {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let storagePath = "\(userId.uuidString)/\(filename)"
        let uploadUrl = "\(SupabaseConfig.url)/storage/v1/object/avatars/\(storagePath)"

        guard let url = URL(string: uploadUrl) else {
            throw SupabaseError.networkError("Invalid upload URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(sessionToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = imageData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            // Construct public URL
            let publicUrl = "\(SupabaseConfig.url)/storage/v1/object/public/avatars/\(storagePath)"

            // Update profile with new avatar URL
            let body: [String: Any] = [
                "p_user_id": userId.uuidString,
                "p_storage_path": storagePath,
                "p_original_filename": filename,
                "p_file_size_bytes": imageData.count,
                "p_mime_type": "image/jpeg"
            ]

            let _: EmptyResponse = try await self.request(
                endpoint: "/rest/v1/rpc/set_profile_photo",
                method: "POST",
                body: body,
                requiresAuth: true
            )

            return publicUrl
        default:
            let message = String(data: data, encoding: .utf8) ?? "Upload failed"
            throw SupabaseError.serverError(httpResponse.statusCode, message)
        }
    }

    /// Delete profile photo
    func deleteProfilePhoto() async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let response: DeletePhotoResponse = try await request(
            endpoint: "/rest/v1/rpc/delete_profile_photo",
            method: "POST",
            body: ["p_user_id": userId.uuidString],
            requiresAuth: true
        )

        // Delete from storage if there was a file
        if let storagePath = response.deletedStoragePath {
            let deleteUrl = "\(SupabaseConfig.url)/storage/v1/object/avatars/\(storagePath)"

            if let url = URL(string: deleteUrl) {
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(sessionToken ?? "")", forHTTPHeaderField: "Authorization")

                _ = try? await session.data(for: request)
            }
        }
    }

    /// Update email with validation
    func updateEmail(_ email: String) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let response: EmailUpdateResponse = try await request(
            endpoint: "/rest/v1/rpc/update_email",
            method: "POST",
            body: ["p_user_id": userId.uuidString, "p_email": email],
            requiresAuth: true
        )

        guard response.success else {
            if response.error == "email_already_in_use" {
                throw SupabaseError.conflict("This email is already associated with another account")
            }
            throw SupabaseError.serverError(400, response.error ?? "Failed to update email")
        }
    }

    // MARK: - Security Settings Management

    /// Get security settings
    func getSecuritySettings() async throws -> UserSecuritySettings {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let results: [UserSecuritySettings] = try await request(
            endpoint: "/rest/v1/user_security_settings",
            method: "GET",
            requiresAuth: true,
            filters: [
                "user_id": "eq.\(userId.uuidString)",
                "select": "*"
            ]
        )

        guard let settings = results.first else {
            throw SupabaseError.serverError(404, "Security settings not found")
        }

        return settings
    }

    /// Get privacy settings
    func getPrivacySettings() async throws -> UserPrivacySettings {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let results: [UserPrivacySettings] = try await request(
            endpoint: "/rest/v1/user_privacy_settings",
            method: "GET",
            requiresAuth: true,
            filters: [
                "user_id": "eq.\(userId.uuidString)",
                "select": "*"
            ]
        )

        guard let settings = results.first else {
            throw SupabaseError.serverError(404, "Privacy settings not found")
        }

        return settings
    }

    /// Set PIN with hash
    func setPIN(pinHash: String) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_security_settings",
            method: "PATCH",
            body: [
                "pin_enabled": true,
                "pin_hash": pinHash,
                "pin_attempts_remaining": 5
            ],
            requiresAuth: true,
            filters: ["user_id": "eq.\(userId.uuidString)"]
        )
    }

    /// Disable PIN
    func disablePIN() async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_security_settings",
            method: "PATCH",
            body: [
                "pin_enabled": false,
                "pin_hash": NSNull()
            ],
            requiresAuth: true,
            filters: ["user_id": "eq.\(userId.uuidString)"]
        )
    }

    /// Verify PIN and return remaining attempts
    func verifyPIN(pinHash: String) async throws -> PINVerificationResult {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let response: PINVerificationResult = try await request(
            endpoint: "/rest/v1/rpc/verify_pin",
            method: "POST",
            body: [
                "p_user_id": userId.uuidString,
                "p_pin_hash": pinHash
            ],
            requiresAuth: true
        )

        return response
    }

    /// Enable/disable biometric authentication
    func setBiometricEnabled(_ enabled: Bool, biometricType: String?) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        var body: [String: Any] = ["biometric_enabled": enabled]
        if enabled {
            body["biometric_type"] = biometricType ?? "unknown"
            body["biometric_registered_at"] = ISO8601DateFormatter().string(from: Date())
        } else {
            body["biometric_type"] = NSNull()
            body["biometric_registered_at"] = NSNull()
        }

        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_security_settings",
            method: "PATCH",
            body: body,
            requiresAuth: true,
            filters: ["user_id": "eq.\(userId.uuidString)"]
        )
    }

    /// Update auto-lock timeout
    func setAutoLockTimeout(_ minutes: Int) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_security_settings",
            method: "PATCH",
            body: ["auto_lock_timeout_minutes": minutes],
            requiresAuth: true,
            filters: ["user_id": "eq.\(userId.uuidString)"]
        )
    }

    /// Update require auth for sensitive actions
    func setRequireAuthForSensitiveActions(_ required: Bool) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_security_settings",
            method: "PATCH",
            body: ["require_auth_for_sensitive_actions": required],
            requiresAuth: true,
            filters: ["user_id": "eq.\(userId.uuidString)"]
        )
    }

    /// Get login history
    func getLoginHistory(limit: Int = 20) async throws -> [LoginHistoryEntry] {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        return try await request(
            endpoint: "/rest/v1/login_history",
            method: "GET",
            requiresAuth: true,
            filters: [
                "user_id": "eq.\(userId.uuidString)",
                "select": "*",
                "order": "attempted_at.desc",
                "limit": "\(limit)"
            ]
        )
    }

    /// Get current session info
    func getCurrentSession() async throws -> UserSessionInfo? {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let results: [UserSessionInfo] = try await request(
            endpoint: "/rest/v1/user_sessions",
            method: "GET",
            requiresAuth: true,
            filters: [
                "user_id": "eq.\(userId.uuidString)",
                "is_current_session": "eq.true",
                "status": "eq.active",
                "select": "*"
            ]
        )

        return results.first
    }

    /// Mark device as trusted
    func setDeviceTrusted(_ sessionId: UUID, trusted: Bool) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_sessions",
            method: "PATCH",
            body: ["trusted_device": trusted],
            requiresAuth: true,
            filters: ["id": "eq.\(sessionId.uuidString)"]
        )
    }

    /// Terminate all other sessions (enhanced version)
    func terminateAllOtherSessionsEnhanced() async throws -> Int {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        // Get current session first
        guard let currentSession = try await getCurrentSession() else {
            throw SupabaseError.serverError(400, "No current session found")
        }

        let response: TerminateSessionsResponse = try await request(
            endpoint: "/rest/v1/rpc/revoke_all_other_sessions",
            method: "POST",
            body: [
                "p_user_id": userId.uuidString,
                "p_current_session_id": currentSession.id.uuidString
            ],
            requiresAuth: true
        )

        return response.count
    }

    // MARK: - Appearance Settings

    /// Get appearance settings
    func getAppearanceSettings() async throws -> UserAppearanceSettings {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let results: [UserAppearanceSettings] = try await request(
            endpoint: "/rest/v1/user_settings",
            method: "GET",
            requiresAuth: true,
            filters: [
                "user_id": "eq.\(userId.uuidString)",
                "select": "*"
            ]
        )

        guard let settings = results.first else {
            throw SupabaseError.serverError(404, "Appearance settings not found")
        }

        return settings
    }

    /// Update appearance settings
    func updateAppearanceSettings(_ settings: UserSettingsUpdate) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_settings",
            method: "PATCH",
            body: settings.dictionary,
            requiresAuth: true,
            filters: ["user_id": "eq.\(userId.uuidString)"]
        )
    }

    // MARK: - Notification Settings

    /// Get notification settings
    func getNotificationSettingsComplete() async throws -> UserNotificationSettings {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let results: [UserNotificationSettings] = try await request(
            endpoint: "/rest/v1/user_notification_settings",
            method: "GET",
            requiresAuth: true,
            filters: [
                "user_id": "eq.\(userId.uuidString)",
                "select": "*"
            ]
        )

        guard let settings = results.first else {
            throw SupabaseError.serverError(404, "Notification settings not found")
        }

        return settings
    }

    /// Update notification settings (comprehensive)
    func updateNotificationSettingsComplete(_ settings: NotificationSettingsUpdate) async throws {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let _: EmptyResponse = try await request(
            endpoint: "/rest/v1/user_notification_settings",
            method: "PATCH",
            body: settings.dictionary,
            requiresAuth: true,
            filters: ["user_id": "eq.\(userId.uuidString)"]
        )
    }

    // MARK: - Transaction Categories

    /// Get all categories (system + user custom)
    func getAllCategories() async throws -> [SystemTransactionCategory] {
        return try await request(
            endpoint: "/rest/v1/transaction_categories",
            method: "GET",
            requiresAuth: true,
            filters: [
                "is_active": "eq.true",
                "select": "*",
                "order": "display_order.asc"
            ]
        )
    }

    /// Create custom category
    func createCustomCategory(name: String, icon: String, colorHex: String, categoryType: String) async throws -> SystemTransactionCategory {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }

        let id = name.lowercased().replacingOccurrences(of: " ", with: "_") + "_\(UUID().uuidString.prefix(8))"

        let body: [String: Any] = [
            "id": id,
            "name": name,
            "icon": icon,
            "color_hex": colorHex,
            "category_type": categoryType,
            "user_id": userId.uuidString,
            "is_system": false,
            "display_order": 50
        ]

        return try await request(
            endpoint: "/rest/v1/transaction_categories",
            method: "POST",
            body: body,
            requiresAuth: true,
            returnSingle: true
        )
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        requiresAuth: Bool,
        filters: [String: String] = [:],
        returnSingle: Bool = false
    ) async throws -> T {
        var urlString = SupabaseConfig.url + endpoint

        // Add query parameters for filters
        if !filters.isEmpty {
            let queryString = filters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += (endpoint.contains("?") ? "&" : "?") + queryString
        }

        guard let url = URL(string: urlString) else {
            throw SupabaseError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")

        if returnSingle {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }

        if requiresAuth {
            guard let token = sessionToken else {
                throw SupabaseError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw SupabaseError.decodingError(error.localizedDescription)
            }
        case 401:
            // Try to refresh token once
            try await refreshToken()
            // Retry request
            return try await self.request(
                endpoint: endpoint,
                method: method,
                body: body,
                requiresAuth: requiresAuth,
                filters: filters,
                returnSingle: returnSingle
            )
        case 429:
            throw SupabaseError.rateLimited
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.serverError(httpResponse.statusCode, message)
        }
    }
}

// MARK: - Response Models

struct EmptyResponse: Decodable {}

struct AuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let user: AuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct AuthUser: Decodable {
    let id: UUID
    let phone: String?
    let email: String?
}

struct UserProfile: Decodable {
    let userId: UUID
    let displayName: String?
    let avatarUrl: String?
    let phoneNumber: String?
    let settings: UserSettings?
    let notificationSettings: NotificationSettings?
    let privacySettings: PrivacySettings?
    let securitySettings: SecuritySettings?
}

struct UserSettings: Decodable {
    let themeMode: String
    let accentColor: String
    let fontSize: String
    let reduceMotion: Bool
    let hapticFeedback: Bool  // Maps from haptic_feedback_enabled in DB
    let defaultCurrency: String
    let currencySymbolPosition: String?
    let decimalPlaces: Int?

    enum CodingKeys: String, CodingKey {
        case themeMode = "theme_mode"
        case accentColor = "accent_color"
        case fontSize = "font_size"
        case reduceMotion = "reduce_motion"
        case hapticFeedback = "haptic_feedback_enabled"
        case defaultCurrency = "default_currency"
        case currencySymbolPosition = "currency_symbol_position"
        case decimalPlaces = "decimal_places"
    }
}

struct NotificationSettings: Decodable {
    let pushEnabled: Bool
    let transactionAlerts: Bool
    let reminderAlerts: Bool
    let subscriptionAlerts: Bool
    let settlementAlerts: Bool
    let groupUpdates: Bool
    let chatMessages: Bool
    let weeklySummary: Bool
    let monthlySummary: Bool
    let quietHoursEnabled: Bool
    let quietHoursStart: String?
    let quietHoursEnd: String?
}

struct PrivacySettings: Decodable {
    let profileVisibility: String
    let showOnlineStatus: Bool
    let showLastSeen: Bool
    let allowFriendRequests: Bool
    let allowGroupInvites: Bool
}

struct SecuritySettings: Decodable {
    let biometricEnabled: Bool
    let pinEnabled: Bool
    let autoLockTimeout: Int
    let twoFactorEnabled: Bool
}

struct UserSessionInfo: Decodable, Identifiable {
    let id: UUID
    let deviceName: String?
    let deviceType: String?
    let osVersion: String?
    let appVersion: String?
    let ipAddress: String?
    let location: String?
    let createdAt: Date
    let lastActiveAt: Date
    let isCurrent: Bool
}

struct BlockedUserInfo: Decodable, Identifiable {
    let id: UUID
    let blockedId: UUID
    let reason: String?
    let createdAt: Date
    let blocked: BlockedUserProfile?
}

struct BlockedUserProfile: Decodable {
    let id: UUID
    let displayName: String?
    let avatarUrl: String?
}

struct TransactionCategory: Decodable, Identifiable {
    let id: UUID
    let name: String
    let iconName: String
    let colorHex: String
    let categoryType: String
    let isSystem: Bool
}

struct SystemTransactionCategory: Decodable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let colorHex: String
    let categoryType: String
    let userId: UUID?
    let isSystem: Bool
    let displayOrder: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case colorHex = "color_hex"
        case categoryType = "category_type"
        case userId = "user_id"
        case isSystem = "is_system"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }
}

struct DataExportResponse: Decodable {
    let exportUrl: String
}

// MARK: - Profile Models

struct ProfileDetails: Decodable {
    let id: UUID
    let phoneNumber: String?
    let phoneVerified: Bool
    let displayName: String?
    let fullName: String?
    let email: String?
    let emailVerified: Bool
    let avatarUrl: String?
    let colorHex: String?
    let defaultCurrency: String?
    let createdAt: Date?
    let updatedAt: Date?
}

struct ProfileDetailsResponse: Decodable {
    let id: UUID?
    let phoneNumber: String?
    let phoneVerified: Bool?
    let displayName: String?
    let fullName: String?
    let email: String?
    let emailVerified: Bool?
    let avatarUrl: String?
    let colorHex: String?
    let defaultCurrency: String?
    let createdAt: String?
    let updatedAt: String?

    func toProfileDetails() -> ProfileDetails {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return ProfileDetails(
            id: id ?? UUID(),
            phoneNumber: phoneNumber,
            phoneVerified: phoneVerified ?? false,
            displayName: displayName,
            fullName: fullName,
            email: email,
            emailVerified: emailVerified ?? false,
            avatarUrl: avatarUrl,
            colorHex: colorHex,
            defaultCurrency: defaultCurrency,
            createdAt: createdAt.flatMap { dateFormatter.date(from: $0) },
            updatedAt: updatedAt.flatMap { dateFormatter.date(from: $0) }
        )
    }
}

struct ProfileUpdateResponse: Decodable {
    let success: Bool
    let error: String?
    let profile: ProfileDetails?
}

struct ProfileDetailsUpdate {
    var displayName: String?
    var fullName: String?
    var email: String?
    var colorHex: String?
    var avatarUrl: String?
}

struct DeletePhotoResponse: Decodable {
    let success: Bool
    let deletedStoragePath: String?

    enum CodingKeys: String, CodingKey {
        case success
        case deletedStoragePath = "deleted_storage_path"
    }
}

struct EmailUpdateResponse: Decodable {
    let success: Bool
    let error: String?
    let email: String?
}

// MARK: - Security Models

struct UserSecuritySettings: Decodable {
    let id: UUID
    let userId: UUID
    let pinEnabled: Bool
    let pinHash: String?
    let pinAttemptsRemaining: Int?
    let pinLockedUntil: Date?
    let biometricEnabled: Bool
    let biometricType: String?
    let biometricRegisteredAt: Date?
    let twoFactorEnabled: Bool
    let twoFactorMethod: String?
    let requireAuthForSensitiveActions: Bool
    let autoLockTimeoutMinutes: Int?
    let logoutOnAppClose: Bool
    let singleSessionOnly: Bool
    let maxLoginAttempts: Int
    let loginLockoutMinutes: Int
    let notifyOnNewDevice: Bool
    let notifyOnSuspiciousActivity: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case pinEnabled = "pin_enabled"
        case pinHash = "pin_hash"
        case pinAttemptsRemaining = "pin_attempts_remaining"
        case pinLockedUntil = "pin_locked_until"
        case biometricEnabled = "biometric_enabled"
        case biometricType = "biometric_type"
        case biometricRegisteredAt = "biometric_registered_at"
        case twoFactorEnabled = "two_factor_enabled"
        case twoFactorMethod = "two_factor_method"
        case requireAuthForSensitiveActions = "require_auth_for_sensitive_actions"
        case autoLockTimeoutMinutes = "auto_lock_timeout_minutes"
        case logoutOnAppClose = "logout_on_app_close"
        case singleSessionOnly = "single_session_only"
        case maxLoginAttempts = "max_login_attempts"
        case loginLockoutMinutes = "login_lockout_minutes"
        case notifyOnNewDevice = "notify_on_new_device"
        case notifyOnSuspiciousActivity = "notify_on_suspicious_activity"
    }
}

struct UserPrivacySettings: Decodable {
    let id: UUID
    let userId: UUID
    let profileVisibility: String
    let showPhoneNumber: Bool
    let showEmail: Bool
    let showFullName: Bool
    let showLastSeen: Bool
    let showProfilePhoto: Bool
    let showBalancesToContacts: Bool
    let showTransactionHistory: Bool
    let allowContactDiscovery: Bool
    let syncContactsWithPhone: Bool
    let allowAnalytics: Bool
    let allowCrashReports: Bool
    let personalizedSuggestions: Bool
    let dataExportEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case profileVisibility = "profile_visibility"
        case showPhoneNumber = "show_phone_number"
        case showEmail = "show_email"
        case showFullName = "show_full_name"
        case showLastSeen = "show_last_seen"
        case showProfilePhoto = "show_profile_photo"
        case showBalancesToContacts = "show_balances_to_contacts"
        case showTransactionHistory = "show_transaction_history"
        case allowContactDiscovery = "allow_contact_discovery"
        case syncContactsWithPhone = "sync_contacts_with_phone"
        case allowAnalytics = "allow_analytics"
        case allowCrashReports = "allow_crash_reports"
        case personalizedSuggestions = "personalized_suggestions"
        case dataExportEnabled = "data_export_enabled"
    }
}

struct PINVerificationResult: Decodable {
    let success: Bool
    let attemptsRemaining: Int?
    let lockedUntil: Date?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case attemptsRemaining = "attempts_remaining"
        case lockedUntil = "locked_until"
        case error
    }
}

struct LoginHistoryEntry: Decodable, Identifiable {
    let id: UUID
    let userId: UUID?
    let phoneNumber: String?
    let success: Bool
    let failureReason: String?
    let authMethod: String?
    let deviceId: String?
    let deviceName: String?
    let deviceType: String?
    let ipAddress: String?
    let locationCity: String?
    let locationCountry: String?
    let isSuspicious: Bool
    let riskScore: Int?
    let attemptedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case phoneNumber = "phone_number"
        case success
        case failureReason = "failure_reason"
        case authMethod = "auth_method"
        case deviceId = "device_id"
        case deviceName = "device_name"
        case deviceType = "device_type"
        case ipAddress = "ip_address"
        case locationCity = "location_city"
        case locationCountry = "location_country"
        case isSuspicious = "is_suspicious"
        case riskScore = "risk_score"
        case attemptedAt = "attempted_at"
    }
}

struct TerminateSessionsResponse: Decodable {
    let count: Int
}

// MARK: - Appearance Settings Models

struct UserAppearanceSettings: Decodable {
    let id: UUID
    let userId: UUID
    let themeMode: String
    let accentColor: String
    let fontSize: String
    let reduceMotion: Bool
    let hapticFeedbackEnabled: Bool
    let dateFormat: String?
    let timeFormat: String?
    let weekStartsOn: Int?
    let defaultHomeTab: String?
    let showBalanceOnHome: Bool
    let defaultSplitMethod: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case themeMode = "theme_mode"
        case accentColor = "accent_color"
        case fontSize = "font_size"
        case reduceMotion = "reduce_motion"
        case hapticFeedbackEnabled = "haptic_feedback_enabled"
        case dateFormat = "date_format"
        case timeFormat = "time_format"
        case weekStartsOn = "week_starts_on"
        case defaultHomeTab = "default_home_tab"
        case showBalanceOnHome = "show_balance_on_home"
        case defaultSplitMethod = "default_split_method"
    }
}

// MARK: - Notification Settings Models

struct UserNotificationSettings: Decodable {
    let id: UUID
    let userId: UUID

    // Master toggle
    let allNotificationsEnabled: Bool

    // Transaction notifications
    let newExpenseAdded: Bool
    let expenseModified: Bool
    let expenseDeleted: Bool
    let someonePaidYou: Bool

    // Reminder notifications
    let paymentReminders: Bool
    let reminderFrequency: String?
    let reminderDaysBefore: Int

    // Subscription notifications
    let subscriptionDueSoon: Bool
    let subscriptionDueDays: Int
    let subscriptionOverdue: Bool
    let subscriptionPaid: Bool

    // Settlement notifications
    let settlementReceived: Bool
    let settlementSent: Bool

    // Group notifications
    let addedToGroup: Bool
    let removedFromGroup: Bool
    let groupExpenseAdded: Bool

    // Chat notifications
    let newMessage: Bool
    let messageFrequency: String?

    // Summary notifications
    let weeklySummary: Bool
    let monthlyReport: Bool
    let weeklySummaryDay: Int?

    // Quiet hours
    let quietHoursEnabled: Bool
    let quietHoursStart: String?
    let quietHoursEnd: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case allNotificationsEnabled = "all_notifications_enabled"
        case newExpenseAdded = "new_expense_added"
        case expenseModified = "expense_modified"
        case expenseDeleted = "expense_deleted"
        case someonePaidYou = "someone_paid_you"
        case paymentReminders = "payment_reminders"
        case reminderFrequency = "reminder_frequency"
        case reminderDaysBefore = "reminder_days_before"
        case subscriptionDueSoon = "subscription_due_soon"
        case subscriptionDueDays = "subscription_due_days"
        case subscriptionOverdue = "subscription_overdue"
        case subscriptionPaid = "subscription_paid"
        case settlementReceived = "settlement_received"
        case settlementSent = "settlement_sent"
        case addedToGroup = "added_to_group"
        case removedFromGroup = "removed_from_group"
        case groupExpenseAdded = "group_expense_added"
        case newMessage = "new_message"
        case messageFrequency = "message_frequency"
        case weeklySummary = "weekly_summary"
        case monthlyReport = "monthly_report"
        case weeklySummaryDay = "weekly_summary_day"
        case quietHoursEnabled = "quiet_hours_enabled"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
    }
}

// MARK: - Update Models

struct UserSettingsUpdate {
    // Appearance
    var themeMode: String?
    var accentColor: String?
    var fontSize: String?
    var reduceMotion: Bool?
    var hapticFeedbackEnabled: Bool?

    // Regional
    var dateFormat: String?
    var timeFormat: String?
    var weekStartsOn: Int?

    // Dashboard
    var defaultHomeTab: String?
    var showBalanceOnHome: Bool?
    var defaultSplitMethod: String?

    // Legacy (for backward compatibility)
    var defaultCurrency: String?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if let v = themeMode { dict["theme_mode"] = v }
        if let v = accentColor { dict["accent_color"] = v }
        if let v = fontSize { dict["font_size"] = v }
        if let v = reduceMotion { dict["reduce_motion"] = v }
        if let v = hapticFeedbackEnabled { dict["haptic_feedback_enabled"] = v }
        if let v = dateFormat { dict["date_format"] = v }
        if let v = timeFormat { dict["time_format"] = v }
        if let v = weekStartsOn { dict["week_starts_on"] = v }
        if let v = defaultHomeTab { dict["default_home_tab"] = v }
        if let v = showBalanceOnHome { dict["show_balance_on_home"] = v }
        if let v = defaultSplitMethod { dict["default_split_method"] = v }
        if let v = defaultCurrency { dict["default_currency"] = v }
        return dict
    }
}

struct NotificationSettingsUpdate {
    // Master toggle
    var allNotificationsEnabled: Bool?

    // Transaction notifications
    var newExpenseAdded: Bool?
    var expenseModified: Bool?
    var expenseDeleted: Bool?
    var someonePaidYou: Bool?

    // Reminder notifications
    var paymentReminders: Bool?
    var reminderFrequency: String?
    var reminderDaysBefore: Int?

    // Subscription notifications
    var subscriptionDueSoon: Bool?
    var subscriptionDueDays: Int?
    var subscriptionOverdue: Bool?
    var subscriptionPaid: Bool?

    // Settlement notifications
    var settlementReceived: Bool?
    var settlementSent: Bool?

    // Group notifications
    var addedToGroup: Bool?
    var removedFromGroup: Bool?
    var groupExpenseAdded: Bool?

    // Chat notifications
    var newMessage: Bool?
    var messageFrequency: String?

    // Summary notifications
    var weeklySummary: Bool?
    var monthlyReport: Bool?
    var weeklySummaryDay: Int?

    // Quiet hours
    var quietHoursEnabled: Bool?
    var quietHoursStart: String?
    var quietHoursEnd: String?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if let v = allNotificationsEnabled { dict["all_notifications_enabled"] = v }
        if let v = newExpenseAdded { dict["new_expense_added"] = v }
        if let v = expenseModified { dict["expense_modified"] = v }
        if let v = expenseDeleted { dict["expense_deleted"] = v }
        if let v = someonePaidYou { dict["someone_paid_you"] = v }
        if let v = paymentReminders { dict["payment_reminders"] = v }
        if let v = reminderFrequency { dict["reminder_frequency"] = v }
        if let v = reminderDaysBefore { dict["reminder_days_before"] = v }
        if let v = subscriptionDueSoon { dict["subscription_due_soon"] = v }
        if let v = subscriptionDueDays { dict["subscription_due_days"] = v }
        if let v = subscriptionOverdue { dict["subscription_overdue"] = v }
        if let v = subscriptionPaid { dict["subscription_paid"] = v }
        if let v = settlementReceived { dict["settlement_received"] = v }
        if let v = settlementSent { dict["settlement_sent"] = v }
        if let v = addedToGroup { dict["added_to_group"] = v }
        if let v = removedFromGroup { dict["removed_from_group"] = v }
        if let v = groupExpenseAdded { dict["group_expense_added"] = v }
        if let v = newMessage { dict["new_message"] = v }
        if let v = messageFrequency { dict["message_frequency"] = v }
        if let v = weeklySummary { dict["weekly_summary"] = v }
        if let v = monthlyReport { dict["monthly_report"] = v }
        if let v = weeklySummaryDay { dict["weekly_summary_day"] = v }
        if let v = quietHoursEnabled { dict["quiet_hours_enabled"] = v }
        if let v = quietHoursStart { dict["quiet_hours_start"] = v }
        if let v = quietHoursEnd { dict["quiet_hours_end"] = v }
        return dict
    }
}

struct PrivacySettingsUpdate {
    var profileVisibility: String?
    var showOnlineStatus: Bool?
    var showLastSeen: Bool?
    var allowFriendRequests: Bool?
    var allowGroupInvites: Bool?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if let v = profileVisibility { dict["profile_visibility"] = v }
        if let v = showOnlineStatus { dict["show_online_status"] = v }
        if let v = showLastSeen { dict["show_last_seen"] = v }
        if let v = allowFriendRequests { dict["allow_friend_requests"] = v }
        if let v = allowGroupInvites { dict["allow_group_invites"] = v }
        return dict
    }
}

struct SecuritySettingsUpdate {
    var biometricEnabled: Bool?
    var pinEnabled: Bool?
    var pinHash: String?
    var autoLockTimeout: Int?
    var twoFactorEnabled: Bool?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if let v = biometricEnabled { dict["biometric_enabled"] = v }
        if let v = pinEnabled { dict["pin_enabled"] = v }
        if let v = pinHash { dict["pin_hash"] = v }
        if let v = autoLockTimeout { dict["auto_lock_timeout"] = v }
        if let v = twoFactorEnabled { dict["two_factor_enabled"] = v }
        return dict
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
