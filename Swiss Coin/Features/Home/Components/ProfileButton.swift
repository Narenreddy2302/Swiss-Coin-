import SwiftUI

struct ProfileButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Placeholder gradient/color if no image
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                // User Initials or Image
                // Using an image from assets if available to match the reference
                // Ideally this would come from a user model
                Image("uploaded_image_1768262251873")  // Assuming this might be added to assets, strictly based on user context
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
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
