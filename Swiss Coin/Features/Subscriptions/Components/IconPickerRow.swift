//
//  IconPickerRow.swift
//  Swiss Coin
//
//  Row for selecting a subscription icon.
//

import SwiftUI

struct IconPickerRow: View {
    @Binding var selectedIcon: String
    @State private var showingPicker = false

    private let popularIcons = [
        "creditcard.fill",
        "tv.fill",
        "music.note",
        "film.fill",
        "gamecontroller.fill",
        "book.fill",
        "newspaper.fill",
        "cloud.fill",
        "heart.fill",
        "cart.fill",
        "car.fill",
        "house.fill",
        "bolt.fill",
        "phone.fill",
        "wifi",
        "globe",
        "airplane",
        "tram.fill",
        "cup.and.saucer.fill",
        "fork.knife"
    ]

    var body: some View {
        Button {
            HapticManager.tap()
            showingPicker = true
        } label: {
            HStack {
                Text("Icon")
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                RoundedRectangle(cornerRadius: CornerRadius.xs)
                    .fill(AppColors.cardBackground)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: selectedIcon)
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.accent)
                    )

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 60))
                    ], spacing: Spacing.md) {
                        ForEach(popularIcons, id: \.self) { icon in
                            Button {
                                HapticManager.selectionChanged()
                                selectedIcon = icon
                                showingPicker = false
                            } label: {
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .fill(selectedIcon == icon ? AppColors.accent.opacity(0.2) : AppColors.cardBackground)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: icon)
                                            .font(.system(size: 24))
                                            .foregroundColor(selectedIcon == icon ? AppColors.accent : AppColors.textSecondary)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                                            .strokeBorder(selectedIcon == icon ? AppColors.accent : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                    }
                    .padding(Spacing.lg)
                }
                .background(AppColors.backgroundSecondary)
                .navigationTitle("Choose Icon")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingPicker = false
                        }
                    }
                }
            }
        }
    }
}
