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
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.swisscoin"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let coreData = Logger(subsystem: subsystem, category: "coredata")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let contacts = Logger(subsystem: subsystem, category: "contacts")
    static let transactions = Logger(subsystem: subsystem, category: "transactions")
    static let subscriptions = Logger(subsystem: subsystem, category: "subscriptions")
    static let auth = Logger(subsystem: subsystem, category: "auth")
}
