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
            self.dateString = DateFormatter.dayOfWeek.string(from: date)
        } else {
            self.dateString = DateFormatter.mediumDate.string(from: date)
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
                        .fill(AppColors.backgroundTertiary)
                )
            Spacer()
        }
        .padding(.vertical, Spacing.sm)
    }
}
