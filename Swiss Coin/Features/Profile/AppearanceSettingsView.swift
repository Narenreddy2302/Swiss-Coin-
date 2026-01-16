//
//  AppearanceSettingsView.swift
//  Swiss Coin
//
//  View for managing app appearance settings.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.colorScheme) var systemColorScheme

    // Appearance Settings
    @AppStorage("theme_mode") private var themeMode = "system"
    @AppStorage("accent_color") private var accentColor = "#34C759"
    @AppStorage("font_size") private var fontSize = "medium"
    @AppStorage("reduce_motion") private var reduceMotion = false
    @AppStorage("haptic_feedback") private var hapticFeedback = true

    // Display Settings
    @AppStorage("show_balance_home") private var showBalanceOnHome = true
    @AppStorage("default_home_tab") private var defaultHomeTab = "summary"

    // Predefined accent colors
    private let accentColorOptions = [
        ("#34C759", "Green"),
        ("#007AFF", "Blue"),
        ("#FF9500", "Orange"),
        ("#FF2D55", "Pink"),
        ("#AF52DE", "Purple"),
        ("#5856D6", "Indigo"),
        ("#00C7BE", "Teal"),
        ("#FF3B30", "Red")
    ]

    var body: some View {
        Form {
            // Theme Section
            Section {
                Picker("Theme", selection: $themeMode) {
                    Label("Light", systemImage: "sun.max.fill").tag("light")
                    Label("Dark", systemImage: "moon.fill").tag("dark")
                    Label("System", systemImage: "iphone.gen3").tag("system")
                }
                .pickerStyle(.segmented)
                .onChange(of: themeMode) { _, _ in
                    HapticManager.selectionChanged()
                }

                // Theme Preview
                HStack(spacing: Spacing.lg) {
                    ThemePreviewCard(theme: "light", isSelected: themeMode == "light" || (themeMode == "system" && systemColorScheme == .light))
                    ThemePreviewCard(theme: "dark", isSelected: themeMode == "dark" || (themeMode == "system" && systemColorScheme == .dark))
                }
                .padding(.vertical, Spacing.sm)
            } header: {
                Label("Theme", systemImage: "paintbrush.fill")
                    .font(AppTypography.subheadlineMedium())
            }

            // Accent Color Section
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Spacing.md) {
                    ForEach(accentColorOptions, id: \.0) { color, name in
                        Button {
                            HapticManager.selectionChanged()
                            accentColor = color
                        } label: {
                            VStack(spacing: Spacing.xs) {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(accentColor == color ? AppColors.textPrimary : Color.clear, lineWidth: 3)
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .opacity(accentColor == color ? 1 : 0)
                                    )

                                Text(name)
                                    .font(AppTypography.caption2())
                                    .foregroundColor(accentColor == color ? AppColors.textPrimary : AppColors.textSecondary)
                            }
                        }
                    }
                }
                .padding(.vertical, Spacing.sm)
            } header: {
                Label("Accent Color", systemImage: "paintpalette.fill")
                    .font(AppTypography.subheadlineMedium())
            }

            // Text Size Section
            Section {
                Picker("Text Size", selection: $fontSize) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                    Text("Extra Large").tag("extra_large")
                }
                .onChange(of: fontSize) { _, _ in
                    HapticManager.selectionChanged()
                }

                // Text size preview
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Preview Text")
                        .font(fontSizePreview)
                        .foregroundColor(AppColors.textPrimary)

                    Text("This is how text will appear throughout the app.")
                        .font(fontSizePreviewSecondary)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.vertical, Spacing.sm)
            } header: {
                Label("Text Size", systemImage: "textformat.size")
                    .font(AppTypography.subheadlineMedium())
            }

            // Accessibility Section
            Section {
                Toggle("Reduce Motion", isOn: $reduceMotion)
                    .onChange(of: reduceMotion) { _, _ in HapticManager.toggle() }

                Toggle("Haptic Feedback", isOn: $hapticFeedback)
                    .onChange(of: hapticFeedback) { _, _ in HapticManager.toggle() }
            } header: {
                Label("Accessibility", systemImage: "accessibility")
                    .font(AppTypography.subheadlineMedium())
            } footer: {
                Text("Reduce motion minimizes animations. Haptic feedback provides tactile responses.")
                    .font(AppTypography.caption())
            }

            // Home Screen Settings
            Section {
                Toggle("Show Balance on Home", isOn: $showBalanceOnHome)
                    .onChange(of: showBalanceOnHome) { _, _ in HapticManager.toggle() }

                Picker("Default Home Tab", selection: $defaultHomeTab) {
                    Text("Summary").tag("summary")
                    Text("Recent Activity").tag("activity")
                    Text("Quick Actions").tag("quick")
                }
                .onChange(of: defaultHomeTab) { _, _ in
                    HapticManager.selectionChanged()
                }
            } header: {
                Label("Home Screen", systemImage: "house.fill")
                    .font(AppTypography.subheadlineMedium())
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed Properties

    private var fontSizePreview: Font {
        switch fontSize {
        case "small": return .system(size: 14, weight: .semibold)
        case "medium": return .system(size: 17, weight: .semibold)
        case "large": return .system(size: 20, weight: .semibold)
        case "extra_large": return .system(size: 24, weight: .semibold)
        default: return .system(size: 17, weight: .semibold)
        }
    }

    private var fontSizePreviewSecondary: Font {
        switch fontSize {
        case "small": return .system(size: 12)
        case "medium": return .system(size: 15)
        case "large": return .system(size: 17)
        case "extra_large": return .system(size: 20)
        default: return .system(size: 15)
        }
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let theme: String
    let isSelected: Bool

    private var backgroundColor: Color {
        theme == "dark" ? Color(UIColor.systemGray6) : Color.white
    }

    private var textColor: Color {
        theme == "dark" ? .white : .black
    }

    private var secondaryColor: Color {
        theme == "dark" ? Color(UIColor.systemGray) : Color(UIColor.systemGray3)
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Mini preview
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(theme == "dark" ? Color.black : Color.white)
                .frame(height: 80)
                .overlay(
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(secondaryColor)
                            .frame(width: 40, height: 6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(secondaryColor.opacity(0.5))
                            .frame(width: 60, height: 4)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(AppColors.positive)
                                .frame(width: 16, height: 16)
                            Circle()
                                .fill(AppColors.negative)
                                .frame(width: 16, height: 16)
                        }
                        .padding(.top, 4)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 3)
                )

            Text(theme == "dark" ? "Dark" : "Light")
                .font(AppTypography.caption())
                .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
        }
    }
}
