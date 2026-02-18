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
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}
