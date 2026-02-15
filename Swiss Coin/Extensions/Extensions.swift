import CoreData
import SwiftUI

// MARK: - Person Extensions
// Note: Core Person computed properties (displayName, firstName, initials, etc.)
// are defined in Extensions/Person+Extensions.swift

// MARK: - Date Formatter Extensions
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let longDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// "MMM d, yyyy" format (e.g. "Jan 5, 2026") — used in transaction cards and rows
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
    
    /// Day-of-week format (e.g. "Monday") — used in date headers
    static let dayOfWeek: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    /// Month and day format (e.g. "September 16") — used in transaction detail card
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    /// Time-only format (e.g. "02:11 pm") — used in transaction detail card
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }()

    /// Short month format (e.g. "Feb") — used in receipt-style formatting
    static let shortMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    /// Year-only format (e.g. "2026") — used in receipt-style formatting
    static let yearOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()
}

// MARK: - Date Extensions

extension Date {
    /// Formats as "Feb 5th, 2026 | Thursday" — used in receipt-style transaction detail
    var receiptFormatted: String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: self)

        let month = DateFormatter.shortMonth.string(from: self)
        let year = DateFormatter.yearOnly.string(from: self)
        let dayOfWeek = DateFormatter.dayOfWeek.string(from: self)

        return "\(month) \(day)\(Self.daySuffix(for: day)), \(year) | \(dayOfWeek)"
    }

    private static func daySuffix(for day: Int) -> String {
        switch day {
        case 11, 12, 13: return "th"
        default:
            switch day % 10 {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }

    /// Short relative time string: "Just now", "2m", "1h", "Yesterday", or short date
    var relativeShort: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if Calendar.current.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            return DateFormatter.shortDate.string(from: self)
        }
    }
}
