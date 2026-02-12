//
//  SwipeBackGesture.swift
//  Swiss Coin
//
//  Re-enables the native iOS interactive pop gesture (swipe from left edge to go back)
//  on views that use .navigationBarBackButtonHidden(true).
//
//  SwiftUI disables the interactivePopGestureRecognizer when the default back button
//  is hidden. This modifier finds the underlying UINavigationController and re-enables it.
//

import SwiftUI
import UIKit

// MARK: - UIKit Bridge

/// A hidden UIViewController representable that locates the parent UINavigationController
/// and re-enables its interactivePopGestureRecognizer.
private struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackController {
        SwipeBackController()
    }

    func updateUIViewController(_ uiViewController: SwipeBackController, context: Context) {}
}

/// Lightweight UIViewController that enables the interactive pop gesture on its
/// parent navigation controller.
private class SwipeBackController: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Walk up the responder chain to find the navigation controller
        // and re-enable its interactive pop gesture recognizer.
        if let nav = navigationController {
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = nil
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let nav = navigationController {
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

// MARK: - View Modifier

/// ViewModifier that enables swipe-back navigation on views with hidden back buttons.
private struct SwipeBackModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                SwipeBackGestureEnabler()
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            )
    }
}

// MARK: - View Extension

extension View {
    /// Enables the native iOS swipe-from-left-edge-to-go-back gesture.
    ///
    /// Use this on views where `.navigationBarBackButtonHidden(true)` is set
    /// to restore the standard interactive pop gesture that SwiftUI disables
    /// when hiding the default back button.
    ///
    /// Usage:
    /// ```swift
    /// .navigationBarBackButtonHidden(true)
    /// .enableSwipeBack()
    /// ```
    func enableSwipeBack() -> some View {
        modifier(SwipeBackModifier())
    }
}
