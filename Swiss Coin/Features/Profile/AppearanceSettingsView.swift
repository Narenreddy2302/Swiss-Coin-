//
//  AppearanceSettingsView.swift
//  Swiss Coin
//
//  View for managing app appearance settings.
//  All settings are stored locally via AppStorage.
//

import Combine
import SwiftUI

// MARK: - ViewModel

@MainActor
final class AppearanceSettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    // Theme
    @Published var themeMode: String = "system"

    // Accent Color
    @Published var accentColor: String = "#34C759"

    // Font Size
    @Published var fontSize: String = "medium"

    // Accessibility
    @Published var reduceMotion: Bool = false
    @Published var hapticFeedback: Bool = true

    // Home Screen
    @Published var showBalanceOnHome: Bool = true
    @Published var defaultHomeTab: String = "summary"

    // State
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - AppStorage (local persistence)

    @AppStorage("theme_mode") private var storedThemeMode = "system"
    @AppStorage("accent_color") private var storedAccentColor = "#34C759"
    @AppStorage("font_size") private var storedFontSize = "medium"
    @AppStorage("reduce_motion") private var storedReduceMotion = false
    @AppStorage("haptic_feedback") private var storedHapticFeedback = true
    @AppStorage("show_balance_home") private var storedShowBalanceOnHome = true
    @AppStorage("default_home_tab") private var storedDefaultHomeTab = "summary"

    // MARK: - Init

    init() {
        loadFromLocalStorage()
        setupAutoSave()
    }

    // MARK: - Public Methods

    func loadSettings() {
        isLoading = true
        loadFromLocalStorage()
        isLoading = false
    }

    // MARK: - Private Methods

    private func loadFromLocalStorage() {
        themeMode = storedThemeMode
        accentColor = storedAccentColor
        fontSize = storedFontSize
        reduceMotion = storedReduceMotion
        hapticFeedback = storedHapticFeedback
        showBalanceOnHome = storedShowBalanceOnHome
        defaultHomeTab = storedDefaultHomeTab
    }

    private func syncToLocalStorage() {
        storedThemeMode = themeMode
        storedAccentColor = accentColor
        storedFontSize = fontSize
        storedReduceMotion = reduceMotion
        storedHapticFeedback = hapticFeedback
        storedShowBalanceOnHome = showBalanceOnHome
        storedDefaultHomeTab = defaultHomeTab
    }

    private func setupAutoSave() {
        // Debounced auto-save when any setting changes
        Publishers.CombineLatest4(
            $themeMode,
            $accentColor,
            $fontSize,
            $reduceMotion
        )
        .combineLatest(
            Publishers.CombineLatest3(
                $hapticFeedback,
                $showBalanceOnHome,
                $defaultHomeTab
            )
        )
        .dropFirst() // Skip initial values
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.syncToLocalStorage()
        }
        .store(in: &cancellables)
    }
}

// MARK: - View

struct AppearanceSettingsView: View {
    @StateObject private var viewModel = AppearanceSettingsViewModel()
    @Environment(\.colorScheme) var systemColorScheme

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
                Picker("Theme", selection: $viewModel.themeMode) {
                    Label("Light", systemImage: "sun.max.fill").tag("light")
                    Label("Dark", systemImage: "moon.fill").tag("dark")
                    Label("System", systemImage: "iphone.gen3").tag("system")
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.themeMode) { _, _ in
                    HapticManager.selectionChanged()
                }

                // Theme Preview
                HStack(spacing: Spacing.lg) {
                    ThemePreviewCard(
                        theme: "light",
                        isSelected: viewModel.themeMode == "light" ||
                            (viewModel.themeMode == "system" && systemColorScheme == .light)
                    )
                    ThemePreviewCard(
                        theme: "dark",
                        isSelected: viewModel.themeMode == "dark" ||
                            (viewModel.themeMode == "system" && systemColorScheme == .dark)
                    )
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
                        AccentColorButton(
                            color: color,
                            name: name,
                            isSelected: viewModel.accentColor == color
                        ) {
                            HapticManager.selectionChanged()
                            viewModel.accentColor = color
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
                Picker("Text Size", selection: $viewModel.fontSize) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                    Text("Extra Large").tag("extra_large")
                }
                .onChange(of: viewModel.fontSize) { _, _ in
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
                Toggle("Reduce Motion", isOn: $viewModel.reduceMotion)
                    .onChange(of: viewModel.reduceMotion) { _, _ in
                        HapticManager.toggle()
                    }

                Toggle("Haptic Feedback", isOn: $viewModel.hapticFeedback)
                    .onChange(of: viewModel.hapticFeedback) { _, _ in
                        HapticManager.toggle()
                    }
            } header: {
                Label("Accessibility", systemImage: "accessibility")
                    .font(AppTypography.subheadlineMedium())
            } footer: {
                Text("Reduce motion minimizes animations. Haptic feedback provides tactile responses.")
                    .font(AppTypography.caption())
            }

            // Home Screen Settings
            Section {
                Toggle("Show Balance on Home", isOn: $viewModel.showBalanceOnHome)
                    .onChange(of: viewModel.showBalanceOnHome) { _, _ in
                        HapticManager.toggle()
                    }

                Picker("Default Home Tab", selection: $viewModel.defaultHomeTab) {
                    Text("Summary").tag("summary")
                    Text("Recent Activity").tag("activity")
                    Text("Quick Actions").tag("quick")
                }
                .onChange(of: viewModel.defaultHomeTab) { _, _ in
                    HapticManager.selectionChanged()
                }
            } header: {
                Label("Home Screen", systemImage: "house.fill")
                    .font(AppTypography.subheadlineMedium())
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadSettings()
        }
    }

    // MARK: - Computed Properties

    private var fontSizePreview: Font {
        switch viewModel.fontSize {
        case "small": return .system(size: 14, weight: .semibold)
        case "medium": return .system(size: 17, weight: .semibold)
        case "large": return .system(size: 20, weight: .semibold)
        case "extra_large": return .system(size: 24, weight: .semibold)
        default: return .system(size: 17, weight: .semibold)
        }
    }

    private var fontSizePreviewSecondary: Font {
        switch viewModel.fontSize {
        case "small": return .system(size: 12)
        case "medium": return .system(size: 15)
        case "large": return .system(size: 17)
        case "extra_large": return .system(size: 20)
        default: return .system(size: 15)
        }
    }
}

// MARK: - Accent Color Button

private struct AccentColorButton: View {
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
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )

                Text(name)
                    .font(AppTypography.caption2())
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
            }
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

// MARK: - Preview

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
