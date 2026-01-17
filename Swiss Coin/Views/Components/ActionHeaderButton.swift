import SwiftUI

struct ActionHeaderButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(AppTypography.bodyBold())
                Text(title)
                    .font(AppTypography.bodyBold())
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: ButtonHeight.lg)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .cornerRadius(CornerRadius.lg)
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
