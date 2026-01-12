import SwiftUI

struct ActionHeaderButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))  // Slightly larger, bold icon
                Text(title)
                    .font(.system(size: 17, weight: .semibold))  // Standard body size but semibold
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 52)  // Slightly taller
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(14)  // Softer corners
        }
    }
}

struct ActionHeaderButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            ActionHeaderButton(title: "Play", icon: "play.fill", color: .red) {}
            ActionHeaderButton(title: "Shuffle", icon: "shuffle", color: .red) {}
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
