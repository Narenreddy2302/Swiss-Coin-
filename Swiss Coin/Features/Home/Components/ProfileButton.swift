import SwiftUI

struct ProfileButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Gradient background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                // System icon for profile (ready for real user image from auth)
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .accessibilityLabel("Profile")
    }
}

#Preview {
    ProfileButton(action: {})
        .padding()
        .background(Color.black)
}
