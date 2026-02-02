//
//  Color+Hex.swift
//  Swiss Coin
//
//  Extension to support hex color initialization in SwiftUI.
//

import SwiftUI
import UIKit

extension Color {
    
    /// Initialize a Color from a hex string
    /// - Parameter hex: Hex string (e.g., "#FF5733", "FF5733", "#ff5733")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            // Invalid hex, fallback to AppColors.defaultAvatarColor (#007AFF)
            (a, r, g, b) = (255, 0, 122, 255)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Convert Color to hex string
    /// - Returns: Hex string representation (e.g., "#FF5733")
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(Float(r) * 255),
                     lroundf(Float(g) * 255),
                     lroundf(Float(b) * 255))
    }
    
    /// Check if color is light (for contrast calculation)
    var isLight: Bool {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let brightness = (r * 299 + g * 587 + b * 114) / 1000
        
        return brightness > 0.5
    }
    
    /// Get contrasting color (black or white) for text overlay
    var contrastingColor: Color {
        return isLight ? .black : .white
    }
}