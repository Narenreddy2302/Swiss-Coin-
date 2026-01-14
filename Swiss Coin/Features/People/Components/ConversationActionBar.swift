//
//  ConversationActionBar.swift
//  Swiss Coin
//

import SwiftUI

struct ConversationActionBar: View {
    let balance: Double
    let onAdd: () -> Void
    let onSettle: () -> Void
    let onRemind: () -> Void

    private var canSettle: Bool {
        abs(balance) > 0.01
    }

    private var canRemind: Bool {
        balance > 0.01 // Only show remind when they owe you
    }

    var body: some View {
        HStack(spacing: 10) {
            // Add Transaction Button (Primary - Green Accent)
            ActionButton(
                title: "Add",
                icon: "plus",
                isPrimary: true,
                isEnabled: true,
                action: onAdd
            )

            // Remind Button
            ActionButton(
                title: "Remind",
                icon: "bell.fill",
                isPrimary: false,
                isEnabled: canRemind,
                action: {
                    if canRemind {
                        onRemind()
                    }
                }
            )

            // Settle Button
            ActionButton(
                title: "Settle",
                icon: "checkmark",
                isPrimary: false,
                isEnabled: canSettle,
                action: {
                    if canSettle {
                        onSettle()
                    }
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let title: String
    let icon: String
    let isPrimary: Bool
    let isEnabled: Bool
    let action: () -> Void

    // Retained haptic generator for reliable feedback
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        Button(action: {
            if isEnabled || isPrimary {
                hapticGenerator.impactOccurred()
                action()
            }
        }) {
            HStack(spacing: 8) {
                if isPrimary {
                    // Green circle with plus icon for Add button
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 24, height: 24)

                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.4))
                }

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isPrimary ? .green : (isEnabled ? .secondary : .secondary.opacity(0.4)))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray6).opacity(0.3))
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled && !isPrimary)
        .onAppear {
            hapticGenerator.prepare()
        }
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
