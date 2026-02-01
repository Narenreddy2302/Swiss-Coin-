//
//  KeychainHelper.swift
//  Swiss Coin
//
//  Helper for securely storing sensitive data in the keychain.
//

import Foundation
import Security

/// Helper for storing sensitive data in the iOS keychain
enum KeychainHelper {
    
    /// Save a value to the keychain
    /// - Parameters:
    ///   - key: The key to store the value under
    ///   - value: The value to store
    /// - Returns: True if successful, false otherwise
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete any existing item first
        delete(key: key)
        
        // Add new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Read a value from the keychain
    /// - Parameter key: The key to read the value for
    /// - Returns: The stored value or nil if not found
    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    /// Delete a value from the keychain
    /// - Parameter key: The key to delete
    /// - Returns: True if successful or item doesn't exist, false on error
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Update a value in the keychain
    /// - Parameters:
    ///   - key: The key to update
    ///   - value: The new value
    /// - Returns: True if successful, false otherwise
    @discardableResult
    static func update(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // If item doesn't exist, create it
        if status == errSecItemNotFound {
            return save(key: key, value: value)
        }
        
        return status == errSecSuccess
    }
    
    /// Check if a key exists in the keychain
    /// - Parameter key: The key to check
    /// - Returns: True if the key exists, false otherwise
    static func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanFalse!
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Delete all items stored by this app
    /// Use with extreme caution - this will delete all keychain data
    @discardableResult
    static func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}