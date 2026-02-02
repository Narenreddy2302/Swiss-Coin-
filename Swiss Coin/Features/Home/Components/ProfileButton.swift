import SwiftUI

struct ProfileButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            ZStack {
                // Clean circular background - Apple style
                Circle()
                    .fill(AppColors.cardBackground)
                    .frame(width: AvatarSize.xs, height: AvatarSize.xs)

                // SF Symbol person icon - Apple's standard approach
                Image(systemName: "person.circle.fill")
                    .font(.system(size: AvatarSize.xs - 2, weight: .light))
                    .foregroundStyle(
                        AppColors.textSecondary,
                        AppColors.cardBackground
                    )
            }
        }
        .buttonStyle(ProfileButtonStyle())
        .accessibilityLabel("Profile")
    }
}

/// Apple-style button interaction with subtle scale animation
private struct ProfileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileButton(action: {})
            .padding()
            .background(Color(UIColor.systemBackground))

        ProfileButton(action: {})
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
    }
}
