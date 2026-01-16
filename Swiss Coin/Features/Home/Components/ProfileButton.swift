import SwiftUI

struct ProfileButton: View {
    var action: () -> Void

    // Apple-style color palette for profile avatars
    private let avatarColor = Color(red: 0.35, green: 0.35, blue: 0.37)

    var body: some View {
        Button(action: action) {
            ZStack {
                // Clean circular background - Apple style
                Circle()
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: 32, height: 32)

                // SF Symbol person icon - Apple's standard approach
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(
                        Color(UIColor.secondaryLabel),
                        Color(UIColor.tertiarySystemFill)
                    )
            }
        }
        .buttonStyle(ProfileButtonStyle())
        .accessibilityLabel("Profile")
    }
}

/// Apple-style button interaction with subtle scale and haptic feedback
private struct ProfileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.lightTap()
                }
            }
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
