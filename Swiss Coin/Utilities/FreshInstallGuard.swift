//
//  FreshInstallGuard.swift
//  Swiss Coin
//
//  Clears stale Keychain data on app reinstall.
//  iOS Keychain persists across uninstall/reinstall while UserDefaults is wiped,
//  so we use a UserDefaults sentinel to detect reinstalls.
//

import Foundation

enum FreshInstallGuard {

    private static let sentinelKey = "app_installed_marker"

    /// Must be called before Supabase SDK initializes.
    /// Detects reinstall via missing UserDefaults sentinel + existing Keychain data,
    /// then clears stale auth items so the user sees the sign-in screen.
    static func clearKeychainIfReinstalled() {
        if UserDefaults.standard.bool(forKey: sentinelKey) {
            return
        }

        let hasSupabaseSession = KeychainHelper.exists(key: "supabase.auth.token")
        let hasAppleUserId = KeychainHelper.exists(key: "apple_user_id")

        if hasSupabaseSession || hasAppleUserId {
            // Stale Keychain from a previous install — wipe auth items
            KeychainHelper.deleteSupabaseAuthItems()
            KeychainHelper.delete(key: "apple_user_id")
            KeychainHelper.delete(key: "apple_email")
            KeychainHelper.delete(key: "user_pin_hash")
            KeychainHelper.delete(key: "swiss_coin_access_token")
            KeychainHelper.delete(key: "swiss_coin_refresh_token")
        }

        UserDefaults.standard.set(true, forKey: sentinelKey)
    }
}
