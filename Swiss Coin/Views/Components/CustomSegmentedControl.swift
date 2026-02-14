//
//  CustomSegmentedControl.swift
//  Swiss Coin
//
//  Custom segmented control using the design system for consistent styling.
//

import SwiftUI

struct CustomSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]

    // Namespace for MatchedGeometryEffect
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: {
                    withAnimation(AppAnimation.spring) {
                        selection = index
                        HapticManager.selectionChanged()
                    }
                }) {
                    ZStack {
                        if selection == index {
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .fill(AppColors.buttonBackground)
                                .matchedGeometryEffect(id: "selection", in: namespace)
                                .shadow(color: AppColors.shadow, radius: 2, x: 0, y: 1)
                        }

                        Text(options[index])
                            .font(AppTypography.labelLarge())
                            .foregroundColor(selection == index ? AppColors.buttonForeground : AppColors.textSecondary)
                            .padding(.vertical, Spacing.sm)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("\(options[index]), tab \(index + 1) of \(options.count)")
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
        .padding(Spacing.xxs)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(CornerRadius.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Segment picker")
    }
}

#Preview {
    VStack {
        CustomSegmentedControl(selection: .constant(0), options: ["People", "Groups"])
        CustomSegmentedControl(selection: .constant(1), options: ["Personal", "Shared"])
    }
    .padding()
    .preferredColorScheme(.dark)
}
