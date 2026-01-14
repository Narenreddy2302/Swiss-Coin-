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
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // Add Transaction Button
                ActionBarButton(
                    title: "Add",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    onAdd()
                }

                // Settle Button
                ActionBarButton(
                    title: "Settle",
                    icon: "checkmark.circle.fill",
                    color: canSettle ? .green : .gray
                ) {
                    if canSettle {
                        onSettle()
                    }
                }
                .opacity(canSettle ? 1.0 : 0.5)
                .disabled(!canSettle)

                // Remind Button
                ActionBarButton(
                    title: "Remind",
                    icon: "bell.fill",
                    color: canRemind ? .orange : .gray
                ) {
                    if canRemind {
                        onRemind()
                    }
                }
                .opacity(canRemind ? 1.0 : 0.5)
                .disabled(!canRemind)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}

// MARK: - Action Bar Button

struct ActionBarButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
