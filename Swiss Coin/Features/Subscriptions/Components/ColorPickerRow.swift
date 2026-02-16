//
//  ColorPickerRow.swift
//  Swiss Coin
//
//  Row for selecting a subscription color.
//

import SwiftUI

struct ColorPickerRow: View {
    @Binding var selectedColor: String
    @State private var showingPicker = false

    private let colors = [
        "#007AFF", // Blue
        "#34C759", // Green
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#FFCC00", // Yellow
        "#AF52DE", // Purple
        "#FF2D55", // Pink
        "#5856D6", // Indigo
        "#00C7BE", // Teal
        "#8E8E93", // Gray
        "#5AC8FA", // Cyan
        "#FF6B6B"  // Coral
    ]

    var body: some View {
        Button {
            HapticManager.tap()
            showingPicker = true
        } label: {
            HStack {
                Text("Color")
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Circle()
                    .fill(Color(hex: selectedColor))
                    .frame(width: IconSize.category, height: IconSize.category)

                Image(systemName: "chevron.right")
                    .font(.system(size: IconSize.sm, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 60))
                    ], spacing: Spacing.md) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                HapticManager.selectionChanged()
                                selectedColor = color
                                showingPicker = false
                            } label: {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(selectedColor == color ? AppColors.textPrimary : Color.clear, lineWidth: 3)
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: IconSize.md, weight: .bold))
                                            .foregroundColor(AppColors.onAccent)
                                            .opacity(selectedColor == color ? 1 : 0)
                                    )
                            }
                        }
                    }
                    .padding(Spacing.lg)
                }
                .background(AppColors.backgroundSecondary)
                .navigationTitle("Choose Color")
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
