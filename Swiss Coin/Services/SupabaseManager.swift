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
    let hapticFeedback: Bool
    let defaultCurrency: String
    let currencySymbolPosition: String
    let decimalPlaces: Int
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

struct DataExportResponse: Decodable {
    let exportUrl: String
}

// MARK: - Update Models

struct UserSettingsUpdate {
    var themeMode: String?
    var accentColor: String?
    var fontSize: String?
    var reduceMotion: Bool?
    var hapticFeedback: Bool?
    var defaultCurrency: String?
    var currencySymbolPosition: String?
    var decimalPlaces: Int?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if let v = themeMode { dict["theme_mode"] = v }
        if let v = accentColor { dict["accent_color"] = v }
        if let v = fontSize { dict["font_size"] = v }
        if let v = reduceMotion { dict["reduce_motion"] = v }
        if let v = hapticFeedback { dict["haptic_feedback"] = v }
        if let v = defaultCurrency { dict["default_currency"] = v }
        if let v = currencySymbolPosition { dict["currency_symbol_position"] = v }
        if let v = decimalPlaces { dict["decimal_places"] = v }
        return dict
    }
}

struct NotificationSettingsUpdate {
    var pushEnabled: Bool?
    var transactionAlerts: Bool?
    var reminderAlerts: Bool?
    var subscriptionAlerts: Bool?
    var settlementAlerts: Bool?
    var groupUpdates: Bool?
    var chatMessages: Bool?
    var weeklySummary: Bool?
    var monthlySummary: Bool?
    var quietHoursEnabled: Bool?
    var quietHoursStart: String?
    var quietHoursEnd: String?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if let v = pushEnabled { dict["push_enabled"] = v }
        if let v = transactionAlerts { dict["transaction_alerts"] = v }
        if let v = reminderAlerts { dict["reminder_alerts"] = v }
        if let v = subscriptionAlerts { dict["subscription_alerts"] = v }
        if let v = settlementAlerts { dict["settlement_alerts"] = v }
        if let v = groupUpdates { dict["group_updates"] = v }
        if let v = chatMessages { dict["chat_messages"] = v }
        if let v = weeklySummary { dict["weekly_summary"] = v }
        if let v = monthlySummary { dict["monthly_summary"] = v }
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
