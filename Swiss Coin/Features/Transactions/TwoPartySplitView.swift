import CoreData
import SwiftUI

/// Specialized split details view for 2-party transactions.
/// Shows a simplified "Equal Split" layout with directional owe indicators
/// instead of the standard multi-party breakdown.
struct TwoPartySplitView: View {
    @ObservedObject var viewModel: TransactionViewModel

    /// Green color for "they owe you" (matching reference design)
    private let positiveGreen = Color(hex: "#34C759")

    private var otherPerson: Person? {
        viewModel.twoPartyOtherPerson
    }

    private var otherName: String {
        otherPerson?.firstName ?? "Unknown"
    }

    private var otherInitials: String {
        otherPerson?.initials ?? "?"
    }

    private var otherColor: Color {
        Color(hex: otherPerson?.colorHex ?? AppColors.defaultAvatarColorHex)
    }

    private var currentUserColor: Color {
        Color(hex: CurrentUser.defaultColorHex)
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            equalSplitPill
            directionalFlowSection
        }
        .onAppear {
            if viewModel.splitMethod != .equal {
                viewModel.splitMethod = .equal
                viewModel.rawInputs = [:]
            }
        }
    }

    // MARK: - Equal Split Pill

    private var equalSplitPill: some View {
        Text("Equal Split")
            .font(AppTypography.bodyBold())
            .foregroundColor(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(AppColors.cardBackgroundElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(AppColors.separator, lineWidth: 1)
            )
    }

    // MARK: - Directional Flow Section

    private var directionalFlowSection: some View {
        let theyOweYou = viewModel.twoPartyTheyOweYou
        let youOweThem = viewModel.twoPartyYouOweThem

        return VStack(spacing: Spacing.md) {
            // Row 1: Other Person owes You
            DirectionalFlowRow(
                leftInitials: otherInitials,
                leftColor: otherColor,
                rightInitials: CurrentUser.initials,
                rightColor: currentUserColor,
                labelText: "\(otherName) owe You",
                amount: theyOweYou,
                isActive: theyOweYou > 0.01,
                accentColor: positiveGreen
            )

            // Row 2: You owe Other Person
            DirectionalFlowRow(
                leftInitials: CurrentUser.initials,
                leftColor: currentUserColor,
                rightInitials: otherInitials,
                rightColor: otherColor,
                labelText: "You owe \(otherName)",
                amount: youOweThem,
                isActive: youOweThem > 0.01,
                accentColor: AppColors.negative
            )
        }
    }
}

// MARK: - Directional Flow Row

/// A single directional indicator showing who owes whom.
/// Displays two avatar circles connected by an arrow line with a label overlay.
struct DirectionalFlowRow: View {
    let leftInitials: String
    let leftColor: Color
    let rightInitials: String
    let rightColor: Color
    let labelText: String
    let amount: Double
    let isActive: Bool
    let accentColor: Color

    private let avatarSize: CGFloat = 40

    var body: some View {
        HStack(spacing: 0) {
            // Left avatar
            avatarCircle(initials: leftInitials, color: leftColor)

            // Center: arrow line with label overlay
            ZStack {
                // Arrow line
                arrowLine
                    .frame(height: 2)

                // Label + amount overlay
                VStack(spacing: Spacing.xxs) {
                    Text(labelText)
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(isActive ? accentColor : AppColors.textTertiary)

                    if isActive && amount > 0.01 {
                        Text(CurrencyFormatter.formatAbsolute(amount))
                            .font(AppTypography.amount())
                            .foregroundColor(accentColor)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.cardBackgroundElevated)
                )
            }

            // Right avatar
            avatarCircle(initials: rightInitials, color: rightColor)
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(AppColors.cardBackgroundElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(isActive ? accentColor.opacity(0.3) : AppColors.separator, lineWidth: 1)
        )
        .opacity(isActive ? 1.0 : 0.5)
        .animation(AppAnimation.standard, value: isActive)
    }

    // MARK: - Avatar Circle

    private func avatarCircle(initials: String, color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.15))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text(initials)
                    .font(.system(size: avatarSize * 0.35, weight: .semibold))
                    .foregroundColor(color)
            )
            .overlay(
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - Arrow Line

    private var arrowLine: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let midY = geometry.size.height / 2

            Path { path in
                // Main horizontal line
                path.move(to: CGPoint(x: 0, y: midY))
                path.addLine(to: CGPoint(x: width, y: midY))

                // Arrowhead at the right end
                let arrowSize: CGFloat = 5
                path.move(to: CGPoint(x: width - arrowSize, y: midY - arrowSize))
                path.addLine(to: CGPoint(x: width, y: midY))
                path.addLine(to: CGPoint(x: width - arrowSize, y: midY + arrowSize))
            }
            .stroke(
                isActive ? accentColor.opacity(0.4) : AppColors.separator,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

