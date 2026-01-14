//
//  MessageBubbleView.swift
//  Swiss Coin
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    private var isFromUser: Bool {
        message.isFromUser
    }

    var body: some View {
        HStack {
            if isFromUser {
                Spacer(minLength: 60)
            }

            Text(message.content ?? "")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(isFromUser ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    ChatBubbleShape(isFromUser: isFromUser)
                        .fill(isFromUser ? Color.green : Color(UIColor.systemGray5))
                )

            if !isFromUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Chat Bubble Shape with Tail

struct ChatBubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let radius: CGFloat = 18
        let tailWidth: CGFloat = 8
        let tailHeight: CGFloat = 12

        var path = Path()

        if isFromUser {
            // Right-aligned bubble with tail on the right
            // Start from top-left
            path.move(to: CGPoint(x: radius, y: 0))

            // Top edge
            path.addLine(to: CGPoint(x: width - radius - tailWidth, y: 0))

            // Top-right corner
            path.addArc(
                center: CGPoint(x: width - radius - tailWidth, y: radius),
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )

            // Right edge (before tail)
            path.addLine(to: CGPoint(x: width - tailWidth, y: height - tailHeight - radius))

            // Tail
            path.addQuadCurve(
                to: CGPoint(x: width, y: height - 4),
                control: CGPoint(x: width - tailWidth + 2, y: height - tailHeight + 4)
            )
            path.addQuadCurve(
                to: CGPoint(x: width - tailWidth - 4, y: height),
                control: CGPoint(x: width - 4, y: height)
            )

            // Bottom-right (after tail)
            path.addLine(to: CGPoint(x: radius, y: height))

            // Bottom-left corner
            path.addArc(
                center: CGPoint(x: radius, y: height - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )

            // Left edge
            path.addLine(to: CGPoint(x: 0, y: radius))

            // Top-left corner
            path.addArc(
                center: CGPoint(x: radius, y: radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        } else {
            // Left-aligned bubble with tail on the left
            // Start from top-left (after tail area)
            path.move(to: CGPoint(x: tailWidth + radius, y: 0))

            // Top edge
            path.addLine(to: CGPoint(x: width - radius, y: 0))

            // Top-right corner
            path.addArc(
                center: CGPoint(x: width - radius, y: radius),
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )

            // Right edge
            path.addLine(to: CGPoint(x: width, y: height - radius))

            // Bottom-right corner
            path.addArc(
                center: CGPoint(x: width - radius, y: height - radius),
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )

            // Bottom edge
            path.addLine(to: CGPoint(x: tailWidth + 4, y: height))

            // Tail
            path.addQuadCurve(
                to: CGPoint(x: 0, y: height - 4),
                control: CGPoint(x: 4, y: height)
            )
            path.addQuadCurve(
                to: CGPoint(x: tailWidth, y: height - tailHeight - radius),
                control: CGPoint(x: tailWidth - 2, y: height - tailHeight + 4)
            )

            // Left edge (after tail)
            path.addLine(to: CGPoint(x: tailWidth, y: radius))

            // Top-left corner
            path.addArc(
                center: CGPoint(x: tailWidth + radius, y: radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }

        path.closeSubpath()
        return path
    }
}
