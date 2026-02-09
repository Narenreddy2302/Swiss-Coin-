//
//  ThemeTransitionManager.swift
//  Swiss Coin
//
//  Manages smooth cross-fade transitions when switching between light and dark mode.
//

import UIKit

final class ThemeTransitionManager {

    static let shared = ThemeTransitionManager()
    private init() {}

    private var isTransitioning = false

    /// Performs a smooth theme transition using a snapshot overlay cross-fade.
    /// - Parameters:
    ///   - newThemeMode: The new theme mode string ("light", "dark", or "system")
    ///   - reduceMotion: Whether the user has reduce motion enabled
    func transition(to newThemeMode: String, reduceMotion: Bool = false) {
        guard !isTransitioning else {
            applyTheme(newThemeMode)
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            applyTheme(newThemeMode)
            return
        }

        guard let snapshot = window.snapshotView(afterScreenUpdates: false) else {
            applyTheme(newThemeMode)
            return
        }

        isTransitioning = true
        snapshot.frame = window.bounds
        window.addSubview(snapshot)

        applyTheme(newThemeMode)

        let duration = reduceMotion
            ? AppAnimation.themeTransitionReducedDuration
            : AppAnimation.themeTransitionDuration

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                snapshot.alpha = 0
            },
            completion: { _ in
                snapshot.removeFromSuperview()
                self.isTransitioning = false
            }
        )
    }

    private func applyTheme(_ themeMode: String) {
        UserDefaults.standard.set(themeMode, forKey: "theme_mode")
    }
}
