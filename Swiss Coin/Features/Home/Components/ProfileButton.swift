import SwiftUI

struct ProfileButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            HapticManager.lightTap()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(AppColors.buttonBackground)
                    .frame(width: AvatarSize.xs, height: AvatarSize.xs)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: AvatarSize.xs - 2, weight: .light))
                    .foregroundStyle(
                        AppColors.buttonForeground,
                        AppColors.buttonBackground
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
            .background(AppColors.background)

        ProfileButton(action: {})
            .padding()
            .background(AppColors.backgroundSecondary)
    }
}
