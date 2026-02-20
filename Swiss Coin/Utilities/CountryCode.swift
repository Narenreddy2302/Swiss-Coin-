//
//  CountryCode.swift
//  Swiss Coin
//
//  Country code model for phone number entry.
//

import Foundation

struct CountryCode: Identifiable, Hashable {
    let id: String          // ISO 3166-1 alpha-2
    let name: String
    let dialCode: String
    let flag: String

    static let switzerland = CountryCode(id: "CH", name: "Switzerland", dialCode: "+41", flag: "🇨🇭")

    static let all: [CountryCode] = [
        CountryCode(id: "CH", name: "Switzerland", dialCode: "+41", flag: "🇨🇭"),
        CountryCode(id: "US", name: "United States", dialCode: "+1", flag: "🇺🇸"),
        CountryCode(id: "GB", name: "United Kingdom", dialCode: "+44", flag: "🇬🇧"),
        CountryCode(id: "DE", name: "Germany", dialCode: "+49", flag: "🇩🇪"),
        CountryCode(id: "FR", name: "France", dialCode: "+33", flag: "🇫🇷"),
        CountryCode(id: "IT", name: "Italy", dialCode: "+39", flag: "🇮🇹"),
        CountryCode(id: "AT", name: "Austria", dialCode: "+43", flag: "🇦🇹"),
        CountryCode(id: "CA", name: "Canada", dialCode: "+1", flag: "🇨🇦"),
        CountryCode(id: "IN", name: "India", dialCode: "+91", flag: "🇮🇳"),
        CountryCode(id: "AU", name: "Australia", dialCode: "+61", flag: "🇦🇺"),
        CountryCode(id: "ES", name: "Spain", dialCode: "+34", flag: "🇪🇸"),
        CountryCode(id: "NL", name: "Netherlands", dialCode: "+31", flag: "🇳🇱"),
        CountryCode(id: "BE", name: "Belgium", dialCode: "+32", flag: "🇧🇪"),
        CountryCode(id: "PT", name: "Portugal", dialCode: "+351", flag: "🇵🇹"),
        CountryCode(id: "SE", name: "Sweden", dialCode: "+46", flag: "🇸🇪"),
        CountryCode(id: "NO", name: "Norway", dialCode: "+47", flag: "🇳🇴"),
        CountryCode(id: "DK", name: "Denmark", dialCode: "+45", flag: "🇩🇰"),
        CountryCode(id: "FI", name: "Finland", dialCode: "+358", flag: "🇫🇮"),
        CountryCode(id: "IE", name: "Ireland", dialCode: "+353", flag: "🇮🇪"),
        CountryCode(id: "SG", name: "Singapore", dialCode: "+65", flag: "🇸🇬"),
        CountryCode(id: "JP", name: "Japan", dialCode: "+81", flag: "🇯🇵"),
        CountryCode(id: "KR", name: "South Korea", dialCode: "+82", flag: "🇰🇷"),
        CountryCode(id: "BR", name: "Brazil", dialCode: "+55", flag: "🇧🇷"),
        CountryCode(id: "MX", name: "Mexico", dialCode: "+52", flag: "🇲🇽"),
        CountryCode(id: "AE", name: "UAE", dialCode: "+971", flag: "🇦🇪"),
        CountryCode(id: "SA", name: "Saudi Arabia", dialCode: "+966", flag: "🇸🇦"),
        CountryCode(id: "ZA", name: "South Africa", dialCode: "+27", flag: "🇿🇦"),
        CountryCode(id: "NZ", name: "New Zealand", dialCode: "+64", flag: "🇳🇿"),
        CountryCode(id: "PL", name: "Poland", dialCode: "+48", flag: "🇵🇱"),
        CountryCode(id: "CZ", name: "Czech Republic", dialCode: "+420", flag: "🇨🇿"),
    ]
}
