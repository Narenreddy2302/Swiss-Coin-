//
//  AppLogger.swift
//  Swiss Coin
//
//  Centralized logging utility using os.Logger for production-safe logging.
//  All log output is stripped in non-debug builds via compiler optimization.
//

import Foundation
import os.log

/// Production-safe logger that uses os.Logger for structured, low-overhead logging.
/// Messages appear in Console.app but are NOT printed to stdout in release builds.
///
/// Note: Each Logger uses an inline string literal for the subsystem to avoid
/// referencing a shared `static let` property. This prevents Swift 6 strict
/// concurrency issues where inter-property dependencies in static initializers
/// cause actor-isolation inference, making the properties inaccessible from
/// `Task.detached`, nonisolated actors, or Sendable closures.
enum AppLogger {
    static let general = Logger(subsystem: "com.swisscoin", category: "general")
    static let coreData = Logger(subsystem: "com.swisscoin", category: "coredata")
    static let notifications = Logger(subsystem: "com.swisscoin", category: "notifications")
    static let contacts = Logger(subsystem: "com.swisscoin", category: "contacts")
    static let transactions = Logger(subsystem: "com.swisscoin", category: "transactions")
    static let subscriptions = Logger(subsystem: "com.swisscoin", category: "subscriptions")
    static let auth = Logger(subsystem: "com.swisscoin", category: "auth")
}
