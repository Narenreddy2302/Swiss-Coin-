//
//  SupabaseConfig.swift
//  Swiss Coin
//
//  Supabase client singleton. Single entry point for all Supabase services.
//

import Foundation
import Supabase

enum SupabaseConfig {
    static let projectURL = URL(string: "https://fgcjijairsikaeshpiof.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZnY2ppamFpcnNpa2Flc2hwaW9mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNzg0ODIsImV4cCI6MjA4Njk1NDQ4Mn0.Ivyy6jPxRlwd6PTuXoRHHikBYai0XUlbvLT8edvSxFA"

    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: anonKey,
        options: .init(
            auth: .init(
                redirectToURL: URL(string: "swisscoin://auth-callback"),
                emitLocalSessionAsInitialSession: true
            )
        )
    )

    /// Shared JSON decoder configured for Supabase date formats (ISO 8601 with fractional seconds).
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Try ISO 8601 with fractional seconds first
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) {
                return date
            }

            // Fall back to without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(string)")
        }
        return decoder
    }()
}
