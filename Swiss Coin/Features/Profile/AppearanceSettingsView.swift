//
//  AppearanceSettingsView.swift
//  Swiss Coin
//
//  Simplified appearance settings with card-based design.
//

import Combine
import SwiftUI

@MainActor
final class AppearanceSettingsViewModel: ObservableObject {
    @Published var themeMode: String = "system"
    @Published var accentColor: String = "#34C759"
    @Published var fontSize: String = "medium"
    @Published var reduceMotion: Bool = false
    @Published var hapticFeedback: Bool = true

    private var cancellables = Set<AnyCancellable>()

    @AppStorage("theme_mode") private var storedThemeMode = "system"
    @AppStorage("accent_color") private var storedAccentColor = "#34C759"
    @AppStorage("font_size") private var storedFontSize = "medium"
    @AppStorage("reduce_motion") private var storedReduceMotion = false
    @AppStorage("haptic_feedback") private var storedHapticFeedback = true

    init() {
        loadFromLocalStorage()
        setupAutoSave()
    }

    func loadSettings() {
        loadFromLocalStorage()
    }

    private func loadFromLocalStorage() {
        themeMode = storedThemeMode
        accentColor = storedAccentColor
        fontSize = storedFontSize
        reduceMotion = storedReduceMotion
        hapticFeedback = storedHapticFeedback
    }

    private func syncToLocalStorage() {
        storedThemeMode = themeMode
        storedAccentColor = accentColor
        storedFontSize = fontSize
        storedReduceMotion = reduceMotion
        storedHapticFeedback = hapticFeedback
    }

    private func setupAutoSave() {
        // Theme mode syncs immediately (no debounce) to avoid race condition
        // with ThemeTransitionManager's direct UserDefaults write
        $themeMode
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newMode in
                self?.storedThemeMode = newMode
            }
            .store(in: &cancellables)

        // Other settings can be debounced
        Publishers.CombineLatest4($accentColor, $fontSize, $reduceMotion, $hapticFeedback)
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.storedAccentColor = self.accentColor
                self.storedFontSize = self.fontSize
                self.storedReduceMotion = self.reduceMotion
                self.storedHapticFeedback = self.hapticFeedback
            }
            .store(in: &cancellables)
    }
}

struct AppearanceSettingsView: View {
    @StateObject private var viewModel = AppearanceSettingsViewModel()
    @Environment(\.colorScheme) var systemColorScheme
    @AppStorage("reduce_motion") private var reduceMotion = false

    private let accentColorOptions = [
        ("#34C759", "Green"), ("#007AFF", "Blue"), ("#FF9500", "Orange"),
        ("#FF2D55", "Pink"), ("#AF52DE", "Purple"), ("#5856D6", "Indigo"),
        ("#00C7BE", "Teal"), ("#FF3B30", "Red")
    ]

    var body: some View {
        ZStack {
            AppColors.backgroundSecondary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // Theme Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Theme")
                            .font(AppTypography.headingMedium())
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.sm)

                        VStack(spacing: Spacing.md) {
                            // Theme Selector
                            HStack(spacing: Spacing.md) {
                                ThemeButton(
                                    title: "Light",
                                    icon: "sun.max.fill",
                                    isSelected: viewModel.themeMode == "light"
                                ) {
                                    HapticManager.selectionChanged()
                                    changeTheme(to: "light")
                                }

                                ThemeButton(
                                    title: "Dark",
                                    icon: "moon.fill",
                                    isSelected: viewModel.themeMode == "dark"
                                ) {
                                    HapticManager.selectionChanged()
                                    changeTheme(to: "dark")
                                }

                                ThemeButton(
                                    title: "System",
                                    icon: "iphone",
                                    isSelected: viewModel.themeMode == "system"
                                ) {
                                    HapticManager.selectionChanged()
                                    changeTheme(to: "system")
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.md)

                            Divider()
                                .padding(.horizontal, Spacing.lg)

                            // Preview
                            ThemePreview(
                                isDark: viewModel.themeMode == "dark" ||
                                    (viewModel.themeMode == "system" && systemColorScheme == .dark)
                            )
                            .padding(.horizontal, Spacing.lg)
                            .padding(.bottom, Spacing.md)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                    }

                    // Accent Color Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Accent Color")
                            .font(AppTypography.headingMedium())
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.sm)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Spacing.md) {
                            ForEach(accentColorOptions, id: \.0) { color, name in
                                ColorButton(
                                    color: color,
                                    name: name,
                                    isSelected: viewModel.accentColor == color
                                ) {
                                    HapticManager.selectionChanged()
                                    viewModel.accentColor = color
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                    }

                    // Text Size Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Text Size")
                            .font(AppTypography.headingMedium())
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.sm)

                        VStack(spacing: 0) {
                            ForEach([("small", "Small"), ("medium", "Medium"), ("large", "Large"), ("extra_large", "Extra Large")], id: \.0) { key, label in
                                Button {
                                    HapticManager.selectionChanged()
                                    viewModel.fontSize = key
                                } label: {
                                    HStack {
                                        Text(label)
                                            .font(fontSize(for: key))
                                            .foregroundColor(AppColors.textPrimary)

                                        Spacer()

                                        if viewModel.fontSize == key {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: IconSize.lg))
                                                .foregroundColor(AppColors.accent)
                                        } else {
                                            Circle()
                                                .strokeBorder(AppColors.textTertiary.opacity(0.5), lineWidth: 1.5)
                                                .frame(width: 22, height: 22)
                                        }
                                    }
                                    .padding(.horizontal, Spacing.lg)
                                    .padding(.vertical, Spacing.md)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if key != "extra_large" {
                                    Divider()
                                        .padding(.leading, Spacing.lg)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                    }

                    // Accessibility Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Accessibility")
                            .font(AppTypography.headingMedium())
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.sm)

                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "waveform")
                                    .font(.system(size: IconSize.sm))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: 28)

                                Text("Haptic Feedback")
                                    .font(AppTypography.bodyLarge())
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                Toggle("", isOn: $viewModel.hapticFeedback)
                                    .labelsHidden()
                                    .onChange(of: viewModel.hapticFeedback) { _, _ in
                                        HapticManager.toggle()
                                    }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)

                            Divider()
                                .padding(.leading, 70)

                            HStack {
                                Image(systemName: "figure.walk.motion")
                                    .font(.system(size: IconSize.sm))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: 28)

                                Text("Reduce Motion")
                                    .font(AppTypography.bodyLarge())
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                Toggle("", isOn: $viewModel.reduceMotion)
                                    .labelsHidden()
                                    .onChange(of: viewModel.reduceMotion) { _, _ in
                                        HapticManager.toggle()
                                    }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(AppColors.separator.opacity(0.5), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.section)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadSettings()
        }
    }

    private func fontSize(for key: String) -> Font {
        switch key {
        case "small": return AppTypography.bodySmall()
        case "medium": return AppTypography.bodyDefault()
        case "large": return AppTypography.bodyLarge()
        case "extra_large": return AppTypography.headingLarge()
        default: return AppTypography.bodyDefault()
        }
    }

    private func changeTheme(to mode: String) {
        guard mode != viewModel.themeMode else { return }
        viewModel.themeMode = mode
        ThemeTransitionManager.shared.transition(to: mode, reduceMotion: reduceMotion)
    }
}

// MARK: - Supporting Views

private struct ThemeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.lg))
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)

                Text(title)
                    .font(AppTypography.caption())
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(isSelected ? AppColors.buttonBackground.opacity(0.12) : AppColors.backgroundTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .strokeBorder(isSelected ? AppColors.buttonBackground : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ThemePreview: View {
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(isDark ? Color(UIColor(hex: "#1C1C1E")) : Color.white)
                .frame(height: 60)
                .overlay(
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        RoundedRectangle(cornerRadius: CornerRadius.xs)
                            .fill(isDark ? AppColors.textTertiary : AppColors.borderSubtle)
                            .frame(width: 60, height: 8)
                        RoundedRectangle(cornerRadius: CornerRadius.xs)
                            .fill(isDark ? AppColors.borderStrong : AppColors.border)
                            .frame(width: 100, height: 6)
                    }
                    .padding(Spacing.sm),
                    alignment: .topLeading
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(AppColors.separator, lineWidth: 0.5)
                )

            Text(isDark ? "Dark Mode" : "Light Mode")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

private struct ColorButton: View {
    let color: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? AppColors.textPrimary : Color.clear, lineWidth: 3)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: IconSize.sm, weight: .bold))
                            .foregroundColor(AppColors.onAccent)
                            .opacity(isSelected ? 1 : 0)
                    )

                Text(name)
                    .font(AppTypography.labelSmall())
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
