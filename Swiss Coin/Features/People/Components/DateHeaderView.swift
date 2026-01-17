//
//  DateHeaderView.swift
//  Swiss Coin
//

import SwiftUI

struct DateHeaderView: View {
    let dateString: String

    init(date: Date) {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            self.dateString = "Today"
        } else if calendar.isDateInYesterday(date) {
            self.dateString = "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            self.dateString = formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            self.dateString = formatter.string(from: date)
        }
    }

    init(dateString: String) {
        self.dateString = dateString
    }

    var body: some View {
        HStack {
            Spacer()
            Text(dateString)
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(Color(UIColor.tertiarySystemFill))
                )
            Spacer()
        }
        .padding(.vertical, Spacing.sm)
    }
}
