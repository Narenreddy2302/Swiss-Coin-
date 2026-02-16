//
//  ThemeTransitionManager.swift
//  Swiss Coin
//
//  Manages smooth cross-fade transitions when switching between light and dark mode.
//

import UIKit

@MainActor
final class ThemeTransitionManager {

    static let shared = ThemeTransitionManager()
    private init() {}

    private var isTransitioning = false
    private var pendingThemeMode: String?
    private var pendingReduceMotion: Bool = false

    private static let snapshotTag = 999

    /// Performs a smooth theme transition using a snapshot overlay cross-fade.
    /// - Parameters:
    ///   - newThemeMode: The new theme mode string ("light", "dark", or "system")
    ///   - reduceMotion: Whether the user has reduce motion enabled
    func transition(to newThemeMode: String, reduceMotion: Bool = false) {
        guard !isTransitioning else {
            pendingThemeMode = newThemeMode
            pendingReduceMotion = reduceMotion
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            applyTheme(newThemeMode)
            return
        }

        // Capture snapshots for ALL visible windows (main + sheet windows)
        var snapshots: [(UIView, UIWindow)] = []
        for window in windowScene.windows where window.isKeyWindow || !window.isHidden {
            if let snapshot = window.snapshotView(afterScreenUpdates: false) {
                snapshot.frame = window.bounds
                snapshot.tag = ThemeTransitionManager.snapshotTag
                window.addSubview(snapshot)
                snapshots.append((snapshot, window))
            }
        }

        guard !snapshots.isEmpty else {
            applyTheme(newThemeMode)
            return
        }

        isTransitioning = true
        applyTheme(newThemeMode)

        // Let SwiftUI complete its trait collection update and re-render
        DispatchQueue.main.async { [self] in
            let duration = reduceMotion
                ? AppAnimation.themeTransitionReducedDuration
                : AppAnimation.themeTransitionDuration

            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: {
                    for (snapshot, _) in snapshots { snapshot.alpha = 0 }
                },
                completion: { [self] _ in
                    for (snapshot, _) in snapshots { snapshot.removeFromSuperview() }
                    self.isTransitioning = false

                    // Apply any queued theme change from rapid toggling
                    if let pending = self.pendingThemeMode {
                        self.pendingThemeMode = nil
                        self.transition(to: pending, reduceMotion: self.pendingReduceMotion)
                    }
                }
            )
        }
    }

    /// Remove any lingering snapshot overlays (e.g. if app went to background mid-transition).
    func cancelTransition() {
        isTransitioning = false
        pendingThemeMode = nil

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            for subview in window.subviews where subview.tag == ThemeTransitionManager.snapshotTag {
                subview.removeFromSuperview()
            }
        }
    }

    private func applyTheme(_ themeMode: String) {
        UserDefaults.standard.set(themeMode, forKey: "theme_mode")

        // Directly override UIKit trait collection on all windows so that
        // UIColor { traitCollection in … } closures (used by AppColors)
        // resolve to the new theme *immediately* — before the snapshot
        // overlay begins fading out.  Without this, the SwiftUI
        // @AppStorage → .preferredColorScheme chain is asynchronous and
        // the current page (e.g. Profile / Appearance Settings) can stay
        // stuck showing old-theme colours while the cross-fade reveals it.
        let style: UIUserInterfaceStyle
        switch themeMode {
        case "light":
            style = .light
        case "dark":
            style = .dark
        default:
            style = .unspecified
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            window.overrideUserInterfaceStyle = style
        }
    }
}
