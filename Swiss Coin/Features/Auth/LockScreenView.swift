//
//  LockScreenView.swift
//  Swiss Coin
//
//  Premium lock screen modeled after Cash App and Revolut.
//  Features a custom number pad, PIN dot indicators, biometric unlock button,
//  shake-on-error animation, and smooth unlock transitions.
//  Data preloads behind this view so the home screen is instant on unlock.
//

import LocalAuthentication
import SwiftUI

struct LockScreenView: View {
    @ObservedObject var lockManager: AppLockManager

    // MARK: - State

    @State private var enteredPIN = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var showError = false
    @State private var failedAttempts = 0
    @State private var isLocked = false
    @State private var lockoutTimeRemaining = 0
    @State private var lockoutTimer: Timer?
    @State private var biometricAttempted = false
    @State private var dotScale: [CGFloat] = Array(repeating: 1.0, count: 6)
    @State private var unlockScale: CGFloat = 1.0
    @State private var unlockOpacity: Double = 1.0

    private let pinLength = 6
    private let maxAttempts = 5
    private let lockoutDuration = 30 // seconds

    var body: some View {
        ZStack {
            // Background
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()
                    .frame(minHeight: Spacing.xxl, maxHeight: Spacing.xxxl * 2)

                // App branding
                brandingSection

                Spacer()
                    .frame(minHeight: Spacing.xl, maxHeight: Spacing.xxxl)

                // PIN dots
                pinDotsSection

                // Error message
                errorSection

                Spacer()
                    .frame(minHeight: Spacing.lg, maxHeight: Spacing.xxl)

                // Number pad
                numberPadSection

                // Biometric button
                biometricSection

                Spacer()
                    .frame(minHeight: Spacing.md, maxHeight: Spacing.xl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .scaleEffect(unlockScale)
        .opacity(unlockOpacity)
        .onChange(of: lockManager.lockState) { _, newState in
            if newState == .unlocking {
                withAnimation(.easeIn(duration: 0.3)) {
                    unlockScale = 1.08
                    unlockOpacity = 0
                }
            } else if newState == .locked {
                // Reset when re-locked
                unlockScale = 1.0
                unlockOpacity = 1.0
                enteredPIN = ""
                showError = false
            }
        }
        .onAppear {
            attemptBiometricOnAppear()
        }
    }

    // MARK: - Branding Section

    private var brandingSection: some View {
        VStack(spacing: Spacing.md) {
            // App icon circle
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: IconSize.xxl))
                    .foregroundColor(AppColors.accent)
            }

            Text("Swiss Coin")
                .font(AppTypography.displayMedium())
                .tracking(AppTypography.Tracking.displayMedium)
                .foregroundColor(AppColors.textPrimary)

            Text(lockMessage)
                .font(AppTypography.bodyDefault())
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var lockMessage: String {
        if isLocked {
            return "Try again in \(lockoutTimeRemaining)s"
        }
        if lockManager.isPINEnabled {
            return "Enter your PIN to unlock"
        }
        return "Authenticate to continue"
    }

    // MARK: - PIN Dots Section

    private var pinDotsSection: some View {
        HStack(spacing: Spacing.lg) {
            ForEach(0..<pinLength, id: \.self) { index in
                PINDotView(
                    isFilled: index < enteredPIN.count,
                    isError: showError,
                    scale: dotScale[index]
                )
            }
        }
        .offset(x: shakeOffset)
        .padding(.vertical, Spacing.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PIN entry, \(enteredPIN.count) of \(pinLength) digits entered")
    }

    // MARK: - Error Section

    private var errorSection: some View {
        Group {
            if showError {
                Text(isLocked ? "Too many attempts" : "Incorrect PIN")
                    .font(AppTypography.labelDefault())
                    .foregroundColor(AppColors.negative)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                // Invisible placeholder to maintain layout
                Text(" ")
                    .font(AppTypography.labelDefault())
            }
        }
        .frame(height: 20)
        .animation(AppAnimation.fast, value: showError)
    }

    // MARK: - Number Pad Section

    private var numberPadSection: some View {
        VStack(spacing: Spacing.md) {
            ForEach(numberPadRows, id: \.self) { row in
                HStack(spacing: Spacing.xl) {
                    ForEach(row, id: \.self) { key in
                        NumberPadButton(key: key, isDisabled: isLocked) {
                            handleKeyPress(key)
                        }
                    }
                }
            }
        }
    }

    private var numberPadRows: [[NumberPadKey]] {
        [
            [.digit(1), .digit(2), .digit(3)],
            [.digit(4), .digit(5), .digit(6)],
            [.digit(7), .digit(8), .digit(9)],
            [.blank, .digit(0), .delete],
        ]
    }

    // MARK: - Biometric Section

    private var biometricSection: some View {
        Group {
            if lockManager.isBiometricEnabled && lockManager.biometricType != .none {
                Button {
                    HapticManager.lightTap()
                    attemptBiometric()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: biometricIcon)
                            .font(.system(size: IconSize.md))
                        Text("Use \(biometricLabel)")
                            .font(AppTypography.labelLarge())
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.vertical, Spacing.md)
                }
                .disabled(isLocked)
                .opacity(isLocked ? 0.4 : 1.0)
                .padding(.top, Spacing.md)
            } else {
                Spacer()
                    .frame(height: Spacing.xxl)
            }
        }
    }

    private var biometricIcon: String {
        switch lockManager.biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    private var biometricLabel: String {
        switch lockManager.biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometric"
        }
    }

    // MARK: - Actions

    private func handleKeyPress(_ key: NumberPadKey) {
        guard !isLocked else { return }

        switch key {
        case .digit(let number):
            guard enteredPIN.count < pinLength else { return }
            enteredPIN += "\(number)"
            HapticManager.lightTap()

            // Animate the dot filling in
            let index = enteredPIN.count - 1
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                dotScale[index] = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    dotScale[index] = 1.0
                }
            }

            // Auto-verify when all 6 digits entered
            if enteredPIN.count == pinLength {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    verifyPIN()
                }
            }

        case .delete:
            guard !enteredPIN.isEmpty else { return }
            enteredPIN.removeLast()
            HapticManager.selectionChanged()
            showError = false

        case .blank:
            break
        }
    }

    private func verifyPIN() {
        if lockManager.verifyPIN(enteredPIN) {
            // Correct PIN
            lockManager.unlock()
        } else {
            // Wrong PIN
            failedAttempts += 1
            HapticManager.error()

            withAnimation(.default) {
                showError = true
            }

            // Shake animation
            withAnimation(Animation.spring(response: 0.1, dampingFraction: 0.2).repeatCount(3)) {
                shakeOffset = 12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    shakeOffset = 0
                }
            }

            // Clear PIN after shake
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                enteredPIN = ""
            }

            // Lockout after max attempts
            if failedAttempts >= maxAttempts {
                startLockout()
            }
        }
    }

    private func startLockout() {
        isLocked = true
        lockoutTimeRemaining = lockoutDuration

        lockoutTimer?.invalidate()
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                lockoutTimeRemaining -= 1
                if lockoutTimeRemaining <= 0 {
                    lockoutTimer?.invalidate()
                    lockoutTimer = nil
                    isLocked = false
                    failedAttempts = 0
                    showError = false
                }
            }
        }
    }

    private func attemptBiometricOnAppear() {
        guard !biometricAttempted else { return }
        guard lockManager.isBiometricEnabled else { return }
        guard lockManager.biometricType != .none else { return }
        biometricAttempted = true

        // Small delay so the UI renders first (like Revolut)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            attemptBiometric()
        }
    }

    private func attemptBiometric() {
        Task {
            let success = await lockManager.authenticateWithBiometric()
            if success {
                lockManager.unlock()
            }
        }
    }
}

// MARK: - PIN Dot View

private struct PINDotView: View {
    let isFilled: Bool
    let isError: Bool
    let scale: CGFloat

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 14, height: 14)
            .scaleEffect(scale)
            .animation(AppAnimation.fast, value: isFilled)
            .animation(AppAnimation.fast, value: isError)
    }

    private var dotColor: Color {
        if isError {
            return AppColors.negative
        }
        return isFilled ? AppColors.accent : AppColors.textSecondary.opacity(0.25)
    }
}

// MARK: - Number Pad Key

enum NumberPadKey: Hashable {
    case digit(Int)
    case delete
    case blank
}

// MARK: - Number Pad Button

private struct NumberPadButton: View {
    let key: NumberPadKey
    let isDisabled: Bool
    let action: () -> Void

    private let buttonSize: CGFloat = 72

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundFill)
                    .frame(width: buttonSize, height: buttonSize)

                content
            }
        }
        .buttonStyle(NumberPadButtonStyle())
        .disabled(isDisabled || key == .blank)
        .opacity(key == .blank ? 0 : (isDisabled ? 0.4 : 1.0))
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var content: some View {
        switch key {
        case .digit(let number):
            VStack(spacing: 1) {
                Text("\(number)")
                    .font(AppTypography.displayLarge())
                    .foregroundColor(AppColors.textPrimary)

                Text(subtitleForDigit(number))
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
                    .opacity(subtitleForDigit(number).isEmpty ? 0 : 1)
            }

        case .delete:
            Image(systemName: "delete.backward.fill")
                .font(.system(size: IconSize.md, weight: .medium))
                .foregroundColor(AppColors.textPrimary)

        case .blank:
            EmptyView()
        }
    }

    private var backgroundFill: Color {
        switch key {
        case .digit:
            return AppColors.backgroundSecondary
        case .delete:
            return Color.clear
        case .blank:
            return Color.clear
        }
    }

    private var accessibilityText: String {
        switch key {
        case .digit(let n): return "\(n)"
        case .delete: return "Delete"
        case .blank: return ""
        }
    }

    /// Phone-style letter subtitles under each digit (like Cash App / banking apps)
    private func subtitleForDigit(_ digit: Int) -> String {
        switch digit {
        case 1: return ""
        case 2: return "ABC"
        case 3: return "DEF"
        case 4: return "GHI"
        case 5: return "JKL"
        case 6: return "MNO"
        case 7: return "PQRS"
        case 8: return "TUV"
        case 9: return "WXYZ"
        case 0: return ""
        default: return ""
        }
    }
}

// MARK: - Number Pad Button Style

/// Custom button style that provides a press-down scale effect
/// without the default SwiftUI button highlight.
private struct NumberPadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    LockScreenView(lockManager: AppLockManager.shared)
}
